class_name WeaponFactory

## 武器工厂 - 统一武器创建流程

static var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

static func create_weapon(weapon_id: String, level: int = 1):
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if not weapon_data:
		push_error("[WeaponFactory] 武器不存在: " + weapon_id)
		return null
	
	var weapon_instance = base_weapon_scene.instantiate()
	if not weapon_instance:
		push_error("[WeaponFactory] 无法实例化基础武器场景")
		return null
	
	# 根据武器类型设置正确的脚本
	var script_path = _get_weapon_script_path(weapon_data.weapon_type)
	var script = load(script_path)
	if not script:
		push_error("[WeaponFactory] 无法加载武器脚本: " + script_path)
		weapon_instance.queue_free()
		return null
	
	weapon_instance.set_script(script)
	
	# 使用meta传递数据，让武器的_ready()处理初始化
	# 这样可以确保@onready的节点引用都已经准备好
	weapon_instance.set_meta("weapon_data", weapon_data)
	weapon_instance.set_meta("weapon_level", level)
	
	return weapon_instance

static func _get_weapon_script_path(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.RANGED: return "res://Scripts/weapons/ranged_weapon.gd"
		WeaponData.WeaponType.MELEE: return "res://Scripts/weapons/melee_weapon.gd"
		WeaponData.WeaponType.MAGIC: return "res://Scripts/weapons/magic_weapon.gd"
		_: return "res://Scripts/weapons/ranged_weapon.gd"
