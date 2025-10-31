extends Node
class_name WeaponDatabase

## 武器数据库
## 预定义多种武器及其属性

static var weapons: Dictionary = {}

## 初始化所有武器
static func initialize_weapons() -> void:
	if not weapons.is_empty():
		return
	
	# 远程武器
	var pistol = WeaponData.new(
		"手枪",
		WeaponData.WeaponType.RANGED,
		2,  # damage
		0.4,  # attack_speed
		600.0  # range
	)
	pistol.description = "基础远程武器，发射快速子弹"
	pistol.bullet_speed = 2000.0
	pistol.bullet_lifetime = 3.0
	weapons["pistol"] = pistol
	
	var rifle = WeaponData.new(
		"步枪",
		WeaponData.WeaponType.RANGED,
		4,  # damage
		0.6,  # attack_speed
		800.0  # range
	)
	rifle.description = "高伤害远程武器，攻击速度较慢"
	rifle.bullet_speed = 2500.0
	rifle.bullet_lifetime = 4.0
	rifle.pierce_count = 1  # 穿透1个敌人
	weapons["rifle"] = rifle
	
	var machine_gun = WeaponData.new(
		"机枪",
		WeaponData.WeaponType.RANGED,
		1,  # damage
		0.15,  # attack_speed (很快)
		500.0  # range
	)
	machine_gun.description = "超高攻击速度的远程武器"
	machine_gun.bullet_speed = 1800.0
	machine_gun.bullet_lifetime = 2.5
	weapons["machine_gun"] = machine_gun
	
	# 近战武器
	var sword = WeaponData.new(
		"剑",
		WeaponData.WeaponType.MELEE,
		3,  # damage
		0.5,  # attack_speed
		150.0  # range
	)
	sword.description = "基础近战武器，旋转攻击"
	sword.rotation_speed = 360.0
	sword.hit_range = 120.0
	sword.knockback_force = 100.0
	weapons["sword"] = sword
	
	var axe = WeaponData.new(
		"斧头",
		WeaponData.WeaponType.MELEE,
		6,  # damage
		0.8,  # attack_speed
		180.0  # range
	)
	axe.description = "高伤害近战武器，攻击速度较慢"
	axe.rotation_speed = 270.0
	axe.hit_range = 150.0
	axe.knockback_force = 200.0
	weapons["axe"] = axe
	
	var dagger = WeaponData.new(
		"匕首",
		WeaponData.WeaponType.MELEE,
		2,  # damage
		0.3,  # attack_speed
		100.0  # range
	)
	dagger.description = "快速攻击的近战武器"
	dagger.rotation_speed = 540.0
	dagger.hit_range = 90.0
	dagger.knockback_force = 50.0
	weapons["dagger"] = dagger
	
	# 魔法武器
	var fireball = WeaponData.new(
		"火球",
		WeaponData.WeaponType.MAGIC,
		5,  # damage
		0.7,  # attack_speed
		600.0  # range
	)
	fireball.description = "基础魔法武器，造成范围爆炸伤害"
	fireball.explosion_radius = 150.0
	fireball.explosion_damage_multiplier = 1.0
	fireball.max_targets = 3
	weapons["fireball"] = fireball
	
	var ice_shard = WeaponData.new(
		"冰刺",
		WeaponData.WeaponType.MAGIC,
		4,  # damage
		0.5,  # attack_speed
		500.0  # range
	)
	ice_shard.description = "快速攻击的魔法武器，较小爆炸范围"
	ice_shard.explosion_radius = 100.0
	ice_shard.explosion_damage_multiplier = 0.8
	ice_shard.max_targets = 2
	weapons["ice_shard"] = ice_shard
	
	var meteor = WeaponData.new(
		"陨石",
		WeaponData.WeaponType.MAGIC,
		10,  # damage
		1.5,  # attack_speed (很慢)
		700.0  # range
	)
	meteor.description = "高伤害魔法武器，超大爆炸范围"
	meteor.explosion_radius = 250.0
	meteor.explosion_damage_multiplier = 1.5
	meteor.max_targets = 8
	weapons["meteor"] = meteor

## 获取武器
static func get_weapon(weapon_id: String) -> WeaponData:
	if weapons.is_empty():
		initialize_weapons()
	return weapons.get(weapon_id, weapons["pistol"])

## 获取所有武器ID
static func get_all_weapon_ids() -> Array:
	if weapons.is_empty():
		initialize_weapons()
	return weapons.keys()

## 根据类型获取武器列表
static func get_weapons_by_type(type: WeaponData.WeaponType) -> Array:
	if weapons.is_empty():
		initialize_weapons()
	
	var result = []
	for weapon_id in weapons.keys():
		var weapon = weapons[weapon_id]
		if weapon.weapon_type == type:
			result.append(weapon_id)
	return result
