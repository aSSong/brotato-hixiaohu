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
	

	
	# ========== 近战武器 ==========
	
	## 剑（近战行为 + 近战结算）
	#var sword = WeaponData.new(
		#"剑",
		#WeaponData.BehaviorType.MELEE,
		#WeaponData.CalculationType.MELEE,
		#{
			#"damage": 4,
			#"attack_speed": 0.5,
			#"range": 240.0,
			#"orbit_radius": 300.0,
			#"orbit_speed": 180.0,
			#"hit_range": 240.0,
			#"knockback_force": 560.0,
			#"rotation_speed": 360.0
		#},
		#"res://assets/weapon/Weapon_lasersword.png",
		#Vector2(0.7, 0.7)
	#)
	#sword.description = "基础近战武器，环绕攻击"
	#weapons["sword"] = sword
	
	# 斧头（近战行为 + 近战结算）
	#var axe = WeaponData.new(
		#"斧头",
		#WeaponData.BehaviorType.MELEE,
		#WeaponData.CalculationType.MELEE,
		#{
			#"damage": 6,
			#"attack_speed": 0.8,
			#"range": 280.0,
			#"orbit_radius": 400.0,
			#"orbit_speed": 120.0,
			#"hit_range": 280.0,
			#"knockback_force": 840.0,
			#"rotation_speed": 270.0
		#},
		#"res://assets/weapon/Weapon_axe.png",
		#Vector2(0.8, 0.8)
	#)
	#axe.description = "高伤害近战武器，攻击速度较慢"
	#weapons["axe"] = axe
	
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
		"res://assets/weapon/weapon_flame_sword.png",
		Vector2(1.0, 1.0)
	)
	flame_sword.description = "环绕自身，火焰附魔"
	flame_sword.special_effects = [
		{
			"type": "burn",
			"params": {
				"chance": 0.3,
				"tick_interval": 0.5,
				"damage": 6.0,
				"duration": 2.0
			}
		}
	]
	weapons["flame_sword"] = flame_sword
	
	# 匕首（近战行为 + 近战结算 + 吸血）
	var dagger = WeaponData.new(
		"匕首",
		WeaponData.BehaviorType.MELEE,
		WeaponData.CalculationType.MELEE,
		{
			"damage": 2,
			"attack_speed": 0.3,
			"range": 200.0,
			"orbit_radius": 250.0,
			"orbit_speed": 240.0, # 每秒转多少度
			"hit_range": 200.0,
			"knockback_force": 280.0,
			"rotation_speed": 540.0
		},
		"res://assets/weapon/weapon-dagger.png",
		Vector2(0.7, 0.7)
	)
	dagger.description = "环绕自身，吸血效果"
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
	
	# ========== 远程武器 ==========
	
	## 手枪（远程行为 + 远程结算）
	#var pistol = WeaponData.new(
		#"手枪",
		#WeaponData.BehaviorType.RANGED,
		#WeaponData.CalculationType.RANGED,
		#{
			#"damage": 3,
			#"attack_speed": 0.4,
			#"range": 800.0,
			#"bullet_id": "normal_bullet",
			#"pierce_count": 0,
			#"projectile_count": 1,
			#"spread_angle": 0.0
		#},
		#"res://assets/weapon/WeaponPistol.png",
		#Vector2(0.7, 0.7)
	#)
	#pistol.description = "基础远程武器，发射快速子弹"
	#weapons["pistol"] = pistol
	
	# 机枪（远程行为 + 远程结算）
	var machine_gun = WeaponData.new(
		"冲锋枪",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 1,
			"attack_speed": 0.3,
			"range": 800.0,
			"bullet_id": "mg_bullet",  # 使用机枪专属子弹（带枪口和击中特效）
			"pierce_count": 0,
			"projectile_count": 1,
			"spread_angle": 0.0,
			"shoot_offset": Vector2(200, -20)  # 发射位置偏移（枪口位置）
		},
		"res://assets/weapon/weapon_machinegun.png",
		Vector2(0.7, 0.7)
	)
	machine_gun.description = "射速超高"
	weapons["machine_gun"] = machine_gun
	
	# 散弹枪（远程行为 + 远程结算 + 多弹丸）
	var shotgun = WeaponData.new(
		"霰弹枪",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,
		{
			"damage": 2,
			"attack_speed": 1.6,
			"range": 800.0,
			"bullet_id": "normal_bullet",
			"pierce_count": 0,
			"projectile_count": 5,
			"spread_angle": 120.0
		},
		"res://assets/weapon/weapon_shotgun.png",
		Vector2(0.7, 0.7)
	)
	shotgun.description = "每次发射5颗子弹"
	weapons["shotgun"] = shotgun
	
	# 追踪导弹（远程行为 + 远程结算 + 追踪子弹）
	var homing_missile = WeaponData.new(
		"追踪导弹",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.RANGED,  # 魔法结算！
		{
			"damage": 8,
			"attack_speed": 2.4,
			"range": 1800.0,
			"bullet_id": "homing_bullet",
			"pierce_count": 0,
			"projectile_count": 1,
			"spread_angle": 0.0
		},
		"res://assets/weapon/weapon_missle.png",
		Vector2(0.7, 0.7)
	)
	homing_missile.description = "追踪目标，燃烧效果"
	homing_missile.special_effects = [
		{
			"type": "burn",
			"params": {
				"chance": 0.3,
				"tick_interval": 0.5,
				"damage": 4.0,
				"duration": 2.0
			}
		}
	]
	weapons["homing_missile"] = homing_missile
	
	# ========== 魔法武器 ==========
	
	## 火球（魔法行为 + 魔法结算）
	#var fireball = WeaponData.new(
		#"火球",
		#WeaponData.BehaviorType.MAGIC,
		#WeaponData.CalculationType.MAGIC,
		#{
			#"damage": 5,
			#"attack_speed": 0.7,
			#"range": 800.0,
			#"explosion_radius": 150.0,
			#"explosion_damage_multiplier": 1.0,
			#"cast_delay": 0.5,
			#"is_target_locked": true,
			#"max_targets": 1,
			#"has_explosion_damage": true,
			#"indicator_color": Color(1.0, 0.4, 0.0, 0.4),
			#"effect_lead_time": 0.2  # 特效提前 0.2 秒播放
		#},
		#"res://assets/weapon/Weapon_fire.png",
		#Vector2(0.7, 0.7)
	#)
	#fireball.description = "基础魔法武器，造成范围爆炸伤害"
	#fireball.special_effects = [
		#{
			#"type": "burn",
			#"params": {
				#"chance": 0.2,
				#"tick_interval": 0.5,
				#"damage": 5.0,
				#"duration": 3.0
			#}
		#}
	#]
	#weapons["fireball"] = fireball
	
		# 闪电长矛（远程行为 + 魔法结算）
	var rifle = WeaponData.new(
		"闪电长矛",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 4,
			"attack_speed": 1.4,
			"range": 900.0,
			"bullet_id": "ls_bullet",  # 使用闪电长矛专属子弹
			"pierce_count": 2,
			"projectile_count": 1,
			"spread_angle": 0.0,
			"shoot_offset": Vector2(100, 0)  # 发射位置偏移
		},
		"res://assets/weapon/weapon_lightspear.png",
		Vector2(0.7, 0.7)
	)
	rifle.description = "可穿透3名敌人"
	#rifle.special_effects = [
		#{
			#"type": "bleed",
			#"params": {
				#"chance": 0.2,
				#"tick_interval": 0.5,
				#"damage": 3.0,
				#"duration": 3.0
			#}
		#}
	#]
	weapons["rifle"] = rifle
	
	
		# 连锁闪电（远程行为 + 远程结算）
	var lightning_chain = WeaponData.new(
		"连锁闪电",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 3,
			"attack_speed": 1.4,
			"range": 1000.0,
			"bullet_id": "bounce_bullet",
			"pierce_count": 0, # 穿透数
			"projectile_count": 1, #子弹数
			"spread_angle": 0.0
		},
		"res://assets/weapon/weapon_lightwand.png",
		Vector2(0.7, 0.7)
	)
	lightning_chain.description = "自动弹射3名敌人"
	weapons["lightning_chain"] = lightning_chain
	
	
	# 冰刺（魔法行为 + 魔法结算）
	var ice_shard = WeaponData.new(
		"冰刺",
		WeaponData.BehaviorType.MAGIC,
		WeaponData.CalculationType.MAGIC,
		{
			"damage": 4,
			"attack_speed": 2.0,
			"range": 900.0,
			"explosion_radius": 150.0,
			"explosion_damage_multiplier": 0.8,
			"cast_delay": 0.3,
			"is_target_locked": false,
			"max_targets": 1,
			"has_explosion_damage": true,
			"indicator_texture_path": "res://assets/skill_indicator/ice_range_circle.png",
			"effect_lead_time": 0.2  # 特效提前 0.15 秒播放
		},
		"res://assets/weapon/weapon_popsicle.png",
		Vector2(0.7, 0.7)
	)
	ice_shard.description = "快速魔法，冰冻效果"
	ice_shard.special_effects = [
		{
			"type": "freeze",
			"params": {
				"chance": 0.15,
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
			"attack_speed": 3.0,
			"range": 700.0,
			"explosion_radius": 250.0,
			"explosion_damage_multiplier": 1.5,
			"cast_delay": 1.0,
			"is_target_locked": false,
			"max_targets": 1,
			"has_explosion_damage": true,
			"indicator_texture_path": "res://assets/skill_indicator/meteor_range_circle.png",
			"effect_lead_time": 0.2  # 特效较长，提前 0.35 秒播放
		},
		"res://assets/weapon/weapon_meteor.png",
		Vector2(0.7, 0.7)
	)
	meteor.description = "高伤害，大范围"
	weapons["meteor"] = meteor
	
	# 闪电（魔法行为 + 魔法结算 + 多目标）
	# var lightning = WeaponData.new(
	# 	"多头闪电",
	# 	WeaponData.BehaviorType.MAGIC,
	# 	WeaponData.CalculationType.MAGIC,
	# 	{
	# 		"damage": 3,
	# 		"attack_speed": 1.4,
	# 		"range": 850.0,
	# 		"explosion_radius": 80.0,
	# 		"explosion_damage_multiplier": 0.6,
	# 		"cast_delay": 0.2,
	# 		"is_target_locked": true,
	# 		"max_targets": 3,
	# 		"has_explosion_damage": true,
	# 		"indicator_color": Color(0.8, 0.8, 1.0, 0.3),
	# 		"effect_lead_time": 0.1  # 特效短，提前 0.1 秒播放
	# 	},
	# 	"res://assets/weapon/weapon_lightwand.png",
	# 	Vector2(0.6, 0.6)
	# )
	# lightning.description = "快速魔法武器，可同时攻击多个目标"
	# weapons["lightning"] = lightning
	
	# 追踪导弹（远程行为 + 远程结算 + 追踪子弹）
	var arcane_missile = WeaponData.new(
		"奥术飞弹",
		WeaponData.BehaviorType.RANGED,
		WeaponData.CalculationType.MAGIC,  # 魔法结算！
		{
			"damage": 6,
			"attack_speed": 2.4,
			"range": 1800.0,
			"bullet_id": "arcane_bullet",
			"pierce_count": 0,
			"projectile_count": 3,
			"spread_angle": 90.0
		},
		"res://assets/weapon/weapon_arcane.png",
		Vector2(0.7, 0.7)
	)
	arcane_missile.description = "发射3发追踪魔弹"
	#arcane_missile.special_effects = [
		#{
			#"type": "burn",
			#"params": {
				#"chance": 0.3,
				#"tick_interval": 0.5,
				#"damage": 3.0,
				#"duration": 2.0
			#}
		#}
	#]
	weapons["arcane_missile"] = arcane_missile

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
