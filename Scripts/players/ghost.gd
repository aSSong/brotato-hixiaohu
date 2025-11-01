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
		ghostAni.flip_h = false
	else:
		ghostAni.flip_h = true

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
	follow_target = target
	queue_index = index
	follow_speed = player_speed
	
	# 设置初始位置为目标当前位置（不要偏移太远）
	if target:
		global_position = target.global_position
	
	# 如果不使用现有数据，则生成随机数据
	if not use_existing_data:
		_generate_random_data()
	# 否则，假设class_id和ghost_weapons已经被外部设置
	
	# 设置外观
	_setup_appearance()
	
	# 创建武器
	_create_weapons()
	
	# 使用call_deferred延迟设置武器透明度，确保武器完全创建完成
	call_deferred("_set_weapons_alpha_deferred")

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
	# 根据职业ID获取职业数据
	var class_data = ClassDatabase.get_class_data(class_id)
	
	# 获取职业的外观类型（player1或player2）
	var player_type = "player1"  # 默认
	if class_data and "player_type" in class_data:
		player_type = class_data.player_type
	else:
		# 如果职业数据中没有player_type，使用随机选择
		var player_types = ["player1", "player2"]
		player_type = player_types[randi() % player_types.size()]
	
	var player_path = "res://assets/player/"
	
	ghostAni.sprite_frames.clear_all()
	
	var sprite_frame_custom = SpriteFrames.new()
	var texture_size = Vector2(960, 240)
	var sprite_size = Vector2(240, 240)
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
	
	# 添加所有随机生成的武器，并在创建后设置透明度
	for weapon_data in ghost_weapons:
		_add_weapon_with_alpha(weapon_data["id"], weapon_data["level"])

## 添加武器并设置透明度
func _add_weapon_with_alpha(weapon_id: String, weapon_level: int) -> void:
	# 调用weapons_node的add_weapon方法
	if weapons_node and weapons_node.has_method("add_weapon"):
		# 先添加武器
		weapons_node.add_weapon(weapon_id, weapon_level)
		
		# 延迟设置透明度
		await get_tree().create_timer(0.2).timeout
		_apply_alpha_to_latest_weapon()

## 设置武器透明度
func _set_weapons_alpha() -> void:
	if weapons_node == null:
		return
	
	# 遍历所有武器子节点
	for weapon in weapons_node.get_children():
		if weapon is BaseWeapon:
			# 设置武器的透明度
			_set_single_weapon_alpha(weapon)

## 设置单个武器的透明度
func _set_single_weapon_alpha(weapon: Node) -> void:
	if weapon == null:
		return
	
	# 尝试多种方式获取武器精灵
	var weapon_sprite = null
	
	# 方式1：直接查找AnimatedSprite2D
	if weapon.has_node("AnimatedSprite2D"):
		weapon_sprite = weapon.get_node("AnimatedSprite2D")
	# 方式2：通过weaponAni属性
	elif "weaponAni" in weapon:
		weapon_sprite = weapon.weaponAni
	
	if weapon_sprite:
		weapon_sprite.modulate = Color(1, 1, 1, 0.7)
		print("成功设置武器透明度: ", weapon.name)
	else:
		print("警告：无法找到武器精灵: ", weapon.name)

## 应用透明度到最新添加的武器
func _apply_alpha_to_latest_weapon() -> void:
	if weapons_node == null:
		return
	
	var weapons = weapons_node.get_children()
	if weapons.size() > 0:
		var latest_weapon = weapons[weapons.size() - 1]
		if latest_weapon is BaseWeapon:
			_set_single_weapon_alpha(latest_weapon)

## 延迟设置武器透明度（确保武器完全创建）
func _set_weapons_alpha_deferred() -> void:
	# 等待多帧确保所有武器完全初始化
	for i in range(5):
		await get_tree().process_frame
	_set_weapons_alpha()

## 记录路径点（用于后续Ghost跟随）
func _record_path_point() -> void:
	# 如果移动距离超过记录间隔，记录新的路径点
	if global_position.distance_to(last_recorded_position) >= path_record_distance:
		path_history.append(global_position)
		last_recorded_position = global_position
		
		# 限制路径点数量，删除最旧的路径点
		if path_history.size() > max_path_points:
			path_history.pop_front()
