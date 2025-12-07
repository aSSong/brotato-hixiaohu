extends Node
class_name WeaponDatabase

## 武器数据库（重构版）
## 
## 使用新的行为/结算分离架构
## 每个武器配置包含：行为类型、行为参数、结算类型、特殊效果

static var weapons: Dictionary = {}

## 初始化所有武器
static func initialize_weapons() -> void:
	if not weapons.is_empty():
		return
	
	# ========== 远程武器 ==========
	
	# 手枪（远程行为 + 远程结算）
	var pistol = WeaponData.new(
		"手枪",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 3,
			"attack_speed": 0.4,
			"range": 800.0,
			"bullet_id": "normal_bullet",
			"pierce_count": 0,
			"projectile_count": 1,
			"spread_angle": 0.0
		},
		"res://assets/weapon/WeaponPistol.png",
		Vector2(0.7, 0.7)
	)
	pistol.description = "基础远程武器，发射快速子弹"
	weapons["pistol"] = pistol
	
	# 步枪（远程行为 + 远程结算 + 流血效果）
	var rifle = WeaponData.new(
		"步枪",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 4,
			"attack_speed": 0.7,
			"range": 900.0,
			"bullet_id": "heavy_bullet",
			"pierce_count": 1,
			"projectile_count": 1,
			"spread_angle": 0.0
		},
		"res://assets/weapon/WeaponShotgun.png",
		Vector2(0.7, 0.7)
	)
	rifle.description = "高伤害远程武器，可穿透敌人"
	rifle.special_effects = [
		{
			"type": "bleed",
			"params": {
				"chance": 0.2,
				"tick_interval": 0.5,
				"damage": 3.0,
				"duration": 3.0
			}
		}
	]
	weapons["rifle"] = rifle
	
	# 机枪（远程行为 + 远程结算）
	var machine_gun = WeaponData.new(
		"机枪",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 1,
			"attack_speed": 0.15,
			"range": 800.0,
			"bullet_id": "fast_bullet",
			"pierce_count": 0,
			"projectile_count": 1,
			"spread_angle": 0.0
		},
		"res://assets/weapon/WeaponSMG.png",
		Vector2(1, 1)
	)
	machine_gun.description = "超高攻击速度的远程武器"
	weapons["machine_gun"] = machine_gun
	
	# 散弹枪（远程行为 + 远程结算 + 多弹丸）
	var shotgun = WeaponData.new(
		"手里剑",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 2,
			"attack_speed": 0.8,
			"range": 800.0,
			"bullet_id": "shuriken_bullet",
			"pierce_count": 0,
			"projectile_count": 5,
			"spread_angle": 120.0
		},
		"res://assets/weapon/weapon-shuriken.png",
		Vector2(0.8, 0.8)
	)
	shotgun.description = "近距离高伤害，发射多颗弹丸"
	weapons["shotgun"] = shotgun
	
	# 追踪导弹（远程行为 + 魔法结算 + 追踪子弹）
	var homing_missile = WeaponData.new(
		"追踪导弹",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.MAGIC,  # 魔法结算！
		{
			"damage": 8,
			"attack_speed": 1.2,
			"range": 1800.0,
			"bullet_id": "homing_bullet",
			"pierce_count": 0,
			"projectile_count": 1,
			"spread_angle": 0.0
		},
		"res://assets/weapon/bullet-missle.png",
		Vector2(0.7, 0.7)
	)
	homing_missile.description = "发射追踪导弹，使用魔法伤害"
	homing_missile.special_effects = [
		{
			"type": "burn",
			"params": {
				"chance": 0.3,
				"tick_interval": 0.5,
				"damage": 3.0,
				"duration": 2.0
			}
		}
	]
	weapons["homing_missile"] = homing_missile
	
	# ========== 近战武器 ==========
	
	# 剑（近战行为 + 近战结算）
	var sword = WeaponData.new(
		"剑",
		WeaponData.BehaviorType.MELEE,
		WeaponData.CalculationType.MELEE,
		{
			"damage": 4,
			"attack_speed": 0.5,
			"range": 240.0,
			"orbit_radius": 300.0,
			"orbit_speed": 180.0,
			"hit_range": 240.0,
			"knockback_force": 560.0,
			"rotation_speed": 360.0
		},
		"res://assets/weapon/Weapon_lasersword.png",
		Vector2(0.7, 0.7)
	)
	sword.description = "基础近战武器，环绕攻击"
	weapons["sword"] = sword
	
	# 斧头（近战行为 + 近战结算）
	var axe = WeaponData.new(
		"斧头",
		WeaponData.BehaviorType.MELEE,
		WeaponData.CalculationType.MELEE,
		{
			"damage": 6,
			"attack_speed": 0.8,
			"range": 280.0,
			"orbit_radius": 400.0,
			"orbit_speed": 120.0,
			"hit_range": 280.0,
			"knockback_force": 840.0,
			"rotation_speed": 270.0
		},
		"res://assets/weapon/Weapon_axe.png",
		Vector2(0.8, 0.8)
	)
	axe.description = "高伤害近战武器，攻击速度较慢"
	weapons["axe"] = axe
	
	# 匕首（近战行为 + 近战结算 + 吸血）
	var dagger = WeaponData.new(
		"匕首",
		WeaponData.BehaviorType.MELEE,
		WeaponData.CalculationType.MELEE,
		{
			"damage": 2,
			"attack_speed": 0.3,
			"range": 200.0,
			"orbit_radius": 200.0,
			"orbit_speed": 240.0,
			"hit_range": 200.0,
			"knockback_force": 280.0,
			"rotation_speed": 540.0
		},
		"res://assets/weapon/weapon-dagger.png",
		Vector2(0.7, 0.7)
	)
	dagger.description = "快速攻击的近战武器，有吸血效果"
	dagger.special_effects = [
		{
			"type": "lifesteal",
			"params": {
				"chance": 0.1,
				"percent": 0.2
			}
		}
	]
	weapons["dagger"] = dagger
	
	# 火焰剑（近战行为 + 魔法结算！）
	var flame_sword = WeaponData.new(
		"火焰剑",
		WeaponData.BehaviorType.MELEE,
		WeaponData.CalculationType.MAGIC,  # 魔法结算！
		{
			"damage": 5,
			"attack_speed": 0.6,
			"range": 250.0,
			"orbit_radius": 320.0,
			"orbit_speed": 160.0,
			"hit_range": 250.0,
			"knockback_force": 400.0,
			"rotation_speed": 300.0
		},
		"res://assets/weapon/Weapon_lasersword.png",
		Vector2(0.75, 0.75)
	)
	flame_sword.description = "附魔火焰的剑，近战行为但使用魔法伤害加成"
	flame_sword.special_effects = [
		{
			"type": "burn",
			"params": {
				"chance": 0.4,
				"tick_interval": 0.5,
				"damage": 5.0,
				"duration": 3.0
			}
		}
	]
	weapons["flame_sword"] = flame_sword
	
	# ========== 魔法武器 ==========
	
	# 火球（魔法行为 + 魔法结算）
	var fireball = WeaponData.new(
		"火球",
		WeaponData.BehaviorType.MAGIC,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 5,
			"attack_speed": 0.7,
			"range": 800.0,
			"explosion_radius": 150.0,
			"explosion_damage_multiplier": 1.0,
			"cast_delay": 0.5,
			"is_target_locked": true,
			"max_targets": 1,
			"has_explosion_damage": true,
			"indicator_color": Color(1.0, 0.4, 0.0, 0.4)
		},
		"res://assets/weapon/Weapon_fire.png",
		Vector2(0.7, 0.7)
	)
	fireball.description = "基础魔法武器，造成范围爆炸伤害"
	fireball.special_effects = [
		{
			"type": "burn",
			"params": {
				"chance": 0.2,
				"tick_interval": 0.5,
				"damage": 5.0,
				"duration": 3.0
			}
		}
	]
	weapons["fireball"] = fireball
	
	# 冰刺（魔法行为 + 魔法结算）
	var ice_shard = WeaponData.new(
		"冰刺",
		WeaponData.BehaviorType.MAGIC,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 4,
			"attack_speed": 1.0,
			"range": 900.0,
			"explosion_radius": 100.0,
			"explosion_damage_multiplier": 0.8,
			"cast_delay": 0.3,
			"is_target_locked": false,
			"max_targets": 1,
			"has_explosion_damage": true,
			#"indicator_color": Color(1.0, 0.4, 0.0, 0.4),
			"indicator_texture_path": "res://assets/skill_indicator/ice_range_circle.png" # 指定自定义纹理路径
		},
		"res://assets/weapon/Weapon_ice.png",
		Vector2(0.7, 0.7)
	)
	ice_shard.description = "快速魔法武器，有几率冰冻敌人"
	ice_shard.special_effects = [
		{
			"type": "freeze",
			"params": {
				"chance": 0.1,
				"duration": 2.0
			}
		}
	]
	weapons["ice_shard"] = ice_shard
	
	# 陨石（魔法行为 + 魔法结算）
	var meteor = WeaponData.new(
		"陨石",
		WeaponData.BehaviorType.MAGIC,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 10,
			"attack_speed": 1.5,
			"range": 700.0,
			"explosion_radius": 250.0,
			"explosion_damage_multiplier": 1.5,
			"cast_delay": 1.0,
			"is_target_locked": false,
			"max_targets": 1,
			"has_explosion_damage": true,
			"indicator_texture_path": "res://assets/skill_indicator/meteor_range_circle.png"  # 指定自定义纹理路径
		},
		"res://assets/weapon/Weapon_stone.png",
		Vector2(0.7, 0.7)
	)
	meteor.description = "高伤害魔法武器，超大爆炸范围"
	weapons["meteor"] = meteor
	
	# 闪电（魔法行为 + 魔法结算 + 多目标）
	var lightning = WeaponData.new(
		"闪电",
		WeaponData.BehaviorType.MAGIC,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 3,
			"attack_speed": 0.5,
			"range": 850.0,
			"explosion_radius": 80.0,
			"explosion_damage_multiplier": 0.6,
			"cast_delay": 0.2,
			"is_target_locked": true,
			"max_targets": 3,
			"has_explosion_damage": true,
			"indicator_color": Color(0.8, 0.8, 1.0, 0.3)
		},
		"res://assets/weapon/weapon-lightningwand.png",
		Vector2(0.6, 0.6)
	)
	lightning.description = "快速魔法武器，可同时攻击多个目标"
	weapons["lightning"] = lightning

