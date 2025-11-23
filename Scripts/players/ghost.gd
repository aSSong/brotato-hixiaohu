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

## Ghost的名字和死亡次数（用于显示）
var ghost_player_name: String = ""
var ghost_total_death_count: int = 0

## 名字显示Label
var name_label: Label = null

## 说话气泡组件
var speech_bubble: PlayerSpeechBubble = null

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
	
	# 注册到说话管理器
	call_deferred("_register_to_speech_manager")

func _process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	
	# 使用贪吃蛇式跟随
	_snake_follow(delta)
	
	# 记录Ghost自己的路径（供后续Ghost使用）
	_record_path_point()

## 贪吃蛇式跟随逻辑
func _snake_follow(delta: float) -> void:
	# 如果目标路径点队列为空，直接跟随目标
	if target_path_points.is_empty():
		_direct_follow()
		return
	
	# 获取当前目标点
	if current_path_index >= target_path_points.size():
		current_path_index = target_path_points.size() - 1
	
	if current_path_index < 0:
		return
	
	var target_point = target_path_points[current_path_index]
	var distance_to_point = global_position.distance_to(target_point)
	
	# 如果接近当前路径点，移动到下一个路径点
	if distance_to_point < path_record_distance:
		current_path_index += 1
		if current_path_index >= target_path_points.size():
			current_path_index = target_path_points.size() - 1
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
	# 确保索引有效
	if current_path_index >= target_path_points.size():
		current_path_index = max(0, target_path_points.size() - 1)

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
	
	# 创建说话气泡组件
	call_deferred("_create_speech_bubble")

## 更新跟随速度（与玩家同步）
func update_speed(new_speed: float) -> void:
	follow_speed = new_speed

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
	if global_position.distance_to(last_recorded_position) >= path_record_distance:
		path_history.append(global_position)
		last_recorded_position = global_position
		
		# 限制路径点数量，删除最旧的路径点
		if path_history.size() > max_path_points:
			path_history.pop_front()

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

## 创建说话气泡组件（Ghost动态创建）
func _create_speech_bubble() -> void:
	# Ghost需要动态创建气泡（因为Ghost是动态生成的）
	var speech_bubble_scene = load("res://scenes/players/player_speech_bubble.tscn")
	if not speech_bubble_scene:
		push_error("[Ghost] 无法加载说话气泡场景！")
		return
	
	speech_bubble = speech_bubble_scene.instantiate()
	speech_bubble.name = "GhostSpeechBubble"
	
	# 设置位置与Player一致
	speech_bubble.offset_left = -105
	speech_bubble.offset_top = -288
	speech_bubble.offset_right = 95
	speech_bubble.offset_bottom = -228
	
	# 直接添加到Ghost节点下，作为子节点（与Player一致）
	add_child(speech_bubble)
	#print("[Ghost] 说话气泡组件已添加到Ghost节点下，位置已设置")

## 显示说话气泡
func show_speech(text: String, duration: float = 3.0) -> void:
	if speech_bubble:
		speech_bubble.show_speech(text, duration)
	else:
		push_warning("[Ghost] 说话气泡组件未找到！")

## 注册到说话管理器
func _register_to_speech_manager() -> void:
	var speech_manager = get_tree().get_first_node_in_group("speech_manager")
	if speech_manager and speech_manager.has_method("register_speaker"):
		speech_manager.register_speaker(self)
