extends Node2D

## 武器管理器（重构版）
## 
## 简化：直接设置武器的player_stats引用，不再手动计算加成

var weapon_radius = 180
var weapon_num = 0
var player_ref: Node2D = null

## 近战武器环绕运动管理
var melee_weapon_angles: Dictionary = {}

## 武器环绕角度偏移（避开玩家头部区域，10点到2点方向）
## PI/4 (45度) 偏移让武器分布避开正上方
const WEAPON_ANGLE_OFFSET = PI / 4

## 预加载武器场景
var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

func _ready() -> void:
	# 添加到组中以便查找
	add_to_group("weapons_manager")
	add_to_group("weapons")
	
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 检查是否为Ghost的组件
	var is_ghost_component = false
	var parent = get_parent()
	if parent and parent.is_in_group("ghost"):
		is_ghost_component = true
		print("[NowWeapons] 父节点是Ghost，跳过自动初始化")
	
	# 如果没有预设武器，从GameMain读取选择的武器（仅在非Ghost情况下）
	if not is_ghost_component and get_child_count() == 0:
		if GameMain.selected_weapon_ids.size() > 0:
			# 使用玩家选择的武器（异步等待每个武器创建完成）
			for weapon_id in GameMain.selected_weapon_ids:
				await add_weapon(weapon_id)
		else:
			# 如果没有选择，使用默认测试武器
			await create_test_weapons()
	
	# 排列现有武器
	arrange_weapons()

## 创建测试武器（用于测试）
func create_test_weapons() -> void:
	# 添加一些测试武器（异步等待每个武器创建完成）
	await add_weapon("pistol")
	await add_weapon("sword")
	await add_weapon("fireball")

## 添加武器
func add_weapon(weapon_id: String, level: int = 1) -> void:
	print("[NowWeapons] 尝试添加武器: ", weapon_id, " Lv.", level)
	
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if weapon_data == null:
		push_error("武器不存在: " + weapon_id)
		return
	
	# 检查武器数量限制
	if get_child_count() >= GameConfig.max_weapon_count:
		push_warning("武器数量已达上限（%d把）" % GameConfig.max_weapon_count)
		return
	
	# 使用WeaponFactory创建武器实例
	var weapon_instance = WeaponFactory.create_weapon(weapon_id, level)
	if weapon_instance == null:
		push_error("创建武器实例失败: " + weapon_id)
		return
	
	print("[NowWeapons] 武器实例已创建: ", weapon_id, " 实例ID: ", weapon_instance.get_instance_id())
	
	# 添加到场景树
	add_child(weapon_instance)
	print("[NowWeapons] 武器实例已添加到场景树: ", weapon_id, " 是否在树中: ", weapon_instance.is_inside_tree())
	
	# 等待一帧以确保_ready执行完毕
	await get_tree().process_frame
	print("[NowWeapons] 等待一帧后，武器实例是否有效: ", is_instance_valid(weapon_instance), " 是否在树中: ", weapon_instance.is_inside_tree() if is_instance_valid(weapon_instance) else "N/A")
	
	# 检查武器实例是否仍然有效
	if not is_instance_valid(weapon_instance):
		push_error("[NowWeapons] 武器实例在添加后变为无效: " + weapon_id)
		# 注意：如果实例无效，不能再调用它的方法，否则会报错
		# 尝试从子节点列表中移除（如果还在的话）
		var children = get_children()
		for i in range(children.size() - 1, -1, -1):
			if not is_instance_valid(children[i]):
				children.remove_at(i)
		return
	
	# 额外检查：确保实例还在场景树中
	if not weapon_instance.is_inside_tree():
		push_error("[NowWeapons] 武器实例不在场景树中: " + weapon_id)
		# 如果不在场景树中，尝试从父节点移除并清理
		var parent = weapon_instance.get_parent()
		if parent:
			parent.remove_child(weapon_instance)
		weapon_instance.queue_free()
		return
	
	# 检查武器是否成功初始化（检查weapon_data是否存在）
	if weapon_instance is BaseWeapon:
		if not weapon_instance.weapon_data:
			push_warning("[NowWeapons] 武器 %s 初始化后 weapon_data 为空，可能初始化失败" % weapon_id)
			# 不销毁实例，让它继续存在（可能稍后会初始化）
	
	# 设置player_stats引用（新系统）
	if weapon_instance is BaseWeapon:
		_setup_weapon_stats(weapon_instance)
	
	# 排列武器
	arrange_weapons()
	print("[NowWeapons] 武器添加完成，当前武器数量: ", get_child_count())

## 设置武器的属性引用
## 
## 连接武器和玩家的属性系统
func _setup_weapon_stats(weapon) -> void:
	if not player_ref:
		push_warning("[NowWeapons] player_ref 未设置，无法设置武器属性")
		return
	
	# 使用新系统：直接引用玩家的final_stats
	if player_ref.has_node("AttributeManager"):
		var attr_manager = player_ref.get_node("AttributeManager")
		weapon.player_stats = attr_manager.final_stats
		print("[NowWeapons] 武器使用新属性系统")
	else:
		# 降级方案：继续使用旧系统
		push_warning("[NowWeapons] 玩家没有AttributeManager，使用旧系统")
		if weapon.weapon_data:
			_apply_class_bonuses_old(weapon, weapon.weapon_data)

