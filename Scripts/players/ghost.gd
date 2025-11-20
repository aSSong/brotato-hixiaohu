extends CharacterBody2D
class_name Ghost

## Ghost跟随玩家的测试功能
## Ghost拥有随机职业外观和随机武器，但没有HP等属性
## 武器会自动攻击敌人，但Ghost本身不会受到伤害

@onready var ghostAni: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapons_node: Node2D = $now_weapons

## 跟随目标（玩家或前一个Ghost）
var follow_target: Node2D = null

## 路径记录间隔（像素）
var path_record_distance: float = 5.0

## 目标路径点队列（贪吃蛇式跟随）
var target_path_points: Array = []

## 跟随距离（用于确定路径点队列长度）
var follow_distance: float = 5.0

## 跟随速度（与玩家速度同步）
var follow_speed: float = 400.0

## 职业ID（用于外观）
var class_id: String = ""

## 武器列表（武器ID和等级）
var ghost_weapons: Array = []

## Ghost在队列中的索引
var queue_index: int = 0

## 当前目标路径点索引
var current_path_index: int = 0

## Ghost自己的路径历史（供后续Ghost使用）
var path_history: Array = []
var last_recorded_position: Vector2 = Vector2.ZERO
var max_path_points: int = 300  # 最多记录的路径点数量
const PATH_HISTORY_MIN_CAPACITY: int = 60
const PATH_HISTORY_MAX_CAPACITY: int = 2000
const PATH_HISTORY_MARGIN_POINTS: int = 12  # 额外冗余，避免刚好触发裁剪

## 跟随间隔调试开关与状态
var spacing_debug_enabled: bool = true
var spacing_debug_allow_unlisted_events: bool = false
var spacing_debug_allowed_events := {
	"path_index_adjusted": true,
	"path_points_became_empty": true,
	"clamp_path_index": true,
	"alignment_started": true,
	"alignment_completed": true,
	"alignment_aborted": true
}
var _was_within_follow_distance: bool = false
var _using_path_points: bool = false
var _spacing_debug_time_accumulator: float = 0.0
var _has_logged_speed: bool = false
var _last_logged_speed: float = 0.0
var _has_logged_path_signature: bool = false
var _last_path_signature_size: int = -1
var _last_path_signature_length: float = 0.0
var spacing_debug_speed_epsilon: float = 0.5
var spacing_debug_path_length_epsilon: float = 0.5
var _chain_follow_initialized: bool = false
var _alignment_in_progress: bool = false
var _alignment_target: Vector2 = Vector2.ZERO
var _alignment_fast_speed_multiplier: float = 3.0
var _alignment_snap_distance: float = 8.0

## Ghost的名字和死亡次数（用于显示）
var ghost_player_name: String = ""
var ghost_total_death_count: int = 0

## 名字显示Label
var name_label: Label = null

func _log_spacing_event(event_name: String, extra_data: Dictionary = {}) -> void:
	if not spacing_debug_enabled:
		return
	
	if spacing_debug_allow_unlisted_events:
		# 仅当明确禁用该事件时跳出
		if spacing_debug_allowed_events.has(event_name) and not spacing_debug_allowed_events[event_name]:
			return
	else:
		# 仅允许白名单事件
		if not spacing_debug_allowed_events.get(event_name, false):
			return
	
	var target_name := "null"
	var distance_to_target := -1.0
	if follow_target != null and is_instance_valid(follow_target):
		target_name = str(follow_target.name)
		distance_to_target = global_position.distance_to(follow_target.global_position)
	
	var next_point_distance := -1.0
	if not target_path_points.is_empty():
		var idx = clamp(current_path_index, 0, target_path_points.size() - 1)
		if idx >= 0 and idx < target_path_points.size():
			next_point_distance = global_position.distance_to(target_path_points[idx])
	
	var base_message = "[Ghost spacing] %s | ghost:%s idx:%d target:%s dist_target:%.2f follow_dist:%.2f record_dist:%.2f next_point_dist:%.2f path_points:%d path_index:%d elapsed:%.2f" % [
		event_name,
		name,
		queue_index,
		target_name,
		distance_to_target,
		follow_distance,
		path_record_distance,
		next_point_distance,
		target_path_points.size(),
		current_path_index,
		_spacing_debug_time_accumulator
	]
	
	if not extra_data.is_empty():
		var extra_parts: Array[String] = []
		for key in extra_data.keys():
			extra_parts.append("%s=%s" % [str(key), str(extra_data[key])])
		base_message += " | " + ", ".join(extra_parts)
	
	print(base_message)

func _compute_path_length(points: Array) -> float:
	if points.size() < 2:
		return 0.0
	var total_distance := 0.0
	for i in range(1, points.size()):
		total_distance += points[i - 1].distance_to(points[i])
	return total_distance

