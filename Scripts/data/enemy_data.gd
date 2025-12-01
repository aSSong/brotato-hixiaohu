extends Resource
class_name EnemyData

## 敌人数据 Resource 类
## 定义敌人的属性：HP、攻击力、移动速度、贴图等

## 技能类型枚举
enum EnemySkillType {
	NONE,      # 无技能
	CHARGING,  # 冲锋技能
	SHOOTING,  # 射击技能
	EXPLODING  # 自爆技能
}

@export var enemy_name: String = "默认敌人"
@export var description: String = ""

## 技能配置
@export var skill_type: EnemySkillType = EnemySkillType.NONE
@export var skill_config: Dictionary = {}  # 技能参数字典

## 外观设置
@export var texture_path: String = "res://assets/enemy/enemy-sheet.png"  # 敌人贴图路径

## 动画帧配置（单行排列）
@export var frame_width: int = 240  # 每帧宽度
@export var frame_height: int = 240  # 每帧高度
@export var frame_count: int = 5  # 帧数量（横向排列，全用上）
@export var animation_speed: float = 8.0  # 动画速度（FPS）

@export var scale: Vector2 = Vector2(0.6, 0.6)  # 敌人缩放

## Shadow配置（可选，如果为Vector2.ZERO则使用场景默认值）
@export var shadow_scale: Vector2 = Vector2.ZERO  # Shadow缩放，Vector2.ZERO表示使用场景默认值
@export var shadow_offset: Vector2 = Vector2.ZERO  # Shadow相对偏移，Vector2.ZERO表示使用场景默认值

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

## 缓存的SpriteFrames（避免每个敌人都创建新的）
var _cached_sprite_frames: SpriteFrames = null
var _cached_texture: Texture2D = null

## 获取缓存的SpriteFrames（懒加载，只创建一次）
func get_sprite_frames() -> SpriteFrames:
	# 如果已经缓存了，直接返回
	if _cached_sprite_frames != null:
		return _cached_sprite_frames
	
	# 加载纹理（只加载一次）
	if _cached_texture == null:
		if texture_path == "":
			return null
		_cached_texture = load(texture_path)
		if _cached_texture == null:
			push_error("[EnemyData] 无法加载纹理: %s" % texture_path)
			return null
	
	# 创建SpriteFrames
	_cached_sprite_frames = SpriteFrames.new()
	_cached_sprite_frames.set_animation_loop("default", true)
	
	# 添加所有帧（单行横向排列）
	for i in range(frame_count):
		var x = i * frame_width
		var y = 0  # 单行，y始终为0
		
		# 创建AtlasTexture
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = _cached_texture
		atlas_texture.region = Rect2(x, y, frame_width, frame_height)
		
		_cached_sprite_frames.add_frame("default", atlas_texture)
	
	# 设置动画速度
	_cached_sprite_frames.set_animation_speed("default", animation_speed)
	
	return _cached_sprite_frames

## 初始化函数
func _init(
	p_enemy_name: String = "默认敌人",
	p_max_hp: int = 50,
	p_attack_damage: int = 5,
	p_move_speed: float = 300.0,
	p_texture_path: String = "res://assets/enemy/enemy-sheet.png",
	p_frame_width: int = 240,
	p_frame_height: int = 240,
	p_frame_count: int = 5
) -> void:
	enemy_name = p_enemy_name
	max_hp = p_max_hp
	attack_damage = p_attack_damage
	move_speed = p_move_speed
	texture_path = p_texture_path
	frame_width = p_frame_width
	frame_height = p_frame_height
	frame_count = p_frame_count

