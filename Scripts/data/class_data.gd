extends Resource
class_name ClassData

## 职业数据 Resource 类
## 定义职业的基础属性和技能信息

@export var name: String = "默认职业"
@export var description: String = ""

## 基础属性
@export var max_hp: int = 100
@export var speed: float = 400.0
@export var attack_multiplier: float = 1.0  # 攻击力倍数
@export var defense: int = 0  # 防御力
@export var crit_chance: float = 0.0  # 暴击率 (0.0-1.0)
@export var crit_damage: float = 1.5  # 暴击伤害倍数

## 特殊技能配置
@export var skill_name: String = ""
@export var skill_description: String = ""
@export var skill_params: Dictionary = {}  # 技能参数，例如：{"cooldown": 5.0, "damage_boost": 1.5}

## 职业特性（被动效果）
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