func _ready() -> void:
	# Ghost不会与其他物体碰撞（只是视觉效果）
	collision_layer = 0
	collision_mask = 0
	
	# 添加到ghost组
	add_to_group("ghost")
	
	# 设置z_index略低于玩家
	z_index = 9
	
	# 初始化路径记录
	last_recorded_position = global_position
	path_history.append(global_position)
	
	# 调试：检查_ready时ghost_weapons的状态
	print("[Ghost _ready] ghost_weapons数量:", ghost_weapons.size(), " class_id:", class_id)
	
	# 监听玩家死亡和复活信号
	call_deferred("_connect_death_signals")

func _process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	
	if spacing_debug_enabled:
		_spacing_debug_time_accumulator += delta

	if _alignment_in_progress:
		if _update_alignment(delta):
			_record_path_point()
		return
		
	# 使用贪吃蛇式跟随
	_snake_follow()
	
	# 记录Ghost自己的路径（供后续Ghost使用）
	_record_path_point()

## 贪吃蛇式跟随逻辑
func _snake_follow() -> void:
	# 如果目标路径点队列为空，直接跟随目标
	if target_path_points.is_empty():
		if _using_path_points:
			_using_path_points = false
			_log_spacing_event("path_points_became_empty")
		_direct_follow()
		return
	elif not _using_path_points:
		_using_path_points = true
		_log_spacing_event("path_points_available", {"points": target_path_points.size()})
	
	# 获取当前目标点
	if current_path_index >= target_path_points.size():
		current_path_index = target_path_points.size() - 1
		_log_spacing_event("clamp_path_index", {"new_index": current_path_index})
	
	if current_path_index < 0:
		return
	
	var target_point = target_path_points[current_path_index]
	var distance_to_point = global_position.distance_to(target_point)
	var near_final_segment = current_path_index >= max(0, target_path_points.size() - 2)
	if near_final_segment and distance_to_point <= follow_distance * 1.2:
		global_position = target_point
		velocity = Vector2.ZERO
		return
	
	# 如果接近当前路径点，移动到下一个路径点
	if distance_to_point < path_record_distance:
		var previous_index = current_path_index
		current_path_index += 1
		if current_path_index >= target_path_points.size():
			current_path_index = target_path_points.size() - 1
		_log_spacing_event("advance_path_point", {
			"distance_to_point": distance_to_point,
			"from_index": previous_index,
			"to_index": current_path_index
		})
		return
	
	# 移动向当前路径点
	var direction = (target_point - global_position).normalized()
	velocity = direction * follow_speed
	move_and_slide()
	
	# 根据移动方向翻转精灵
	if direction.x > 0:
		ghostAni.flip_h = true
	else:
		ghostAni.flip_h = false

## 直接跟随逻辑（作为备用）
func _direct_follow() -> void:
	var distance_to_target = global_position.distance_to(follow_target.global_position)
	
	var within_follow_distance = distance_to_target <= follow_distance
	if within_follow_distance != _was_within_follow_distance:
		_was_within_follow_distance = within_follow_distance
		if within_follow_distance:
			_log_spacing_event("direct_follow_within_range", {"distance_to_target": distance_to_target})
		else:
			_log_spacing_event("direct_follow_chasing", {"distance_to_target": distance_to_target})
	
	if distance_to_target > follow_distance:
		var direction = (follow_target.global_position - global_position).normalized()
		velocity = direction * follow_speed
		move_and_slide()
		
		# 根据移动方向翻转精灵
		if direction.x > 0:
			ghostAni.flip_h = false
		else:
			ghostAni.flip_h = true
	else:
		velocity = Vector2.ZERO

## 更新目标路径点（由跟随目标调用）
func update_path_points(points: Array) -> void:
	target_path_points = points.duplicate()
	_using_path_points = not target_path_points.is_empty()
	var previous_index = current_path_index
	# 确保索引有效
	if current_path_index >= target_path_points.size():
		current_path_index = max(0, target_path_points.size() - 1)
	_retarget_path_index_to_nearest_point()
	if current_path_index != previous_index:
		_log_spacing_event("path_index_adjusted", {"from": previous_index, "to": current_path_index})

func ensure_chain_alignment(path_points: Array) -> void:
	if path_points.is_empty():
		return
	var anchor_point: Vector2 = path_points[0]
	var distance := global_position.distance_to(anchor_point)
	if not _chain_follow_initialized or path_history.size() <= 1:
		_start_alignment(anchor_point, path_points, true)
	elif distance > follow_distance * 8.0:
		if not _alignment_in_progress or _alignment_target != anchor_point:
			_start_alignment(anchor_point, path_points, false)

