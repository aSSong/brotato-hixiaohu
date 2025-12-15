extends Resource
class_name WeaponData

## 武器数据 Resource 类（重构版）
## 
## 武器配置分为四部分：
##   1. 基础信息：名称、贴图、缩放、描述
##   2. 行为配置：行为类型 + 行为参数（包含 damage）
##   3. 结算配置：决定使用哪种属性加成
##   4. 特殊效果：燃烧、冰冻等状态效果

## ========== 旧版兼容（将被废弃） ==========
## 保留旧的 WeaponType 以兼容现有代码
enum WeaponType {
	RANGED,    # 远程武器（子弹）
	MELEE,     # 近战武器（旋转/挥砍）
	MAGIC      # 魔法武器（爆炸/范围）
}

## ========== 新版枚举 ==========

## 行为类型（决定武器如何攻击）
enum BehaviorType {
	MELEE,    # 近战：环绕触碰
	RANGED,   # 远程：发射子弹
	MAGIC,    # 魔法：定点打击
}

## 结算类型（决定使用哪种属性加成）
enum CalculationType {
	MELEE,    # 近战结算：受近战属性加成
	RANGED,   # 远程结算：受远程属性加成
	MAGIC,    # 魔法结算：受魔法属性加成
}

## ========== 基础信息 ==========
@export var weapon_name: String = "默认武器"
@export var description: String = ""

## 外观设置
@export var texture_path: String = "res://assets/weapon/weapon-lightningwand.png"
@export var scale: Vector2 = Vector2(0.7, 0.7)
@export var sprite_offset: Vector2 = Vector2.ZERO

## ========== 新版配置 ==========

## 行为类型
@export var behavior_type: BehaviorType = BehaviorType.RANGED

## 行为参数（根据 behavior_type 包含不同内容）
## 
## MELEE 参数:
##   - damage: int
##   - orbit_radius: float (环绕半径)
##   - orbit_speed: float (环绕速度，度/秒)
##   - hit_range: float (攻击判定范围)
##   - knockback_force: float (击退力度)
##   - rotation_speed: float (武器自转速度)
##   - attack_speed: float (攻击间隔)
##   - range: float (检测范围)
## 
## RANGED 参数:
##   - damage: int
##   - bullet_id: String (子弹ID，引用 BulletDatabase)
##   - pierce_count: int (穿透数量)
##   - projectile_count: int (每次发射子弹数)
##   - spread_angle: float (散射角度)
##   - attack_speed: float (攻击间隔)
##   - range: float (检测范围)
##   - shoot_offset: Vector2 (发射位置偏移，相对于武器中心)
##   - recoil_distance: float (后座力位移像素，可选，默认0)
##   - recoil_duration: float (后座力恢复时间秒，可选，默认0.1)
## 
## MAGIC 参数:
##   - damage: int
##   - explosion_radius: float (爆炸范围)
##   - explosion_damage_multiplier: float (爆炸伤害倍数)
##   - cast_delay: float (施法延迟)
##   - is_target_locked: bool (是否锁定目标)
##   - max_targets: int (最大目标数)
##   - has_explosion_damage: bool (是否有范围爆炸伤害)
##   - attack_speed: float (攻击间隔)
##   - range: float (检测范围)
##   - indicator_color: Color (指示器颜色)
##   - weapon_name: String (用于特效查找)
##   - shoot_offset: Vector2 (发射位置偏移，相对于武器中心)
##   - muzzle_effect_scene_path: String (枪口特效场景路径)
##   - muzzle_effect_ani_name: String (枪口特效动画名)
##   - muzzle_effect_scale: float (枪口特效缩放)
##   - muzzle_effect_offset: Vector2 (枪口特效位置偏移)
@export var behavior_params: Dictionary = {}

## 结算类型
@export var calculation_type: CalculationType = CalculationType.RANGED

## 特殊效果配置
## 格式: [{"type": "burn", "params": {"chance": 0.2, "damage": 5, "duration": 3}}, ...]
@export var special_effects: Array = []

## ========== 旧版兼容字段（保留但不推荐使用） ==========
## 这些字段用于兼容旧代码，新代码应使用 behavior_params

@export var weapon_type: WeaponType = WeaponType.RANGED

