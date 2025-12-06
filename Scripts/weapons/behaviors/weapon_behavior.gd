extends RefCounted
class_name WeaponBehavior

## 武器行为基类
## 
## 定义武器的攻击方式（如何攻击），与结算类型（伤害计算方式）分离
## 
## 子类实现具体行为：
##   - MeleeBehavior: 环绕触碰
##   - RangedBehavior: 发射子弹
##   - MagicBehavior: 定点打击

## 注意：使用 WeaponData 中定义的枚举类型
## - WeaponData.BehaviorType: 行为类型
## - WeaponData.CalculationType: 结算类型

## 行为参数（由子类定义具体内容）
var params: Dictionary = {}

## 所属武器引用
var weapon: Node2D = null

## 玩家属性引用
var player_stats: CombatStats = null

## 结算类型（用于伤害计算，使用 int 存储以兼容 WeaponData.CalculationType）
var calculation_type: int = 0  # 0=MELEE, 1=RANGED, 2=MAGIC

## 特殊效果配置
var special_effects: Array = []

## 武器等级
var weapon_level: int = 1

## 初始化行为
## 
## @param p_weapon 所属武器节点
## @param p_params 行为参数
## @param p_calc_type 结算类型（int，对应 WeaponData.CalculationType）
## @param p_effects 特殊效果配置
func initialize(p_weapon: Node2D, p_params: Dictionary, p_calc_type: int, p_effects: Array = []) -> void:
	weapon = p_weapon
	params = p_params
	calculation_type = p_calc_type
	special_effects = p_effects
	_on_initialize()

## 设置玩家属性
func set_player_stats(stats: CombatStats) -> void:
	player_stats = stats

## 设置武器等级
func set_weapon_level(level: int) -> void:
	weapon_level = clamp(level, 1, 5)

## 获取基础伤害（从参数中读取）
func get_base_damage() -> int:
	return params.get("damage", 1)

## 获取最终伤害（应用结算类型加成）
func get_final_damage() -> int:
	var base_damage = get_base_damage()
	
	if base_damage <= 0:
		return base_damage
	
	if player_stats:
		# 使用新版方法：根据结算类型计算伤害
		return DamageCalculator.calculate_damage_by_calc_type(
			base_damage,
			weapon_level,
			calculation_type,  # 使用结算类型而非行为类型
			player_stats
		)
	else:
		# 降级方案：只应用等级倍数
		var level_mults = WeaponData.get_level_multipliers(weapon_level)
		return int(max(1.0, base_damage * level_mults.damage_multiplier))

## 暴击判定
func roll_critical() -> bool:
	if player_stats:
		return DamageCalculator.roll_critical(player_stats)
	return false

## 应用暴击伤害
func apply_critical(damage: int) -> int:
	if player_stats:
		return DamageCalculator.apply_critical_multiplier(damage, player_stats)
	return damage

## 应用特殊效果到目标
## 
## @param target 目标节点
## @param damage_dealt 造成的伤害（用于吸血等）
func apply_special_effects(target: Node, damage_dealt: int = 0) -> void:
	if not player_stats:
		return
	
	for effect_config in special_effects:
		if not effect_config is Dictionary:
			continue
		
		var effect_type = effect_config.get("type", "")
		var effect_params = effect_config.get("params", {}).duplicate()
		
		# 吸血效果需要传递伤害和攻击者
		if effect_type == "lifesteal":
			effect_params["damage_dealt"] = damage_dealt
			var attacker = weapon.get_tree().get_first_node_in_group("player") if weapon else null
			effect_params["attacker"] = attacker
		
		# 应用效果
		SpecialEffects.try_apply_status_effect(player_stats, target, effect_type, effect_params)

## 执行攻击（子类必须实现）
## 
## @param enemies 范围内的敌人列表
func perform_attack(enemies: Array) -> void:
	push_error("WeaponBehavior.perform_attack() 必须在子类中实现！")

## 每帧更新（可选覆盖）
## 
## @param delta 帧间隔
func process(delta: float) -> void:
	pass

## 物理更新（可选覆盖）
## 
## @param delta 帧间隔
func physics_process(delta: float) -> void:
	pass

## 获取攻击间隔
func get_attack_interval() -> float:
	var base_interval = params.get("attack_speed", 1.0)
	
	if player_stats:
		# 使用新版方法：根据结算类型计算攻速
		return DamageCalculator.calculate_attack_speed_by_calc_type(
			base_interval,
			weapon_level,
			calculation_type,
			player_stats
		)
	else:
		var level_mults = WeaponData.get_level_multipliers(weapon_level)
		return base_interval / level_mults.attack_speed_multiplier

## 获取攻击范围
func get_attack_range() -> float:
	var base_range = params.get("range", 500.0)
	
	if player_stats:
		# 使用新版方法：根据结算类型计算范围
		return DamageCalculator.calculate_range_by_calc_type(
			base_range,
			weapon_level,
			calculation_type,
			player_stats
		)
	else:
		var level_mults = WeaponData.get_level_multipliers(weapon_level)
		return base_range * level_mults.range_multiplier

## 子类初始化钩子
func _on_initialize() -> void:
	pass

## 获取行为类型（子类覆盖）
func get_behavior_type() -> int:
	return WeaponData.BehaviorType.MELEE
