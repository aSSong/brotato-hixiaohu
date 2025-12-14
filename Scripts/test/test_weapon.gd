extends Node2D

## 武器测试场景
## 
## 功能：
## - 顶部按钮栏选择武器
## - 中间显示武器发射效果
## - 底部速度控制滑块

@onready var weapon_buttons_container: HBoxContainer = $UI/TopBar/WeaponButtons
@onready var speed_slider: HSlider = $UI/BottomBar/SpeedSlider
@onready var speed_label: Label = $UI/BottomBar/SpeedLabel
@onready var weapon_holder: Node2D = $WeaponHolder
@onready var target_container: Node2D = $TargetContainer
@onready var weapon_info_label: Label = $UI/WeaponInfo

## 预加载背景贴图
var bg_texture = preload("res://assets/bg/bg.png") if ResourceLoader.exists("res://assets/bg/bg.png") else null

## 当前武器实例
var current_weapon: Node2D = null

## 当前选中的武器ID
var current_weapon_id: String = ""

## 假人列表
var target_dummies: Array = []

## 假人数量
const DUMMY_COUNT = 5

## 假人场景（简单的模拟敌人）
var dummy_scene: PackedScene = null

func _ready() -> void:
	# 初始化数据库
	WeaponDatabase.initialize_weapons()
	BulletDatabase.initialize_bullets()
	CombatEffectManager.initialize()
	
	# 创建武器按钮
	_create_weapon_buttons()
	
	# 创建假人
	_create_target_dummies()
	
	# 设置速度滑块
	speed_slider.value = 1.0
	speed_slider.value_changed.connect(_on_speed_changed)
	_update_speed_label(1.0)
	
	# 默认选择第一个武器
	var weapon_ids = WeaponDatabase.get_all_weapon_ids()
	if weapon_ids.size() > 0:
		_select_weapon(weapon_ids[0])

func _create_weapon_buttons() -> void:
	var weapon_ids = WeaponDatabase.get_all_weapon_ids()
	
	for weapon_id in weapon_ids:
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		if weapon_data == null:
			continue
		
		var button = Button.new()
		button.text = weapon_data.weapon_name
		button.custom_minimum_size = Vector2(100, 40)
		button.pressed.connect(_on_weapon_button_pressed.bind(weapon_id))
		weapon_buttons_container.add_child(button)

func _create_target_dummies() -> void:
	# 在武器周围创建假人作为攻击目标
	var positions = [
		Vector2(400, 0),
		Vector2(-400, 0),
		Vector2(0, 300),
		Vector2(300, 200),
		Vector2(-300, -200),
	]
	
	for i in range(DUMMY_COUNT):
		var dummy = _create_dummy()
		dummy.position = positions[i % positions.size()]
		target_container.add_child(dummy)
		target_dummies.append(dummy)

func _create_dummy() -> CharacterBody2D:
	# 创建一个简单的假人（CharacterBody2D，加入enemy组）
	var dummy = TestDummy.new()
	dummy.add_to_group("enemy")
	
	# 设置碰撞层（enemy层，通常是第4层）
	dummy.collision_layer = 8  # 第4层
	dummy.collision_mask = 0
	
	# 添加碰撞形状
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30
	collision.shape = shape
	dummy.add_child(collision)
	
	# 添加可视化（红色圆形）
	var sprite = Sprite2D.new()
	var texture = PlaceholderTexture2D.new()
	texture.size = Vector2(60, 60)
	sprite.texture = texture
	sprite.modulate = Color(1, 0.3, 0.3, 0.8)
	dummy.add_child(sprite)
	
	# 添加标签
	var label = Label.new()
	label.text = "假人"
	label.position = Vector2(-20, -50)
	label.add_theme_color_override("font_color", Color.WHITE)
	dummy.add_child(label)
	
	return dummy


## 测试假人类
class TestDummy extends CharacterBody2D:
	var hp: int = 9999
	var is_dead: bool = false
	
	func enemy_hurt(damage: int, is_crit: bool = false) -> void:
		# 显示伤害数字
		print("[假人] 受到伤害: ", damage, " 暴击: ", is_crit)

func _select_weapon(weapon_id: String) -> void:
	# 清除当前武器
	if current_weapon:
		current_weapon.queue_free()
		current_weapon = null
	
	current_weapon_id = weapon_id
	
	# 创建新武器
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if weapon_data == null:
		return
	
	current_weapon = WeaponFactory.create_weapon(weapon_id, 1)
	if current_weapon == null:
		return
	
	weapon_holder.add_child(current_weapon)
	
	# 等待一帧确保初始化完成
	await get_tree().process_frame
	
	# 更新武器信息显示
	_update_weapon_info(weapon_data)
	
	# 更新按钮高亮
	_update_button_highlights(weapon_id)

func _update_weapon_info(weapon_data: WeaponData) -> void:
	var behavior_type_name = ""
	match weapon_data.behavior_type:
		WeaponData.BehaviorType.MELEE:
			behavior_type_name = "近战"
		WeaponData.BehaviorType.RANGED:
			behavior_type_name = "远程"
		WeaponData.BehaviorType.MAGIC:
			behavior_type_name = "魔法"
	
	var calc_type_name = ""
	match weapon_data.calculation_type:
		WeaponData.CalculationType.MELEE:
			calc_type_name = "近战"
		WeaponData.CalculationType.RANGED:
			calc_type_name = "远程"
		WeaponData.CalculationType.MAGIC:
			calc_type_name = "魔法"
	
	var params = weapon_data.get_behavior_params()
	
	weapon_info_label.text = """武器: %s
类型: %s行为 + %s结算
描述: %s
伤害: %d | 攻速: %.2fs | 范围: %.0f""" % [
		weapon_data.weapon_name,
		behavior_type_name,
		calc_type_name,
		weapon_data.description,
		params.get("damage", 0),
		params.get("attack_speed", 1.0),
		params.get("range", 500)
	]

func _update_button_highlights(selected_id: String) -> void:
	var weapon_ids = WeaponDatabase.get_all_weapon_ids()
	var idx = 0
	for child in weapon_buttons_container.get_children():
		if child is Button:
			if idx < weapon_ids.size() and weapon_ids[idx] == selected_id:
				child.modulate = Color(1, 1, 0.5)  # 高亮选中的按钮
			else:
				child.modulate = Color.WHITE
			idx += 1

func _on_weapon_button_pressed(weapon_id: String) -> void:
	_select_weapon(weapon_id)

func _on_speed_changed(value: float) -> void:
	Engine.time_scale = value
	_update_speed_label(value)

func _update_speed_label(value: float) -> void:
	speed_label.text = "速度: %.2fx" % value

func _process(_delta: float) -> void:
	# 让假人缓慢移动，增加测试趣味性
	var time = Time.get_ticks_msec() / 1000.0
	for i in range(target_dummies.size()):
		var dummy = target_dummies[i]
		if is_instance_valid(dummy):
			var base_pos = Vector2(400, 0).rotated(TAU / DUMMY_COUNT * i + time * 0.2)
			var offset = Vector2(sin(time * 0.5 + i) * 50, cos(time * 0.3 + i) * 50)
			dummy.position = base_pos + offset

