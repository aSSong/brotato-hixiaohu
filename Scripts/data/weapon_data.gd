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

## 外观设置
@export var texture_path: String = "res://assets/weapon/weapon1.png"  # 武器贴图路径
@export var scale: Vector2 = Vector2(7, 7)  # 武器缩放
@export var sprite_offset: Vector2 = Vector2.ZERO  # 贴图偏移

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

## 武器等级颜色（白、绿、蓝、紫、红）
const weapon_level_colors = {
	level_1 = "#FFFFFF",  # 白色
	level_2 = "#00FF00",  # 绿色
	level_3 = "#0000FF",  # 蓝色
	level_4 = "#FF00FF",  # 紫色
	level_5 = "#FF0000",  # 红色
}

## 获取指定等级的参数倍数
## 返回字典：{"damage_multiplier": 1.0, "attack_speed_multiplier": 1.0, ...}
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

## 初始化函数
func _init(
	p_weapon_name: String = "默认武器",
	p_weapon_type: WeaponType = WeaponType.RANGED,
	p_damage: int = 1,
	p_attack_speed: float = 0.5,
	p_range: float = 500.0,
	p_texture_path: String = "res://assets/weapon/weapon1.png",
	p_scale: Vector2 = Vector2(7, 7)
) -> void:
	weapon_name = p_weapon_name
	weapon_type = p_weapon_type
	damage = p_damage
	attack_speed = p_attack_speed
	range = p_range
	texture_path = p_texture_path
	scale = p_scale
