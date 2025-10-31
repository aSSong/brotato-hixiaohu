extends Node2D
class_name BaseWeapon

## 武器基类
## 提取通用逻辑，定义虚函数接口供子类实现

@onready var weaponAni: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer
@onready var detection_area: Area2D = $Area2D

## 武器数据
var weapon_data: WeaponData = null

## 敌人列表
var attack_enemies: Array = []

## 伤害和攻击速度倍数（用于职业加成）
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0

## 武器等级（用于颜色显示）
const weapon_level_colors = {
	level_1 = "#b0c3d9",
	level_2 = "#4b69ff",
	level_3 = "#d32ce6",
	level_4 = "#8847ff",
	level_5 = "#eb4b4b",
}

## 初始化武器
func initialize(data: WeaponData) -> void:
	weapon_data = data
	if weapon_data == null:
		push_error("武器数据为空！")
		return
	
	# 设置攻击间隔（考虑攻击速度倍数）
	if timer:
		timer.wait_time = weapon_data.attack_speed / attack_speed_multiplier
		timer.autostart = true
	
	# 设置检测范围
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var shape = detection_area.get_child(0).shape
		if shape is CircleShape2D:
			shape.radius = weapon_data.range
	
	# 设置武器等级颜色（随机）
	if weaponAni and weaponAni.material:
		var ran = RandomNumberGenerator.new()
		ran.randomize()
		var level = ran.randi_range(1, 5)
		weaponAni.material.set_shader_parameter("color", Color(weapon_data.weapon_level_colors['level_' + str(level)]))
	
	# 调用子类的初始化
	_on_weapon_initialized()

func _ready() -> void:
	# 连接信号
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_area_2d_body_entered):
			detection_area.body_entered.connect(_on_area_2d_body_entered)
		if not detection_area.body_exited.is_connected(_on_area_2d_body_exited):
			detection_area.body_exited.connect(_on_area_2d_body_exited)
	
	if timer:
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
	
	# 检查是否有存储的weapon_data（用于动态创建的武器）
	if has_meta("weapon_data"):
		var stored_data = get_meta("weapon_data")
		if stored_data is WeaponData:
			initialize(stored_data)
			remove_meta("weapon_data")

func _process(delta: float) -> void:
	# 朝向最近的敌人
	if attack_enemies.size() > 0:
		var target_enemy = attack_enemies[0]
		if is_instance_valid(target_enemy):
			look_at(target_enemy.global_position)
		else:
			attack_enemies.erase(target_enemy)
			sort_enemy()
	else:
		rotation_degrees = 0
	
	# 调用子类的更新逻辑
	_on_weapon_process(delta)

## 计时器超时，执行攻击
func _on_timer_timeout() -> void:
	if attack_enemies.is_empty() or weapon_data == null:
		return
	
	# 清理无效的敌人
	attack_enemies = attack_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	if attack_enemies.is_empty():
		return
	
	# 调用子类的攻击方法
	_perform_attack()

## 敌人进入检测范围
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and not attack_enemies.has(body):
		attack_enemies.append(body)
		sort_enemy()

## 敌人离开检测范围
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy") and attack_enemies.has(body):
		attack_enemies.erase(body)
		sort_enemy()

## 排序敌人（按距离）
func sort_enemy() -> void:
	if attack_enemies.size() == 0:
		return
	
	attack_enemies.sort_custom(
		func(x, y):
			if not is_instance_valid(x) or not is_instance_valid(y):
				return false
			return x.global_position.distance_to(self.global_position) < y.global_position.distance_to(self.global_position)
	)

## 虚函数：子类实现具体的攻击逻辑
func _perform_attack() -> void:
	push_error("_perform_attack() 必须在子类中实现！")

## 虚函数：武器初始化时的额外设置
func _on_weapon_initialized() -> void:
	pass

## 虚函数：每帧更新逻辑
func _on_weapon_process(delta: float) -> void:
	pass

## 获取伤害值（考虑职业加成等）
func get_damage() -> int:
	if weapon_data == null:
		return 1
	return int(weapon_data.damage * damage_multiplier)

## 设置伤害倍数
func set_damage_multiplier(multiplier: float) -> void:
	damage_multiplier = multiplier

## 设置攻击速度倍数
func set_attack_speed_multiplier(multiplier: float) -> void:
	attack_speed_multiplier = multiplier
	if timer and weapon_data:
		timer.wait_time = weapon_data.attack_speed / attack_speed_multiplier

## 获取攻击速度
func get_attack_speed() -> float:
	if weapon_data == null:
		return 0.5
	return weapon_data.attack_speed

