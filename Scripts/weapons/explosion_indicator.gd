extends Node2D
class_name ExplosionIndicator

## 魔法武器爆炸范围指示器
## 显示一个半透明的圆形区域，标识攻击目标位置和范围
## 修改：使用纹理替代程序化绘制，与GraveRescueManager方案一致

## 预加载的范围圈纹理（所有实例共享）
static var _circle_texture = preload("res://assets/others/rescue_range_circle.png")

## 自定义纹理（如果设置，将覆盖默认纹理）
var custom_texture: Texture2D = null

## 圆形精灵
var circle_sprite: Sprite2D = null

## 淡入淡出动画
var tween: Tween = null

## 指示器颜色（默认白色，保留纹理原色）
var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.8)

## 显示持续时间（秒）
var display_duration: float = 0.3

## 是否为持续显示模式
var is_persistent: bool = false

## 目标引用（用于持续跟随）
var follow_target: Node2D = null

func _ready() -> void:
	# 创建圆形精灵
	_create_circle_sprite()

func _process(_delta: float) -> void:
	# 如果是持续显示且有目标，跟随目标移动
	if is_persistent and follow_target and is_instance_valid(follow_target):
		global_position = follow_target.global_position
	# 如果没有目标，保持在原位置（固定位置模式）

## 设置自定义纹理
func set_texture(texture: Texture2D) -> void:
	custom_texture = texture
	if circle_sprite:
		circle_sprite.texture = custom_texture

## 创建圆形精灵
func _create_circle_sprite() -> void:
	circle_sprite = Sprite2D.new()
	add_child(circle_sprite)
	
	# 使用自定义纹理或默认纹理
	if custom_texture:
		circle_sprite.texture = custom_texture
	else:
		circle_sprite.texture = _circle_texture
	
	# 设置颜色和初始透明度
	circle_sprite.modulate = indicator_color
	circle_sprite.modulate.a = 0  # 初始完全透明

## 在指定位置显示指示器（短暂模式）
## position: 目标位置（世界坐标）
## radius: 爆炸半径
## color: 指示器颜色（可选）
## duration: 显示持续时间（可选）
func show_at(position: Vector2, radius: float, color: Color = Color(1.0, 1.0, 1.0, 0.8), duration: float = 0.3) -> void:
	if not circle_sprite:
		return
	
	is_persistent = false
	follow_target = null
	
	# 设置位置
	global_position = position
	
	# 获取当前使用的纹理
	var current_texture = circle_sprite.texture
	var texture_size = 0.0
	if current_texture:
		texture_size = current_texture.get_size().x
	
	# 设置缩放（根据半径和纹理尺寸）
	var target_diameter = radius * 2.0
	var scale_factor = 1.0
	if texture_size > 0:
		scale_factor = target_diameter / texture_size
	
	circle_sprite.scale = Vector2(scale_factor, scale_factor)
	
	# 设置颜色
	indicator_color = color
	circle_sprite.modulate = indicator_color
	
	# 设置持续时间
	display_duration = duration
	
	# 播放淡入淡出动画
	_play_animation()

## 持续显示指示器（跟随目标或固定位置）
## target: 跟随的目标节点（可以为null，表示固定位置）
## radius: 爆炸半径
## color: 指示器颜色
## duration: 持续显示时间（0表示无限）
func show_persistent(target: Node2D, radius: float, color: Color, duration: float = 0.0) -> void:
	if not circle_sprite:
		return
	
	is_persistent = true
	follow_target = target  # 可以是null
	display_duration = duration
	
	# 设置初始位置
	if target and is_instance_valid(target):
		global_position = target.global_position
	# 如果target为null，保持当前位置（由调用者设置）
	
	# 获取当前使用的纹理
	var current_texture = circle_sprite.texture
	var texture_size = 0.0
	if current_texture:
		texture_size = current_texture.get_size().x
	
	# 设置缩放
	var target_diameter = radius * 2.0
	var scale_factor = 1.0
	if texture_size > 0:
		scale_factor = target_diameter / texture_size
		
	circle_sprite.scale = Vector2(scale_factor, scale_factor)
	
	# 设置颜色
	indicator_color = color
	circle_sprite.modulate = indicator_color
	
	# 播放持续显示动画
	_play_persistent_animation()

## 播放淡入淡出动画（短暂显示）
func _play_animation() -> void:
	# 停止之前的动画
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	
	# 淡入（快速）
	circle_sprite.modulate.a = 0
	tween.tween_property(circle_sprite, "modulate:a", indicator_color.a, 0.05)
	
	# 保持
	tween.tween_interval(display_duration - 0.1)
	
	# 淡出
	tween.tween_property(circle_sprite, "modulate:a", 0.0, 0.05)
	
	# 动画结束后删除自己
	tween.tween_callback(queue_free)

## 播放持续显示动画
func _play_persistent_animation() -> void:
	# 停止之前的动画
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	
	# 淡入
	circle_sprite.modulate.a = 0
	tween.tween_property(circle_sprite, "modulate:a", indicator_color.a, 0.1)
	
	# 如果有持续时间限制
	if display_duration > 0:
		tween.tween_interval(display_duration - 0.15)
		tween.tween_property(circle_sprite, "modulate:a", 0.0, 0.05)
		tween.tween_callback(queue_free)

## 立即隐藏并删除
func hide_and_remove() -> void:
	if tween and tween.is_valid():
		tween.kill()
	queue_free()

## 淡出并删除（用于提前取消）
func fade_out_and_remove(fade_time: float = 0.1) -> void:
	if tween and tween.is_valid():
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(circle_sprite, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
