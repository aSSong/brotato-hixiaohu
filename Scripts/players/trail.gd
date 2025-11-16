extends Line2D
class_name Trail

@export var trail_length := 25
@export var trail_duration := 1.0

var trail_timer: Timer = null
var player: CharacterBody2D = null
var points_array: Array[Vector2] = []
var global_points_array: Array[Vector2] = []  # 存储全局坐标
var is_active := false

func _ready() -> void:
	# 获取玩家节点（父节点）
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("[Trail] 无法找到玩家节点")
	
	# 创建Timer节点
	trail_timer = Timer.new()
	trail_timer.name = "TrailTimer"
	trail_timer.wait_time = trail_duration
	trail_timer.one_shot = true
	trail_timer.timeout.connect(_on_trail_timer_timeout)
	add_child(trail_timer)
	
	# 设置Line2D属性
	#default_color = Color(1.0, 1.0, 1.0, 0.5)  # 半透明白色
	#width = 8.0  # 增加线条宽度
	z_index = 1  # 确保在玩家下方显示
	# 确保Trail节点位置为(0,0)，相对于父节点
	position = Vector2.ZERO

func _process(delta: float) -> void:
	if not is_active or player == null:
		return
		
	# 记录player的全局位置
	global_points_array.append(player.global_position)
	if global_points_array.size() > trail_length:
		global_points_array.pop_front()
	
	# 将全局坐标转换为本地坐标（相对于当前player位置）
	points_array.clear()
	for global_pos in global_points_array:
		var local_pos = to_local(global_pos)
		points_array.append(local_pos)
		
	points = points_array
		
func start_trail() -> void:
	if player == null:
		return
		
	is_active = true
	clear_points()
	points_array.clear()
	global_points_array.clear()
	# 添加初始位置
	global_points_array.append(player.global_position)
	if trail_timer:
		trail_timer.start(trail_duration)

func _on_trail_timer_timeout() -> void:
	is_active = false
	clear_points()
	points_array.clear()
	global_points_array.clear()
