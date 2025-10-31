extends Node2D

var weapon_radius = 230
var weapon_num = 0
var player_ref: Node2D = null  # 玩家引用，用于获取职业加成

## 预加载武器场景（使用现有的weapon.tscn作为基础模板）
var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

func _ready() -> void:
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 如果没有预设武器，从GameMain读取选择的武器
	if get_child_count() == 0:
		if GameMain.selected_weapon_ids.size() > 0:
			# 使用玩家选择的武器
			for weapon_id in GameMain.selected_weapon_ids:
				add_weapon(weapon_id)
		else:
			# 如果没有选择，使用默认测试武器
			create_test_weapons()
	
	# 排列现有武器
	arrange_weapons()
	pass

## 创建测试武器（用于测试）
func create_test_weapons() -> void:
	# 添加一些测试武器
	add_weapon("pistol")
	add_weapon("sword")
	add_weapon("fireball")

## 添加武器
func add_weapon(weapon_id: String) -> void:
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if weapon_data == null:
		push_error("武器不存在: " + weapon_id)
		return
	
	# 创建武器实例
	var weapon_instance = _create_weapon_instance(weapon_data)
	if weapon_instance == null:
		return
	
	add_child(weapon_instance)
	
	# 等待一帧以确保_ready执行完毕，然后初始化武器
	await get_tree().process_frame
	if is_instance_valid(weapon_instance) and weapon_instance.has_method("initialize"):
		var stored_data = weapon_instance.get_meta("weapon_data", null)
		if stored_data:
			weapon_instance.initialize(stored_data)
			weapon_instance.remove_meta("weapon_data")
			# 应用职业加成
			_apply_class_bonuses(weapon_instance, stored_data)
	
	arrange_weapons()

## 根据武器数据创建武器实例
func _create_weapon_instance(weapon_data: WeaponData) -> Node2D:
	# 加载基础场景
	var weapon_scene = base_weapon_scene.instantiate()
	
	# 根据武器类型设置脚本（需要在添加到场景树之前设置）
	var script_path = ""
	match weapon_data.weapon_type:
		WeaponData.WeaponType.RANGED:
			script_path = "res://Scripts/weapons/ranged_weapon.gd"
		WeaponData.WeaponType.MELEE:
			script_path = "res://Scripts/weapons/melee_weapon.gd"
		WeaponData.WeaponType.MAGIC:
			script_path = "res://Scripts/weapons/magic_weapon.gd"
		_:
			# 默认使用远程武器
			script_path = "res://Scripts/weapons/ranged_weapon.gd"
	
	# 设置脚本
	if script_path != "":
		var script = load(script_path)
		if script:
			weapon_scene.set_script(script)
	
	# 添加到场景树后才能访问@onready变量
	# 所以初始化会在_ready中延迟执行
	# 存储weapon_data以便在_ready后初始化
	weapon_scene.set_meta("weapon_data", weapon_data)
	
	return weapon_scene

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