## 基础属性
@export var damage: int = 1
@export var attack_speed: float = 0.5
@export var range: float = 500.0

## 远程武器专用属性
@export var bullet_speed: float = 2000.0
@export var bullet_lifetime: float = 3.0

## 近战武器专用属性
@export var rotation_speed: float = 360.0
@export var swing_angle: float = 180.0
@export var hit_range: float = 100.0
@export var orbit_radius: float = 230.0
@export var orbit_speed: float = 90.0

## 魔法武器专用属性
@export var explosion_radius: float = 150.0
@export var explosion_damage_multiplier: float = 1.0
@export var max_targets: int = 5
@export var has_explosion_damage: bool = true
@export var attack_cast_delay: float = 0.0
@export var is_target_locked: bool = true

## 其他属性
@export var pierce_count: int = 0
@export var knockback_force: float = 0.0

## ========== 武器附加属性 ==========

@export var crit_chance_bonus: float = 0.0
@export var crit_damage_bonus: float = 0.0
@export var lifesteal_percent: float = 0.0
@export var burn_chance: float = 0.0
@export var freeze_chance: float = 0.0
@export var poison_chance: float = 0.0
@export var defense_bonus: int = 0
@export var hp_bonus: int = 0
@export var speed_bonus: float = 0.0

## ========== 等级系统 ==========

const weapon_level_colors = {
	level_1 = "#FFFFFF",
	level_2 = "#00FF00",
	level_3 = "#0000FF",
	level_4 = "#FF00FF",
	level_5 = "#FF0000",
}

static func get_level_multipliers(level: int) -> Dictionary:
	level = clamp(level, 1, 5)
	var multipliers = {
		"damage_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		"range_multiplier": 1.0,
	}
	match level:
		1:
			multipliers.damage_multiplier = 1.0
			multipliers.attack_speed_multiplier = 1.0
			multipliers.range_multiplier = 1.0
		2:
			multipliers.damage_multiplier = 1.3
			multipliers.attack_speed_multiplier = 1.1
			multipliers.range_multiplier = 1.1
		3:
			multipliers.damage_multiplier = 1.6
			multipliers.attack_speed_multiplier = 1.2
			multipliers.range_multiplier = 1.2
		4:
			multipliers.damage_multiplier = 2.0
			multipliers.attack_speed_multiplier = 1.3
			multipliers.range_multiplier = 1.3
		5:
			multipliers.damage_multiplier = 2.5
			multipliers.attack_speed_multiplier = 1.5
			multipliers.range_multiplier = 1.5
	return multipliers

## ========== 初始化 ==========

func _init(
	p_weapon_name: String = "默认武器",
	p_behavior_type: BehaviorType = BehaviorType.RANGED,
	p_calculation_type: CalculationType = CalculationType.RANGED,
	p_behavior_params: Dictionary = {},
	p_texture_path: String = "res://assets/weapon/weapon-lightningwand.png",
	p_scale: Vector2 = Vector2(0.7, 0.7)
) -> void:
	weapon_name = p_weapon_name
	behavior_type = p_behavior_type
	calculation_type = p_calculation_type
	behavior_params = p_behavior_params
	texture_path = p_texture_path
	scale = p_scale
	
	# 同步旧版字段（兼容性）
	_sync_legacy_fields()

