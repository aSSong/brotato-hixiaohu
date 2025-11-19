extends Control
class_name FloatingText

## 浮动文字
## 显示伤害数字等浮动文字效果

@onready var label: Label = $Label

var text: String = ""
var duration: float = 0.8
# 移除 float_speed，使用 velocity 模拟物理
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 800.0  # 重力加速度
var start_scale: float = 0.1
var peak_scale: float = 2.0  # 放大峰值
var end_scale: float = 1.0
var is_critical: bool = false
var initial_color: Color = Color.WHITE  # 存储初始颜色

func _ready() -> void:
	if label:
		label.text = text
		# 使用存储的初始颜色
		label.modulate = initial_color
		label.modulate.a = 1.0
		
		# 根据是否暴击调整字体大小和效果
		if is_critical:
			label.add_theme_font_size_override("font_size", 36)
			peak_scale = 2.0
			# 暴击时初始向上的冲力更大
			velocity.y -= 100
			# 暴击时添加描边效果
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
		else:
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 2)
	
	# 设置高Z层级，确保显示在最上层，低于ui的100
	z_index = 99
	
	scale = Vector2(start_scale, start_scale)
	
	# 开始动画
	_start_animation()

func _process(delta: float) -> void:
	# 应用重力
	velocity.y += gravity * delta
	# 更新位置
	position += velocity * delta

func _start_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 缩放动画：先放大(pop)再缩小
	# 1. 快速放大到峰值
	tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), duration * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2. 恢复到正常大小
	tween.tween_property(self, "scale", Vector2(end_scale, end_scale), duration * 0.4).set_delay(duration * 0.2)
	
	# 淡出
	if label:
		tween.tween_property(label, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	
	# 动画结束后删除
	tween.finished.connect(queue_free)

## 静态方法：创建浮动文字
static func create_floating_text(world_pos: Vector2, damage_text: String, color: Color = Color.WHITE, is_critical: bool = false) -> void:
	# 忽略0伤害
	if damage_text == "-0" or damage_text == "0":
		return
		
	var floating_text_scene = preload("res://scenes/UI/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	
	# 设置属性
	floating_text.text = damage_text
	floating_text.is_critical = is_critical
	floating_text.initial_color = color
	
	# 设置初始速度（模拟飞溅）
	# 向上的冲力
	var up_speed = randf_range(300, 500)
	# 左右的随机速度
	var side_speed = randf_range(-200, 200)
	floating_text.velocity = Vector2(side_speed, -up_speed)
	
	# 添加到CanvasLayer以便正确显示
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		# 尝试找到game_ui的CanvasLayer
		var canvas_layer = tree.root.find_child("game_ui", true, false)
		if canvas_layer:
			canvas_layer.add_child(floating_text)
			# 将世界坐标转换为屏幕坐标
			var camera = tree.get_first_node_in_group("camera")
			if camera and camera is Camera2D:
				# 使用get_viewport().get_camera_2d()或手动计算
				var viewport = tree.root.get_viewport()
				if viewport:
					var camera_pos = camera.global_position
					var zoom = camera.zoom
					var viewport_size = viewport.get_visible_rect().size
					# 计算相对于摄像机的偏移（考虑zoom）
					var offset = (world_pos - camera_pos) * zoom
					# 转换为屏幕坐标（屏幕中心为原点）
					floating_text.position = viewport_size / 2.0 + offset
				else:
					floating_text.position = world_pos
			else:
				floating_text.position = world_pos
		else:
			# 如果没有找到CanvasLayer，添加到根节点
			tree.root.add_child(floating_text)
			floating_text.position = world_pos
