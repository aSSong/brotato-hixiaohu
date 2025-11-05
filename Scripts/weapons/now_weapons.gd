extends Node2D

var weapon_radius: float = GameConfig.weapon_radius
var weapon_num = 0
var player_ref: Node2D = null  # 玩家引用，用于获取职业加成

## 预加载武器场景（使用现有的weapon.tscn作为基础模板）
var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

func _ready() -> void:
	# 添加到组中以便查找
	add_to_group("weapons_manager")
	add_to_group("weapons")
	
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 如果没有预设武器，从GameMain读取选择的武器
	if get_child_count() == 0:
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

## 添加武器（使用WeaponFactory简化流程）
func add_weapon(weapon_id: String, level: int = 1) -> void:
	print("[NowWeapons] 尝试添加武器: ", weapon_id, " Lv.", level)
	
	# 检查武器数量限制
	if get_child_count() >= GameConfig.max_weapon_count:
		push_warning("武器数量已达上限（%d把）" % GameConfig.max_weapon_count)
		return
	
	# 使用WeaponFactory创建武器实例（已初始化）
	var weapon_instance = WeaponFactory.create_weapon(weapon_id, level)
	if weapon_instance == null:
		push_error("创建武器实例失败: " + weapon_id)
		return
	
	# 添加到场景树
	add_child(weapon_instance)
	
	# 等待一帧以确保_ready执行完毕
	await get_tree().process_frame
	
	# 应用职业加成
	if weapon_instance.weapon_data:
		_apply_class_bonuses(weapon_instance, weapon_instance.weapon_data)
	
	# 排列武器
	arrange_weapons()
	print("[NowWeapons] 武器添加完成，当前武器数量: ", get_child_count())

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
func get_lowest_level_weapon_of_type(weapon_id: String) -> BaseWeapon:
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

## 应用职业加成到武器
func _apply_class_bonuses(weapon: Node2D, weapon_data: WeaponData) -> void:
	if not player_ref or not player_ref.has_method("get_attack_multiplier"):
		return
	
	# 获取攻击力倍数
	var attack_multiplier = player_ref.get_attack_multiplier()
	var type_multiplier = player_ref.get_weapon_type_multiplier(weapon_data.weapon_type)
	
	# 应用到武器伤害（可以通过修改weapon_data或添加加成变量）
	# 这里我们可以在武器类中添加一个damage_multiplier属性
	if weapon.has_method("set_damage_multiplier"):
		weapon.set_damage_multiplier(attack_multiplier * type_multiplier)
	
	# 应用攻击速度加成
	if player_ref.class_manager:
		var speed_multiplier = player_ref.class_manager.get_passive_effect("attack_speed_multiplier", 1.0)
		if player_ref.class_manager.is_skill_active("狂暴"):
			speed_multiplier *= (1.0 + player_ref.class_manager.get_skill_effect("狂暴_attack_speed", 0.0))
		
		if weapon.has_method("set_attack_speed_multiplier"):
			weapon.set_attack_speed_multiplier(speed_multiplier)

## 排列武器位置
func arrange_weapons() -> void:
	var weapons = self.get_children()
	weapon_num = weapons.size()
	
	if weapon_num == 0:
		return
	
	var unit = TAU / weapon_num
	
	for i in range(weapon_num):
		var weapon = weapons[i]
		var weapon_rad = unit * i
		var end_pos = Vector2(weapon_radius, 0).rotated(weapon_rad)
		weapon.position = end_pos

## 移除所有武器
func clear_weapons() -> void:
	for child in get_children():
		child.queue_free()
	weapon_num = 0

## 设置武器半径
func set_weapon_radius(radius: float) -> void:
	weapon_radius = radius
	arrange_weapons()
