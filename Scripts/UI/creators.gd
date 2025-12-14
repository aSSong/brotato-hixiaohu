extends Control

# 创作者名单
const CREATOR_NAMES: Array[String] = [
	"樊万松",
	"朱冬玥",
	"谢童",
	"左佩云",
	"唐枫婷",
	"王玉柱"
]

const THANK_YOU_MESSAGE: String = "Thank you for playing our game"

# Player皮肤资源路径（使用正确的SpriteFrames资源）
const PLAYER_SKIN_RESOURCES: Array[String] = [
	"res://resources/class_skin/armstrong01.tres",
	"res://resources/class_skin/babayaga01.tres",
	"res://resources/class_skin/betty01.tres",
	"res://resources/class_skin/ky01.tres",
	"res://resources/class_skin/mrdot01.tres",
	"res://resources/class_skin/mrwill01.tres"
]

# Enemy动画资源路径（Stage1）
const ENEMY_STAGE1_RESOURCES: Array[String] = [
	"res://resources/enemies/animations/stage1/creeper_fast_sprites.tres",
	"res://resources/enemies/animations/stage1/creeper_sprites.tres",
	"res://resources/enemies/animations/stage1/jug_green_sprites.tres",
	"res://resources/enemies/animations/stage1/jug_sprites.tres",
	"res://resources/enemies/animations/stage1/monitor_sprites.tres",
	"res://resources/enemies/animations/stage1/powerbank_sprites.tres",
	"res://resources/enemies/animations/stage1/stapler_sprites.tres"
]

# Enemy动画资源路径（Stage2）
const ENEMY_STAGE2_RESOURCES: Array[String] = [
	"res://resources/enemies/animations/stage2/bee_sprites.tres",
	"res://resources/enemies/animations/stage2/bluemashroom_sprites.tres",
	"res://resources/enemies/animations/stage2/ent_sprites.tres",
	"res://resources/enemies/animations/stage2/greenmashroom_sprites.tres",
	"res://resources/enemies/animations/stage2/masquito_blue_sprites.tres",
	"res://resources/enemies/animations/stage2/masquito_green_sprites.tres",
	"res://resources/enemies/animations/stage2/redmashroom_sprites.tres"
]

@onready var name_label: Label = $NameLabel
@onready var sprite_container: Node2D = $SpriteContainer

var remaining_names: Array[String] = []
var show_count: int = 0
var current_sprites: Array[AnimatedSprite2D] = []
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	reset_name_pool()
	start_next_sequence()

func _input(event: InputEvent) -> void:
	# 鼠标左键点击或ESC键返回settings界面
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_return_to_settings()
	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			_return_to_settings()

func _return_to_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")

func reset_name_pool() -> void:
	remaining_names = CREATOR_NAMES.duplicate()
	remaining_names.shuffle()
	show_count = 0

func get_next_name() -> String:
	show_count += 1
	
	if show_count > 6:
		# 第7次显示感谢信息
		return THANK_YOU_MESSAGE
	
	if remaining_names.is_empty():
		reset_name_pool()
	
	return remaining_names.pop_back()

func start_next_sequence() -> void:
	# 清理之前的精灵
	clear_sprites()
	
	# 获取下一个名字
	var next_name = get_next_name()
	
	# 如果显示了感谢信息，重置计数器准备下一轮
	if show_count > 6:
		show_count = 0
		reset_name_pool()
	
	# 随机决定运动方向和位置
	var go_left_to_right: bool = randf() > 0.5
	var run_on_top: bool = randf() > 0.5
	
	# 随机决定场景类型：0=单独player，1=怪物追player
	var scene_type: int = randi() % 2
	
	# 设置名字标签位置（与角色相反的一侧）
	setup_name_label(next_name, run_on_top)
	
	# 创建角色
	if scene_type == 0:
		create_solo_player(go_left_to_right, run_on_top)
	else:
		create_chase_scene(go_left_to_right, run_on_top)

func setup_name_label(text: String, character_on_top: bool) -> void:
	name_label.text = text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 重置锚点和位置，使用绝对坐标
	name_label.anchor_left = 0
	name_label.anchor_top = 0
	name_label.anchor_right = 0
	name_label.anchor_bottom = 0
	
	# 名字在屏幕水平方向1/8到7/8范围内随机
	var label_width = 800.0  # 标签宽度
	var min_x = screen_size.x * 0.125
	var max_x = screen_size.x * 0.875 - label_width
	var random_x = randf_range(min_x, max_x)
	
	# 名字显示在角色的另一侧（y轴错开）
	var label_y: float
	if character_on_top:
		# 角色在上方（25%位置），名字在下方（65%-75%位置）
		label_y = screen_size.y * randf_range(0.65, 0.75)
	else:
		# 角色在下方（75%位置），名字在上方（15%-25%位置）
		label_y = screen_size.y * randf_range(0.15, 0.25)
	
	name_label.position = Vector2(random_x, label_y)
	name_label.size = Vector2(label_width, 100)