func _start_alignment(anchor_point: Vector2, path_points: Array, immediate: bool) -> void:
	_chain_follow_initialized = true
	if immediate:
		_alignment_in_progress = false
		global_position = anchor_point
		velocity = Vector2.ZERO
		current_path_index = min(1, max(0, path_points.size() - 1))
		last_recorded_position = anchor_point
		path_history.clear()
		path_history.append(anchor_point)
	else:
		_alignment_target = anchor_point
		_alignment_in_progress = true
		current_path_index = min(1, max(0, path_points.size() - 1))
		_log_spacing_event("alignment_started", {
			"distance": global_position.distance_to(anchor_point)
		})

func _update_alignment(delta: float) -> bool:
	if not _alignment_in_progress:
		return false
	var to_target = _alignment_target - global_position
	var distance = to_target.length()
	if distance <= _alignment_snap_distance:
		global_position = _alignment_target
		velocity = Vector2.ZERO
		_alignment_in_progress = false
		last_recorded_position = global_position
		path_history.clear()
		path_history.append(global_position)
		_log_spacing_event("alignment_completed", {"rest_distance": distance})
		return false
	var move_distance = follow_speed * _alignment_fast_speed_multiplier * delta
	if move_distance <= 0.0:
		move_distance = distance
	var step = to_target.normalized() * min(move_distance, distance)
	global_position += step
	return true

func _retarget_path_index_to_nearest_point() -> void:
	if target_path_points.is_empty():
		return
	var search_radius: int = 6
	var start_idx: int = max(0, current_path_index - search_radius)
	var end_idx: int = min(target_path_points.size() - 1, current_path_index + search_radius)
	var best_idx: int = current_path_index
	var best_distance: float = INF
	for i in range(start_idx, end_idx + 1):
		var d: float = global_position.distance_squared_to(target_path_points[i])
		if d < best_distance:
			best_distance = d
			best_idx = i
	current_path_index = best_idx

## 初始化Ghost
func initialize(target: Node2D, index: int, player_speed: float, use_existing_data: bool = false) -> void:
	print("[Ghost initialize] 开始 | use_existing_data:", use_existing_data, " ghost_weapons数量:", ghost_weapons.size(), " class_id:", class_id)
	
	follow_target = target
	queue_index = index
	follow_speed = player_speed
	
	# 设置初始位置为目标当前位置（不要偏移太远）
	if target:
		global_position = target.global_position
	
	# 如果不使用现有数据，则生成随机数据
	if not use_existing_data:
		print("[Ghost initialize] 生成随机数据")
		_generate_random_data()
		# 随机Ghost也使用当前玩家名字（表示过去的自己）
		ghost_player_name = SaveManager.get_player_name()
		ghost_total_death_count = SaveManager.get_total_death_count()
	else:
		print("[Ghost initialize] 使用现有数据 | ghost_weapons数量:", ghost_weapons.size())
	# 否则，假设class_id和ghost_weapons已经被外部设置
	
	# 设置外观
	_setup_appearance()
	
	# 创建武器
	_create_weapons()
	
	# 创建名字显示（在所有初始化完成后）
	call_deferred("_create_name_label")

## 更新跟随速度（与玩家同步）
func update_speed(new_speed: float) -> void:
	follow_speed = new_speed
	_has_logged_speed = true
	_last_logged_speed = new_speed

## 生成随机数据
func _generate_random_data() -> void:
	# 随机选择职业
	var all_class_ids = ClassDatabase.get_all_class_ids()
	class_id = all_class_ids[randi() % all_class_ids.size()]
	
	# 随机生成1-6把武器
	var weapon_count = randi_range(1, 6)
	var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
	
	ghost_weapons.clear()
	for i in range(weapon_count):
		# 随机选择武器
		var weapon_id = all_weapon_ids[randi() % all_weapon_ids.size()]
		# 随机等级（1-5）
		var weapon_level = randi_range(1, 5)
		ghost_weapons.append({
			"id": weapon_id,
			"level": weapon_level
		})
	
	print("Ghost生成 - 职业: %s, 武器数量: %d" % [class_id, weapon_count])

## 设置外观
func _setup_appearance() -> void:
	# 直接使用player2外观（与玩家一致）
	# 职业数据中没有player_type字段，所以统一使用player2
	var player_type = "player2"
	var player_path = "res://assets/player/"
	
	print("[Ghost] 设置外观，职业ID:", class_id, " 使用外观:", player_type)
	
	ghostAni.sprite_frames.clear_all()
	
	var sprite_frame_custom = SpriteFrames.new()
	var texture_size = Vector2(520, 240)
	var sprite_size = Vector2(130, 240)
	var full_texture: Texture = load(player_path + player_type + "-sheet.png")
	
	var num_columns = int(texture_size.x / sprite_size.x)
	var num_row = int(texture_size.y / sprite_size.y)
	
	for x in range(num_columns):
		for y in range(num_row):
			var frame = AtlasTexture.new()
			frame.atlas = full_texture
			frame.region = Rect2(Vector2(x, y) * sprite_size, sprite_size)
			sprite_frame_custom.add_frame("default", frame)
	
	ghostAni.sprite_frames = sprite_frame_custom
	ghostAni.play("default")
	
	# 设置半透明效果，表示这是Ghost
	ghostAni.modulate = Color(1, 1, 1, 0.7)

