extends Node2D
class_name ExplosionIndicator

## 魔法武器爆炸范围指示器
## 显示一个半透明的圆形区域，标识攻击目标位置和范围

## 静态共享纹理（所有指示器共用，只创建一次）
static var shared_circle_texture: Texture2D = null

## 圆形精灵
var circle_sprite: Sprite2D = null

## 淡入淡出动画
var tween: Tween = null

## 指示器颜色
var indicator_color: Color = Color(1.0, 0.5, 0.0, 0.3)  # 橙色，30%透明度

## 显示持续时间（秒）
var display_duration: float = 0.3

## 是否为持续显示模式
var is_persistent: bool = false

## 目标引用（用于持续跟随）
var follow_target: Node2D = null

func _ready() -> void:
	# 确保共享纹理已创建
	if shared_circle_texture == null:
		_create_shared_texture()
	
	# 创建圆形精灵
	_create_circle_sprite()

func _process(_delta: float) -> void:
	# 如果是持续显示且有目标，跟随目标移动
	if is_persistent and follow_target and is_instance_valid(follow_target):
		global_position = follow_target.global_position

## 创建共享纹理（静态，只执行一次）
static func _create_shared_texture() -> void:
	if shared_circle_texture != null:
		return
	
	var size = 512
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# 绘制实心圆
	var center = Vector2(size / 2, size / 2)
	var radius = size / 2
	
	for x in range(size):
		for y in range(size):
			var distance = Vector2(x, y).distance_to(center)
			if distance <= radius:
				# 添加边缘软化效果
				var alpha = 1.0
				if distance > radius - 20:
					alpha = (radius - distance) / 20.0
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	# 创建纹理并保存为静态共享资源
	shared_circle_texture = ImageTexture.create_from_image(image)

## 创建圆形精灵
func _create_circle_sprite() -> void:
	circle_sprite = Sprite2D.new()
	add_child(circle_sprite)
	
	# 使用共享纹理
	circle_sprite.texture = shared_circle_texture
	
	# 设置颜色和初始透明度
	circle_sprite.modulate = indicator_color
	circle_sprite.modulate.a = 0  # 初始完全透明

## 在指定位置显示指示器（短暂模式）
## position: 目标位置（世界坐标）
## radius: 爆炸半径
## color: 指示器颜色（可选）
## duration: 显示持续时间（可选）
func show_at(position: Vector2, radius: float, color: Color = Color(1.0, 0.5, 0.0, 0.3), duration: float = 0.3) -> void:
	if not circle_sprite:
		return
	
	is_persistent = false
	follow_target = null
	
	# 设置位置
	global_position = position
	
	# 设置缩放（根据半径）
	var scale_factor = radius / 256.0  # 256是纹理半径
	circle_sprite.scale = Vector2(scale_factor, scale_factor)
	
	# 设置颜色
	indicator_color = color
	circle_sprite.modulate = indicator_color
	
	# 设置持续时间
	display_duration = duration
	
	# 播放淡入淡出动画
	_play_animation()

## 持续显示指示器（跟随目标）
## target: 跟随的目标节点
## radius: 爆炸半径
## color: 指示器颜色
## duration: 持续显示时间（0表示无限）
func show_persistent(target: Node2D, radius: float, color: Color, duration: float = 0.0) -> void:
	if not circle_sprite or not is_instance_valid(target):
		return
	
	is_persistent = true
	follow_target = target
	display_duration = duration
	
	# 设置初始位置
	global_position = target.global_position
	
	# 设置缩放
	var scale_factor = radius / 256.0
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

