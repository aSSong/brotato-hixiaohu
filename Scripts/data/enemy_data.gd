extends Resource
class_name EnemyData

## 敌人数据 Resource 类
## 定义敌人的属性：HP、攻击力、移动速度、贴图等

@export var enemy_name: String = "默认敌人"
@export var description: String = ""

## 外观设置
@export var texture_path: String = "res://assets/enemy/enemy-sheet.png"  # 敌人贴图路径
@export var sprite_frames_region: Rect2 = Rect2(0, 0, 240, 240)  # 贴图区域（用于AtlasTexture）
@export var scale: Vector2 = Vector2(0.6, 0.6)  # 敌人缩放

## 属性
@export var max_hp: int = 50  # 最大血量
@export var attack_damage: int = 5  # 攻击力
@export var move_speed: float = 300.0  # 移动速度
@export var attack_interval: float = 1.0  # 攻击间隔（秒）
@export var attack_range: float = 80.0  # 攻击范围

## 特殊效果
@export var shake_on_death: bool = true  # 死亡时震动
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

## 初始化函数
func _init(
	p_enemy_name: String = "默认敌人",
	p_max_hp: int = 50,
	p_attack_damage: int = 5,
	p_move_speed: float = 300.0,
	p_texture_path: String = "res://assets/enemy/enemy-sheet.png",
	p_sprite_frames_region: Rect2 = Rect2(0, 0, 240, 240)
) -> void:
	enemy_name = p_enemy_name
	max_hp = p_max_hp
	attack_damage = p_attack_damage
	move_speed = p_move_speed
	texture_path = p_texture_path
	sprite_frames_region = p_sprite_frames_region

