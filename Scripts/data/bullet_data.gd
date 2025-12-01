extends Resource
class_name BulletData

## 子弹数据配置类
## 
## 定义子弹的外观、速度、移动方式等属性
## 用于 RangedBehavior 配置不同类型的子弹

## 子弹移动类型枚举
enum MovementType {
	STRAIGHT,   # 直线飞行
	HOMING,     # 追踪目标
	BOUNCE,     # 弹跳
	WAVE,       # 波浪形
	SPIRAL,     # 螺旋
}

## 基础信息
@export var bullet_id: String = "default"
@export var bullet_name: String = "默认子弹"

## 外观设置
@export var texture_path: String = "res://assets/bullet/bullet.png"
@export var scale: Vector2 = Vector2(1.0, 1.0)
@export var modulate: Color = Color.WHITE

## 基础属性
@export var speed: float = 2000.0
@export var lifetime: float = 3.0

## 视觉效果
@export var trail_effect_path: String = ""  # 轨迹特效场景路径
@export var hit_effect_path: String = ""    # 命中特效场景路径
@export var muzzle_effect_path: String = "" # 枪口特效路径

## 移动类型
@export var movement_type: MovementType = MovementType.STRAIGHT

## 移动参数（根据 movement_type 使用不同参数）
## STRAIGHT: 无额外参数
## HOMING: {"turn_speed": 5.0, "acceleration": 100.0}
## BOUNCE: {"bounce_count": 3, "bounce_loss": 0.8}
## WAVE: {"amplitude": 50.0, "frequency": 3.0}
## SPIRAL: {"spiral_speed": 360.0, "spiral_radius": 20.0}
@export var movement_params: Dictionary = {}

## 碰撞设置
@export var collision_radius: float = 8.0
@export var destroy_on_hit: bool = true  # 命中后是否销毁

## 初始化
func _init(
	p_bullet_id: String = "default",
	p_speed: float = 2000.0,
	p_lifetime: float = 3.0,
	p_texture_path: String = "res://assets/bullet/bullet.png"
) -> void:
	bullet_id = p_bullet_id
	speed = p_speed
	lifetime = p_lifetime
	texture_path = p_texture_path

## 创建子弹的副本
func duplicate_data() -> BulletData:
	var copy = BulletData.new()
	copy.bullet_id = bullet_id
	copy.bullet_name = bullet_name
	copy.texture_path = texture_path
	copy.scale = scale
	copy.modulate = modulate
	copy.speed = speed
	copy.lifetime = lifetime
	copy.trail_effect_path = trail_effect_path
	copy.hit_effect_path = hit_effect_path
	copy.muzzle_effect_path = muzzle_effect_path
	copy.movement_type = movement_type
	copy.movement_params = movement_params.duplicate()
	copy.collision_radius = collision_radius
	copy.destroy_on_hit = destroy_on_hit
	return copy

