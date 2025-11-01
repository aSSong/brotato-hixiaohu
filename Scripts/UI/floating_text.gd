extends Control
class_name FloatingText

## 浮动文字
## 显示伤害数字等浮动文字效果

@onready var label: Label = $Label

var text: String = ""
var duration: float = 1.0
var float_speed: float = 50.0  # 向上飘的速度
var start_scale: float = 0.5
var end_scale: float = 1.0

func _ready() -> void:
	if label:
		label.text = text
		label.modulate.a = 1.0
		scale = Vector2(start_scale, start_scale)
	
	# 开始动画
	_start_animation()

func _start_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 向上移动
	tween.tween_property(self, "position:y", position.y - float_speed, duration)
	
	# 缩放动画
	tween.tween_property(self, "scale", Vector2(end_scale, end_scale), duration * 0.3)
	tween.tween_property(self, "scale", Vector2(end_scale * 0.8, end_scale * 0.8), duration * 0.7).set_delay(duration * 0.3)
	
	# 淡出
	if label:
		tween.tween_property(label, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	
	# 动画结束后删除
	tween.finished.connect(queue_free)

## 静态方法：创建浮动文字
static func create_floating_text(world_pos: Vector2, damage_text: String, color: Color = Color.WHITE) -> void:
	var floating_text_scene = preload("res://scenes/UI/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	
	# 设置文字
	floating_text.text = damage_text
	
	# 设置颜色
	if floating_text.label:
		floating_text.label.modulate = color
	
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
