extends Resource
class_name EnemyBulletData

## 敌人子弹数据 Resource 类
## 定义子弹的属性：速度、伤害、外观等

@export var bullet_name: String = "默认子弹"
@export var description: String = ""

## 基础属性
@export var speed: float = 400.0  # 子弹速度
@export var damage: int = 10  # 伤害值
@export var life_time: float = 3.0  # 最长存活时间（秒）

## 外观设置
@export var texture_path: String = "res://assets/bullet/bullet.png"  # 子弹贴图路径
@export var scale: Vector2 = Vector2(0.4, 0.4)  # 子弹缩放

## 碰撞设置
@export var collision_radius: float = 35.0  # 碰撞半径

## 特殊效果（未来扩展）
@export var pierce_count: int = 0  # 穿透数量（0表示不穿透）
@export var explosion_on_hit: bool = false  # 命中时爆炸
@export var explosion_range: float = 0.0  # 爆炸范围
@export var explosion_damage: int = 0  # 爆炸伤害

## 初始化函数
func _init(
	p_bullet_name: String = "默认子弹",
	p_speed: float = 400.0,
	p_damage: int = 10,
	p_life_time: float = 3.0,
	p_texture_path: String = "res://assets/bullet/bullet.png"
) -> void:
	bullet_name = p_bullet_name
	speed = p_speed
	damage = p_damage
	life_time = p_life_time
	texture_path = p_texture_path