## 获取所有武器
func get_all_weapons() -> Array:
	var weapons = []
	for child in get_children():
		if child is BaseWeapon:
			weapons.append(child)
	return weapons

## 获取武器数量
func get_weapon_count() -> int:
	return get_all_weapons().size()

## 获取指定类型的最低级武器
func get_lowest_level_weapon_of_type(weapon_id: String):
	var target_data = WeaponDatabase.get_weapon(weapon_id)
	if target_data == null:
		return null
	
	var candidates = []
	for weapon in get_all_weapons():
		if weapon.weapon_data.weapon_name == target_data.weapon_name:
			candidates.append(weapon)
	
	if candidates.is_empty():
		return null
	
	# 找到等级最低的（如果有多把相同等级，随机选择）
	candidates.sort_custom(func(a, b): return a.weapon_level < b.weapon_level)
	var min_level = candidates[0].weapon_level
	
	# 收集所有最低级的武器
	var lowest_level_weapons = []
	for weapon in candidates:
		if weapon.weapon_level == min_level:
			lowest_level_weapons.append(weapon)
	
	# 随机选择一个
	if lowest_level_weapons.size() > 0:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		return lowest_level_weapons[rng.randi_range(0, lowest_level_weapons.size() - 1)]
	
	return null

## 检查是否有武器达到最高等级
func has_all_weapons_max_level() -> bool:
	var weapons = get_all_weapons()
	if weapons.is_empty():
		return true
	
	for weapon in weapons:
		if weapon.weapon_level < 5:
			return false
	
	return true

## 获取所有可升级的武器类型
func get_upgradeable_weapon_types() -> Array:
	var types = {}
	for weapon in get_all_weapons():
		if weapon.weapon_level < 5:
			var weapon_id = _get_weapon_id(weapon.weapon_data)
			if not types.has(weapon_id):
				types[weapon_id] = weapon.weapon_data.weapon_name
	return types.keys()

## 辅助函数：从weapon_data获取weapon_id
func _get_weapon_id(weapon_data: WeaponData) -> String:
	# 通过weapon_name匹配
	for weapon_id in WeaponDatabase.get_all_weapon_ids():
		var data = WeaponDatabase.get_weapon(weapon_id)
		if data and data.weapon_name == weapon_data.weapon_name:
			return weapon_id
	return ""

## 应用职业加成到武器（旧系统兼容）
func _apply_class_bonuses_old(weapon: Node2D, weapon_data: WeaponData) -> void:
	if not player_ref or not player_ref.current_class:
		return
	
	var current_class = player_ref.current_class
	
	# 1. 应用伤害倍率
	var attack_multiplier = player_ref.get_attack_multiplier()
	var type_multiplier = player_ref.get_weapon_type_multiplier(weapon_data.weapon_type)
	if weapon.has_method("set_damage_multiplier"):
		weapon.set_damage_multiplier(attack_multiplier * type_multiplier)
	
	# 2. 应用攻击速度系数（通用 + 类型特定）
	var speed_mult = current_class.attack_speed_multiplier
	match weapon_data.weapon_type:
		WeaponData.WeaponType.MELEE:
			speed_mult *= current_class.melee_speed_multiplier
		WeaponData.WeaponType.RANGED:
			speed_mult *= current_class.ranged_speed_multiplier
		WeaponData.WeaponType.MAGIC:
			speed_mult *= current_class.magic_speed_multiplier
	
	# 应用技能加成
	if player_ref.class_manager and player_ref.class_manager.is_skill_active("狂暴"):
		speed_mult *= (1.0 + player_ref.class_manager.get_skill_effect("狂暴_attack_speed", 0.0))
	
	if weapon.has_method("set_attack_speed_multiplier"):
		weapon.set_attack_speed_multiplier(speed_mult)
	
	# 3. 应用范围系数
	var range_mult = 1.0
	match weapon_data.weapon_type:
		WeaponData.WeaponType.MELEE:
			range_mult = current_class.melee_range_multiplier
		WeaponData.WeaponType.RANGED:
			range_mult = current_class.ranged_range_multiplier
		WeaponData.WeaponType.MAGIC:
			range_mult = current_class.magic_range_multiplier
	
	if weapon.has_method("set_range_multiplier"):
		weapon.set_range_multiplier(range_mult)
	
	# 4. 应用击退系数（仅近战）
	if weapon_data.weapon_type == WeaponData.WeaponType.MELEE:
		if weapon.has_method("set_knockback_multiplier"):
			weapon.set_knockback_multiplier(current_class.melee_knockback_multiplier)
	
	# 5. 应用爆炸范围系数（仅魔法）
	if weapon_data.weapon_type == WeaponData.WeaponType.MAGIC:
		if weapon.has_method("set_explosion_radius_multiplier"):
			weapon.set_explosion_radius_multiplier(current_class.magic_explosion_radius_multiplier)