## 同步旧版字段（从 behavior_params 到旧字段）
func _sync_legacy_fields() -> void:
	# 根据行为类型设置旧版 weapon_type
	match behavior_type:
		BehaviorType.MELEE:
			weapon_type = WeaponType.MELEE
		BehaviorType.RANGED:
			weapon_type = WeaponType.RANGED
		BehaviorType.MAGIC:
			weapon_type = WeaponType.MAGIC
	
	# 同步通用参数
	if behavior_params.has("damage"):
		damage = behavior_params.get("damage")
	if behavior_params.has("attack_speed"):
		attack_speed = behavior_params.get("attack_speed")
	if behavior_params.has("range"):
		range = behavior_params.get("range")
	
	# 同步近战武器专用参数
	if behavior_params.has("orbit_radius"):
		orbit_radius = behavior_params.get("orbit_radius")
	if behavior_params.has("orbit_speed"):
		orbit_speed = behavior_params.get("orbit_speed")
	if behavior_params.has("hit_range"):
		hit_range = behavior_params.get("hit_range")
	if behavior_params.has("knockback_force"):
		knockback_force = behavior_params.get("knockback_force")
	if behavior_params.has("rotation_speed"):
		rotation_speed = behavior_params.get("rotation_speed")
	
	# 同步魔法武器专用参数
	if behavior_params.has("explosion_radius"):
		explosion_radius = behavior_params.get("explosion_radius")
	if behavior_params.has("explosion_damage_multiplier"):
		explosion_damage_multiplier = behavior_params.get("explosion_damage_multiplier")
	if behavior_params.has("cast_delay"):
		attack_cast_delay = behavior_params.get("cast_delay")
	if behavior_params.has("is_target_locked"):
		is_target_locked = behavior_params.get("is_target_locked")
	if behavior_params.has("max_targets"):
		max_targets = behavior_params.get("max_targets")
	if behavior_params.has("has_explosion_damage"):
		has_explosion_damage = behavior_params.get("has_explosion_damage")
	
	# 同步远程武器专用参数
	if behavior_params.has("pierce_count"):
		pierce_count = behavior_params.get("pierce_count")

## 从旧版字段构建 behavior_params（用于迁移）
func build_behavior_params_from_legacy() -> Dictionary:
	var params = {
		"damage": damage,
		"attack_speed": attack_speed,
		"range": range,
	}
	
	match weapon_type:
		WeaponType.MELEE:
			params["orbit_radius"] = orbit_radius
			params["orbit_speed"] = orbit_speed
			params["hit_range"] = hit_range
			params["knockback_force"] = knockback_force
			params["rotation_speed"] = rotation_speed
		WeaponType.RANGED:
			params["bullet_id"] = "normal_bullet"
			params["pierce_count"] = pierce_count
			params["projectile_count"] = 1
			params["spread_angle"] = 0.0
			# 旧版子弹参数存储在 BulletData 中
		WeaponType.MAGIC:
			params["explosion_radius"] = explosion_radius
			params["explosion_damage_multiplier"] = explosion_damage_multiplier
			params["cast_delay"] = attack_cast_delay
			params["is_target_locked"] = is_target_locked
			params["max_targets"] = max_targets
			params["has_explosion_damage"] = has_explosion_damage
			params["weapon_name"] = weapon_name
	
	return params

## 获取行为参数（优先使用新版，降级使用旧版构建）
func get_behavior_params() -> Dictionary:
	if behavior_params.is_empty():
		return build_behavior_params_from_legacy()
	return behavior_params

## 获取结算类型对应的 int（用于 DamageCalculator）
func get_calculation_type_int() -> int:
	return calculation_type as int

## 创建武器的属性修改器
func create_weapon_modifier(weapon_id: String) -> AttributeModifier:
	var modifier = AttributeModifier.new()
	modifier.modifier_type = AttributeModifier.ModifierType.BASE
	modifier.modifier_id = "weapon_" + weapon_id
	modifier.stats_delta = CombatStats.new()
	
	modifier.stats_delta.max_hp = 0
	modifier.stats_delta.speed = 0.0
	modifier.stats_delta.crit_damage = 0.0
	
	if crit_chance_bonus != 0.0:
		modifier.stats_delta.crit_chance = crit_chance_bonus
	if crit_damage_bonus != 0.0:
		modifier.stats_delta.crit_damage = crit_damage_bonus
	
	if lifesteal_percent != 0.0:
		modifier.stats_delta.lifesteal_percent = lifesteal_percent
	if burn_chance != 0.0:
		modifier.stats_delta.burn_chance = burn_chance
	if freeze_chance != 0.0:
		modifier.stats_delta.freeze_chance = freeze_chance
	if poison_chance != 0.0:
		modifier.stats_delta.poison_chance = poison_chance
	
	if defense_bonus != 0:
		modifier.stats_delta.defense = float(defense_bonus)
	if hp_bonus != 0:
		modifier.stats_delta.max_hp = float(hp_bonus)
	if speed_bonus != 0.0:
		modifier.stats_delta.speed = speed_bonus
	
	return modifier