func create_solo_player(left_to_right: bool, on_top: bool) -> void:
	var player_sprite = create_player_sprite()
	var y_pos = screen_size.y * (0.25 if on_top else 0.75)
	
	var start_x: float
	var end_x: float
	
	# 修正方向：左到右时角色面朝右（flip_h = true），右到左时面朝左（flip_h = false）
	if left_to_right:
		start_x = -200
		end_x = screen_size.x + 200
		player_sprite.flip_h = true  # 面朝右
	else:
		start_x = screen_size.x + 200
		end_x = -200
		player_sprite.flip_h = false  # 面朝左
	
	player_sprite.position = Vector2(start_x, y_pos)
	sprite_container.add_child(player_sprite)
	current_sprites.append(player_sprite)
	
	# 创建移动动画
	var tween = create_tween()
	var duration = randf_range(3.0, 5.0)
	tween.tween_property(player_sprite, "position:x", end_x, duration)
	tween.tween_callback(start_next_sequence)

func create_chase_scene(left_to_right: bool, on_top: bool) -> void:
	var y_pos = screen_size.y * (0.25 if on_top else 0.75)
	
	var start_x: float
	var end_x: float
	
	if left_to_right:
		start_x = -300
		end_x = screen_size.x + 500
	else:
		start_x = screen_size.x + 300
		end_x = -500
	
	# 创建player（在前面跑）
	var player_sprite = create_player_sprite()
	# 修正方向：左到右时角色面朝右（flip_h = true），右到左时面朝左（flip_h = false）
	player_sprite.flip_h = left_to_right
	
	var player_offset = 150 if left_to_right else -150
	player_sprite.position = Vector2(start_x + player_offset, y_pos)
	sprite_container.add_child(player_sprite)
	current_sprites.append(player_sprite)
	
	# 创建1-3个追逐的怪物
	var enemy_count = randi_range(1, 3)
	var enemies: Array[AnimatedSprite2D] = []
	
	for i in range(enemy_count):
		var enemy_sprite = create_enemy_sprite()
		# 修正方向：怪物追着player跑，方向相同
		enemy_sprite.flip_h = left_to_right
		
		# 怪物在player后面，间隔更大的距离（200-280像素），避免重叠
		var base_offset = -250 - i * 220 if left_to_right else 250 + i * 220
		# 增加一些随机偏移
		var random_offset = randf_range(-30, 30)
		enemy_sprite.position = Vector2(start_x + base_offset + random_offset, y_pos + randf_range(-30, 30))
		sprite_container.add_child(enemy_sprite)
		current_sprites.append(enemy_sprite)
		enemies.append(enemy_sprite)
	
	# 创建移动动画
	var duration = randf_range(3.5, 5.5)
	
	# Player移动
	var player_tween = create_tween()
	player_tween.tween_property(player_sprite, "position:x", end_x + player_offset, duration)
	
	# 怪物移动（稍微慢一点，保持追逐感）
	# 最后一个怪物的tween完成后才触发下一个序列
	for i in range(enemies.size()):
		var enemy = enemies[i]
		var base_offset = -250 - i * 220 if left_to_right else 250 + i * 220
		var enemy_end = end_x + base_offset
		var enemy_tween = create_tween()
		enemy_tween.tween_property(enemy, "position:x", enemy_end, duration * 1.05)
		
		# 只在最后一个怪物的tween上绑定回调
		if i == enemies.size() - 1:
			enemy_tween.tween_callback(start_next_sequence)

func create_player_sprite() -> AnimatedSprite2D:
	var sprite = AnimatedSprite2D.new()
	
	# 随机选择一个角色皮肤
	var skin_path = PLAYER_SKIN_RESOURCES.pick_random()
	var sprite_frames = load(skin_path) as SpriteFrames
	
	if sprite_frames == null:
		push_error("Failed to load player skin: " + skin_path)
		return sprite
	
	sprite.sprite_frames = sprite_frames
	sprite.animation = "default"  # 角色皮肤使用 "default" 动画
	sprite.play()
	
	# 设置缩放（与class_database.gd中一致）
	sprite.scale = Vector2(0.7, 0.7)
	
	return sprite

func create_enemy_sprite() -> AnimatedSprite2D:
	var sprite = AnimatedSprite2D.new()
	
	# 随机选择stage1或stage2的怪物
	var all_enemies: Array[String] = []
	all_enemies.append_array(ENEMY_STAGE1_RESOURCES)
	all_enemies.append_array(ENEMY_STAGE2_RESOURCES)
	
	var enemy_path = all_enemies.pick_random()
	var sprite_frames = load(enemy_path) as SpriteFrames
	
	if sprite_frames == null:
		push_error("Failed to load enemy sprite: " + enemy_path)
		return sprite
	
	sprite.sprite_frames = sprite_frames
	sprite.animation = "walk"  # 怪物使用 "walk" 动画
	sprite.play()
	
	# 设置随机缩放（0.4到0.7之间）
	var random_scale = randf_range(0.4, 0.7)
	sprite.scale = Vector2(random_scale, random_scale)
	
	return sprite

func clear_sprites() -> void:
	for sprite in current_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	current_sprites.clear()