## 获取武器
static func get_weapon(weapon_id: String) -> WeaponData:
	if weapons.is_empty():
		initialize_weapons()
	return weapons.get(weapon_id, weapons.get("pistol"))

## 获取所有武器ID
static func get_all_weapon_ids() -> Array:
	if weapons.is_empty():
		initialize_weapons()
	return weapons.keys()

## 根据行为类型获取武器列表
static func get_weapons_by_behavior_type(behavior_type: WeaponData.BehaviorType) -> Array:
	if weapons.is_empty():
		initialize_weapons()
	
	var result = []
	for weapon_id in weapons.keys():
		var weapon = weapons[weapon_id]
		if weapon.behavior_type == behavior_type:
			result.append(weapon_id)
	return result

## 根据结算类型获取武器列表
static func get_weapons_by_calculation_type(calculation_type: WeaponData.CalculationType) -> Array:
	if weapons.is_empty():
		initialize_weapons()
	
	var result = []
	for weapon_id in weapons.keys():
		var weapon = weapons[weapon_id]
		if weapon.calculation_type == calculation_type:
			result.append(weapon_id)
	return result

## 兼容旧接口：根据武器类型获取武器列表
static func get_weapons_by_type(type: WeaponData.WeaponType) -> Array:
	if weapons.is_empty():
		initialize_weapons()
	
	var result = []
	for weapon_id in weapons.keys():
		var weapon = weapons[weapon_id]
		if weapon.weapon_type == type:
			result.append(weapon_id)
	return result
