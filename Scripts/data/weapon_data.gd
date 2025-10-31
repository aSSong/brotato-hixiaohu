extends Resource
class_name WeaponData

## 武器数据 Resource 类
## 定义武器的类型、属性和效果

enum WeaponType {
	RANGED,    # 远程武器（子弹）
	MELEE,     # 近战武器（旋转/挥砍）
	MAGIC      # 魔法武器（爆炸/范围）
}

@export var weapon_name: String = "默认武器"
@export var description: String = ""
@export var weapon_type: WeaponType = WeaponType.RANGED

## 基础属性
@export var damage: int = 1
@export var attack_speed: float = 0.5  # 攻击间隔（秒）
@export var range: float = 500.0  # 攻击范围

## 远程武器专用属性
@export var bullet_speed: float = 2000.0  # 子弹速度
@export var bullet_lifetime: float = 3.0  # 子弹存活时间

## 近战武器专用属性
@export var rotation_speed: float = 360.0  # 旋转速度（度/秒）
@export var swing_angle: float = 180.0  # 挥砍角度
@export var hit_range: float = 100.0  # 攻击判定范围

## 魔法武器专用属性
@export var explosion_radius: float = 150.0  # 爆炸范围
@export var explosion_damage_multiplier: float = 1.0  # 爆炸伤害倍数
@export var max_targets: int = 5  # 最大目标数量

## 特殊效果
@export var pierce_count: int = 0  # 穿透数量（0=不穿透）
@export var knockback_force: float = 0.0  # 击退力度
@export var special_effects: Dictionary = {}  # 特殊效果参数

## 武器等级颜色（复用现有系统）
const weapon_level_colors = {
	level_1 = "#b0c3d9",
	level_2 = "#4b69ff",
	level_3 = "#d32ce6",
	level_4 = "#8847ff",
	level_5 = "#eb4b4b",
}

## 初始化函数
func _init(
	p_weapon_name: String = "默认武器",
	p_weapon_type: WeaponType = WeaponType.RANGED,
	p_damage: int = 1,
	p_attack_speed: float = 0.5,
	p_range: float = 500.0
) -> void:
	weapon_name = p_weapon_name
	weapon_type = p_weapon_type
	damage = p_damage
	attack_speed = p_attack_speed
	range = p_range
