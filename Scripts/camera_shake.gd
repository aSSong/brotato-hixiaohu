extends Node

var camera: Camera2D
var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	# 自动找到场景中的摄像机
	call_deferred("find_camera")

func find_camera() -> void:
	camera = get_tree().get_first_node_in_group("camera")
	if camera == null:
		# 如果没有组,尝试查找第一个 Camera2D
		var root = get_tree().root
		camera = find_camera_recursive(root)

func find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = find_camera_recursive(child)
		if result != null:
			return result
	return null

func _process(delta: float) -> void:
	if camera == null or shake_timer <= 0:
		return
	
	shake_timer -= delta
	
	if shake_timer > 0:
		# 随机偏移
		camera.offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		# 震动结束,恢复原位
		camera.offset = Vector2.ZERO
		shake_amount = 0.0

func shake(duration: float = 0.3, amount: float = 10.0) -> void:
	shake_duration = duration
	shake_amount = amount
	shake_timer = duration
