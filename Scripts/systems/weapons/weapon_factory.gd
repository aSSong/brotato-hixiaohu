class_name WeaponFactory

## 武器工厂 - 统一武器创建流程

static var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

static func create_weapon(weapon_id: String, level: int = 1) -> BaseWeapon:
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if not weapon_data:
		push_error("[WeaponFactory] 武器不存在: " + weapon_id)
		return null
	
	var weapon_instance = base_weapon_scene.instantiate()
	if not weapon_instance:
		return null
	
	var script_path = _get_weapon_script_path(weapon_data.weapon_type)
	weapon_instance.set_script(load(script_path))
	weapon_instance.initialize(weapon_data, level)
	
	return weapon_instance

static func _get_weapon_script_path(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.RANGED: return "res://Scripts/weapons/ranged_weapon.gd"
		WeaponData.WeaponType.MELEE: return "res://Scripts/weapons/melee_weapon.gd"
		WeaponData.WeaponType.MAGIC: return "res://Scripts/weapons/magic_weapon.gd"
		_: return "res://Scripts/weapons/ranged_weapon.gd"
