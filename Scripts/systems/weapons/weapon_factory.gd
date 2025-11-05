class_name WeaponFactory extends Node

## 武器工厂
## 统一武器创建流程，消除meta传递和复杂的异步逻辑

## 武器场景预加载
static var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

## 创建武器实例
static func create_weapon(weapon_id: String, level: int = 1) -> BaseWeapon:
	print("[WeaponFactory] 创建武器: %s Lv.%d" % [weapon_id, level])
	
	# 获取武器数据
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if not weapon_data:
		push_error("[WeaponFactory] 武器不存在: " + weapon_id)
		return null
	
	# 实例化武器场景
	var weapon_instance = base_weapon_scene.instantiate()
	if not weapon_instance:
		push_error("[WeaponFactory] 无法实例化武器场景")
		return null
	
	# 根据武器类型设置对应的脚本
	var script_path = _get_weapon_script_path(weapon_data.weapon_type)
	var weapon_script = load(script_path)
	if weapon_script:
		weapon_instance.set_script(weapon_script)
	else:
		push_error("[WeaponFactory] 无法加载武器脚本: " + script_path)
		weapon_instance.queue_free()
		return null
	
	# 直接初始化武器（不使用meta传递）
	weapon_instance.initialize(weapon_data, level)
	
	print("[WeaponFactory] 武器创建成功: %s" % weapon_data.weapon_name)
	return weapon_instance

## 根据武器类型获取对应的脚本路径
static func _get_weapon_script_path(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.RANGED:
			return "res://Scripts/weapons/ranged_weapon.gd"
		WeaponData.WeaponType.MELEE:
			return "res://Scripts/weapons/melee_weapon.gd"
		WeaponData.WeaponType.MAGIC:
			return "res://Scripts/weapons/magic_weapon.gd"
		_:
			# 默认使用远程武器
			push_warning("[WeaponFactory] 未知武器类型，使用默认远程武器脚本")
			return "res://Scripts/weapons/ranged_weapon.gd"

## 批量创建武器
static func create_weapons(weapon_configs: Array) -> Array[BaseWeapon]:
	var weapons: Array[BaseWeapon] = []
	
	for config in weapon_configs:
		var weapon_id = config.get("id", "")
		var level = config.get("level", 1)
		
		if weapon_id == "":
			push_warning("[WeaponFactory] 武器配置缺少id字段")
			continue
		
		var weapon = create_weapon(weapon_id, level)
		if weapon:
			weapons.append(weapon)
	
	return weapons

## 从武器ID列表创建武器（默认等级1）
static func create_weapons_from_ids(weapon_ids: Array) -> Array[BaseWeapon]:
	var weapons: Array[BaseWeapon] = []
	
	for weapon_id in weapon_ids:
		var weapon = create_weapon(weapon_id, 1)
		if weapon:
			weapons.append(weapon)
	
	return weapons

