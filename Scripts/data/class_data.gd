extends Resource
class_name ClassData

## 职业数据 Resource 类
## 定义职业的基础属性和技能信息

@export var name: String = "默认职业"
@export var description: String = ""

## 基础属性
@export var max_hp: int = 100
@export var speed: float = 400.0
@export var attack_multiplier: float = 1.0  # 攻击力倍数（所有武器）
@export var defense: int = 0  # 防御力（固定减伤）
@export var crit_chance: float = 0.0  # 暴击率 (0.0-1.0)
@export var crit_damage: float = 1.5  # 暴击伤害倍数

## 战斗属性系数
@export var damage_reduction_multiplier: float = 1.0  # 减伤系数（1.0=不减伤，0.8=减伤20%）
@export var luck: float = 0.0  # 幸运值（预留，影响掉落）

## 武器通用系数
@export var attack_speed_multiplier: float = 1.0  # 攻击速度系数（所有武器）

## 近战武器系数
@export var melee_damage_multiplier: float = 1.0  # 近战武器伤害系数
@export var melee_range_multiplier: float = 1.0  # 近战武器范围系数
@export var melee_speed_multiplier: float = 1.0  # 近战武器速度系数
@export var melee_knockback_multiplier: float = 1.0  # 近战武器击退系数

## 远程武器系数（枪械）
@export var ranged_damage_multiplier: float = 1.0  # 远程武器伤害系数
@export var ranged_range_multiplier: float = 1.0  # 远程武器范围系数
@export var ranged_speed_multiplier: float = 1.0  # 远程武器速度系数

## 魔法武器系数
@export var magic_damage_multiplier: float = 1.0  # 魔法武器伤害系数
@export var magic_range_multiplier: float = 1.0  # 魔法武器范围系数
@export var magic_speed_multiplier: float = 1.0  # 魔法武器速度系数（魔法冷却）
@export var magic_explosion_radius_multiplier: float = 1.0  # 魔法武器爆炸范围系数

## 特殊技能配置
@export var skill_name: String = ""
@export var skill_description: String = ""
@export var skill_params: Dictionary = {}  # 技能参数，例如：{"cooldown": 5.0, "damage_boost": 1.5}

## 职业特性（被动效果描述，自动生成）
@export var traits: Array = []  # 特性列表，例如：["近战武器伤害+20%", "血量+50"]

## 初始化函数
func _init(
	p_name: String = "默认职业",
	p_max_hp: int = 100,
	p_speed: float = 400.0,
	p_attack_multiplier: float = 1.0,
	p_defense: int = 0,
	p_crit_chance: float = 0.0,
	p_crit_damage: float = 1.5,
	p_skill_name: String = "",
	p_skill_params: Dictionary = {}
) -> void:
	name = p_name
	max_hp = p_max_hp
	speed = p_speed
	attack_multiplier = p_attack_multiplier
	defense = p_defense
	crit_chance = p_crit_chance
	crit_damage = p_crit_damage
	skill_name = p_skill_name
	skill_params = p_skill_params
	
	# 新属性使用默认值，由调用者在创建后手动设置

## 自动生成职业特性描述
func generate_traits_description() -> void:
	traits.clear()
	
	# 基础属性
	if max_hp != 100:
		var diff = max_hp - 100
		traits.append("血量%+d" % diff if diff > 0 else "血量%d" % diff)
	
	if speed != 400.0:
		var percent = int((speed / 400.0 - 1.0) * 100)
		if percent != 0:
			traits.append("移动速度%+d%%" % percent if percent > 0 else "移动速度%d%%" % percent)
	
	if defense != 0:
		traits.append("防御%+d" % defense if defense > 0 else "防御%d" % defense)
	
	# 战斗属性
	if damage_reduction_multiplier != 1.0:
		var percent = int((1.0 - damage_reduction_multiplier) * 100)
		if percent != 0:
			traits.append("受到伤害%+d%%" % -percent if percent > 0 else "受到伤害%d%%" % -percent)
	
	# 总攻击速度
	if attack_speed_multiplier != 1.0:
		var percent = int((attack_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("攻击速度%+d%%" % percent if percent > 0 else "攻击速度%d%%" % percent)
	
	# 总武器伤害
	if attack_multiplier != 1.0:
		var percent = int((attack_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("所有武器伤害%+d%%" % percent if percent > 0 else "所有武器伤害%d%%" % percent)
	
	# 近战武器
	if melee_damage_multiplier != 1.0:
		var percent = int((melee_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器伤害%+d%%" % percent if percent > 0 else "近战武器伤害%d%%" % percent)
	
	if melee_speed_multiplier != 1.0:
		var percent = int((melee_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器速度%+d%%" % percent if percent > 0 else "近战武器速度%d%%" % percent)
	
	if melee_range_multiplier != 1.0:
		var percent = int((melee_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器范围%+d%%" % percent if percent > 0 else "近战武器范围%d%%" % percent)
	
	if melee_knockback_multiplier != 1.0:
		var percent = int((melee_knockback_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器击退%+d%%" % percent if percent > 0 else "近战武器击退%d%%" % percent)
	
	# 远程武器
	if ranged_damage_multiplier != 1.0:
		var percent = int((ranged_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器伤害%+d%%" % percent if percent > 0 else "远程武器伤害%d%%" % percent)
	
	if ranged_speed_multiplier != 1.0:
		var percent = int((ranged_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器速度%+d%%" % percent if percent > 0 else "远程武器速度%d%%" % percent)
	
	if ranged_range_multiplier != 1.0:
		var percent = int((ranged_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器范围%+d%%" % percent if percent > 0 else "远程武器范围%d%%" % percent)
	
	# 魔法武器
	if magic_damage_multiplier != 1.0:
		var percent = int((magic_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法武器伤害%+d%%" % percent if percent > 0 else "魔法武器伤害%d%%" % percent)
	
	if magic_speed_multiplier != 1.0:
		var percent = int((magic_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法冷却%+d%%" % percent if percent > 0 else "魔法冷却%d%%" % percent)
	
	if magic_range_multiplier != 1.0:
		var percent = int((magic_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法武器范围%+d%%" % percent if percent > 0 else "魔法武器范围%d%%" % percent)
	
	if magic_explosion_radius_multiplier != 1.0:
		var percent = int((magic_explosion_radius_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("爆炸范围%+d%%" % percent if percent > 0 else "爆炸范围%d%%" % percent)
