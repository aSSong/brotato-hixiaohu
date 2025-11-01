extends CharacterBody2D
class_name Ghost

## Ghost跟随玩家的测试功能
## Ghost拥有随机职业外观和随机武器，但没有HP等属性
## 武器会自动攻击敌人，但Ghost本身不会受到伤害

@onready var ghostAni: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapons_node: Node2D = $now_weapons

## 跟随目标（玩家或前一个Ghost）
var follow_target: Node2D = null

## 跟随距离
var follow_distance: float = 150.0

## 跟随速度（与玩家速度同步）
var follow_speed: float = 400.0

## 职业ID（用于外观）
var class_id: String = ""

## 武器列表（武器ID和等级）
var ghost_weapons: Array = []

## Ghost在队列中的索引
var queue_index: int = 0

func _ready() -> void:
	# Ghost不会与其他物体碰撞（只是视觉效果）
	collision_layer = 0
	collision_mask = 0
	
	# 添加到ghost组
	add_to_group("ghost")
	
	# 设置z_index略低于玩家
	z_index = 9

func _process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	
	# 计算到目标的距离
	var distance_to_target = global_position.distance_to(follow_target.global_position)
	
	# 如果距离大于跟随距离，移动向目标
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

## 初始化Ghost
func initialize(target: Node2D, index: int, player_speed: float) -> void:
	follow_target = target
	queue_index = index
	follow_speed = player_speed
	
	# 计算初始位置（在目标后方）
	if target:
		global_position = target.global_position - Vector2(follow_distance * index, 0)
	
	# 生成随机数据
	_generate_random_data()
	
	# 设置外观
	_setup_appearance()
	
	# 创建武器
	_create_weapons()

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
	# 根据职业选择玩家外观
	# 使用player1或player2的随机选择
	var player_types = ["player1", "player2"]
	var player_type = player_types[randi() % player_types.size()]
	
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
	
	# 添加所有随机生成的武器
	for weapon_data in ghost_weapons:
		weapons_node.add_weapon(weapon_data["id"], weapon_data["level"])