## 排列武器位置
func arrange_weapons() -> void:
	var weapons = self.get_children()
	weapon_num = weapons.size()
	
	if weapon_num == 0:
		return
	
	# 分离近战武器和其他武器
	var melee_weapons: Array = []
	var other_weapons: Array = []
	
	for weapon in weapons:
		if weapon is BaseWeapon and weapon.weapon_data:
			if weapon.weapon_data.weapon_type == WeaponData.WeaponType.MELEE:
				melee_weapons.append(weapon)
			else:
				other_weapons.append(weapon)
	
	# 为近战武器分配初始角度（均匀分布，带偏移避开头部）
	var melee_unit = TAU / max(melee_weapons.size(), 1)
	for i in range(melee_weapons.size()):
		var weapon = melee_weapons[i]
		var weapon_id = weapon.get_instance_id()
		# 添加角度偏移，避开玩家头部区域
		var initial_angle = melee_unit * i + WEAPON_ANGLE_OFFSET
		
		# 存储初始角度
		melee_weapon_angles[weapon_id] = initial_angle
		
		# 使用武器的环绕半径（如果配置了），否则使用默认半径
		var radius = weapon.weapon_data.orbit_radius if weapon.weapon_data.orbit_radius > 0 else weapon_radius
		var end_pos = Vector2(radius, 0).rotated(initial_angle)
		weapon.position = end_pos
	
	# 为其他武器分配固定位置（均匀分布，带偏移避开头部）
	var other_unit = TAU / max(other_weapons.size(), 1)
	for i in range(other_weapons.size()):
		var weapon = other_weapons[i]
		# 添加角度偏移，避开玩家头部区域
		var weapon_rad = other_unit * i + WEAPON_ANGLE_OFFSET
		var end_pos = Vector2(weapon_radius, 0).rotated(weapon_rad)
		weapon.position = end_pos

## 更新近战武器环绕运动
func _process(delta: float) -> void:
	# 收集当前所有有效的近战武器ID
	var valid_weapon_ids: Array = []
	
	# 更新所有近战武器的位置（持续旋转）
	for child in get_children():
		if child is BaseWeapon and child.weapon_data:
			if child.weapon_data.weapon_type == WeaponData.WeaponType.MELEE:
				var weapon_id = child.get_instance_id()
				valid_weapon_ids.append(weapon_id)
				
				# 如果这个武器还没有角度记录，初始化它
				if not melee_weapon_angles.has(weapon_id):
					# 计算初始角度（基于当前位置）
					var current_pos = child.position
					var angle = atan2(current_pos.y, current_pos.x)
					melee_weapon_angles[weapon_id] = angle
				
				# 获取武器的环绕速度（如果配置了），否则使用默认值
				var orbit_speed = child.weapon_data.orbit_speed if child.weapon_data.orbit_speed > 0 else 90.0
				
				# 更新角度（持续旋转）
				var current_angle = melee_weapon_angles[weapon_id]
				current_angle += deg_to_rad(orbit_speed) * delta
				melee_weapon_angles[weapon_id] = current_angle
				
				# 获取武器的环绕半径（如果配置了），否则使用默认半径
				var radius = child.weapon_data.orbit_radius if child.weapon_data.orbit_radius > 0 else weapon_radius
				
				# 更新位置
				var new_pos = Vector2(radius, 0).rotated(current_angle)
				child.position = new_pos
	
	# 清理无效的角度记录（武器已被移除）
	var keys_to_remove: Array = []
	for weapon_id in melee_weapon_angles.keys():
		if not valid_weapon_ids.has(weapon_id):
			keys_to_remove.append(weapon_id)
	
	for key in keys_to_remove:
		melee_weapon_angles.erase(key)

## 移除所有武器
func clear_weapons() -> void:
	for child in get_children():
		child.queue_free()
	weapon_num = 0
	melee_weapon_angles.clear()  # 清除角度记录

## 设置武器半径
func set_weapon_radius(radius: float) -> void:
	weapon_radius = radius
	arrange_weapons()

## 重新应用所有武器的加成（当玩家属性改变时）
## 
## 注意：使用新系统后，这个方法基本不需要调用
## 因为所有武器直接引用player.attribute_manager.final_stats
## 属性变化时会自动体现
func reapply_all_bonuses() -> void:
	if not player_ref:
		return
	
	# 新系统：刷新所有武器的属性引用
	for weapon in get_children():
		if weapon is BaseWeapon:
			_setup_weapon_stats(weapon)
			# 刷新武器的攻速和范围（基于新属性）
			if weapon.has_method("refresh_weapon_stats"):
				weapon.refresh_weapon_stats()
	
	print("[NowWeapons] 重新应用所有武器加成")