## 创建武器
func _create_weapons() -> void:
	if weapons_node == null:
		return
	
	# 等待一帧，确保weapons_node的_ready()已经执行完毕
	# 这样可以避免在now_weapons自动加载GameMain.selected_weapon_ids之前就开始清除
	await get_tree().process_frame
	
	# 清除weapons_node中可能已经存在的武器（包括自动加载的）
	var children_to_remove = weapons_node.get_children()
	print("[Ghost] 准备清除已有武器，数量:", children_to_remove.size())
	for child in children_to_remove:
		weapons_node.remove_child(child)
		child.queue_free()
	
	# 等待一帧确保清除完成
	await get_tree().process_frame
	
	print("[Ghost] 创建武器，ghost_weapons数量:", ghost_weapons.size())
	
	# 逐个添加武器并等待初始化完成
	for i in range(ghost_weapons.size()):
		var weapon_data = ghost_weapons[i]
		print("[Ghost] 添加武器", i+1, ":", weapon_data["id"], " Lv.", weapon_data["level"])
		
		if weapons_node and weapons_node.has_method("add_weapon"):
			# 调用add_weapon，这是一个异步方法，必须等待它完成
			await weapons_node.add_weapon(weapon_data["id"], weapon_data["level"])
	
	print("[Ghost] 武器创建完成，weapons_node子节点数:", weapons_node.get_child_count())

## 记录路径点（用于后续Ghost跟随）
func _record_path_point() -> void:
	# 如果移动距离超过记录间隔，记录新的路径点
	var distance_since_last = global_position.distance_to(last_recorded_position)
	if distance_since_last >= path_record_distance:
		path_history.append(global_position)
		last_recorded_position = global_position
		
		# 限制路径点数量，删除最旧的路径点
		if path_history.size() > max_path_points:
			path_history.pop_front()

func ensure_path_history_capacity(required_points: int) -> void:
	var target_capacity = clamp(required_points + PATH_HISTORY_MARGIN_POINTS, PATH_HISTORY_MIN_CAPACITY, PATH_HISTORY_MAX_CAPACITY)
	if target_capacity != max_path_points:
		max_path_points = target_capacity

## 连接死亡管理器的信号
func _connect_death_signals() -> void:
	var death_manager = get_tree().get_first_node_in_group("death_manager")
	if death_manager:
		if death_manager.has_signal("player_died"):
			death_manager.player_died.connect(_on_player_died)
		if death_manager.has_signal("player_revived"):
			death_manager.player_revived.connect(_on_player_revived)
		print("[Ghost] 已连接死亡管理器信号")

## 玩家死亡时回调
func _on_player_died() -> void:
	print("[Ghost] 玩家死亡，禁用武器")
	_disable_weapons()

## 玩家复活时回调
func _on_player_revived() -> void:
	print("[Ghost] 玩家复活，启用武器")
	_enable_weapons()

## 禁用武器
func _disable_weapons() -> void:
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_DISABLED
		weapons_node.visible = false

## 启用武器
func _enable_weapons() -> void:
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
		weapons_node.visible = true

## 设置Ghost的名字和死亡次数（从GhostData获取）
func set_name_from_ghost_data(player_name: String, total_death_count: int) -> void:
	ghost_player_name = player_name
	ghost_total_death_count = total_death_count
	
	# 如果Label已经创建，立即更新
	if name_label:
		_update_name_label()

## 创建头顶名字Label
func _create_name_label() -> void:
	# 创建Label节点
	name_label = Label.new()
	add_child(name_label)
	
	# 设置Label属性
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置位置（在角色头顶上方）
	name_label.position = Vector2(-115, -190)  # 根据角色大小调整
	name_label.size = Vector2(120, 30)
	
	# 设置字体大小和颜色
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))  # 淡蓝色，表示Ghost
	
	# 添加黑色描边效果
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	
	# 设置z_index确保在角色上方显示
	name_label.z_index = 100
	
	# 更新名字显示
	_update_name_label()

## 更新名字Label显示内容
func _update_name_label() -> void:
	if name_label == null:
		return
	
	# 如果没有设置名字和死亡次数，使用默认值（不应该发生）
	if ghost_player_name == "":
		name_label.text = "未知 - 第 1 世"
		return
	
	# 格式：名字 - n世（n为死亡时的total_death_count）
	var display_name = "%s - 第 %d 世" % [ghost_player_name, ghost_total_death_count]
	name_label.text = display_name
