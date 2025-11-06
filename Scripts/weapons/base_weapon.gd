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

## 武器等级（1-5级）
var weapon_level: int = 1

## 武器等级颜色（白、绿、蓝、紫、红）
const weapon_level_colors = {
	level_1 = "#FFFFFF",  # 白色
	level_2 = "#00FF00",  # 绿色
	level_3 = "#0000FF",  # 蓝色
	level_4 = "#FF00FF",  # 紫色
	level_5 = "#FF0000",  # 红色
}

## 初始化武器
func initialize(data: WeaponData, level: int = 1) -> void:
	weapon_data = data
	weapon_level = clamp(level, 1, 5)
	
	if weapon_data == null:
		push_error("武器数据为空！")
		return
	
	# 获取等级倍数
	var multipliers = WeaponData.get_level_multipliers(weapon_level)
	
	# 设置攻击间隔（考虑攻击速度倍数和等级倍数）
	if timer:
		var final_attack_speed = weapon_data.attack_speed / (attack_speed_multiplier * multipliers.attack_speed_multiplier)
		timer.wait_time = final_attack_speed
		timer.autostart = true
	
	# 设置检测范围（考虑等级倍数）
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var shape = detection_area.get_child(0).shape
		if shape is CircleShape2D:
			shape.radius = weapon_data.range * multipliers.range_multiplier
	
	# 设置武器贴图
	_setup_weapon_appearance()
	
	# 设置武器等级颜色和描边
	_update_weapon_level_appearance()
	
	# 调用子类的初始化
	_on_weapon_initialized()

## 升级武器等级
func upgrade_level() -> bool:
	if weapon_level >= 5:
		return false  # 已达到最高等级
	
	weapon_level += 1
	
	# 重新应用等级倍数
	var multipliers = WeaponData.get_level_multipliers(weapon_level)
	
	# 更新攻击间隔
	if timer:
		var final_attack_speed = weapon_data.attack_speed / (attack_speed_multiplier * multipliers.attack_speed_multiplier)
		timer.wait_time = final_attack_speed
	
	# 更新检测范围
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var shape = detection_area.get_child(0).shape
		if shape is CircleShape2D:
			shape.radius = weapon_data.range * multipliers.range_multiplier
	
	# 更新颜色和描边
	_update_weapon_level_appearance()
	
	return true

## 更新武器等级外观（颜色和描边）
func _update_weapon_level_appearance() -> void:
	if not weaponAni:
		return
	
	var material = weaponAni.material
	if not material:
		return
	
	# 检查材质类型
	if not material is ShaderMaterial:
		return
	
	var shader_material = material as ShaderMaterial
	if not shader_material:
		return
	
	# 获取颜色（使用 WeaponData 的静态常量）
	var color_hex = WeaponData.weapon_level_colors['level_' + str(weapon_level)]
	var color = Color(color_hex)
	
	# 直接设置 shader 参数（如果参数不存在，set_shader_parameter 不会报错）
	shader_material.set_shader_parameter("color", color)
	#shader_material.set_shader_parameter("line_thickness", 2.5)

## 获取实际伤害（考虑等级倍数）
func get_actual_damage() -> int:
	if weapon_data == null:
		return 1
	var multipliers = WeaponData.get_level_multipliers(weapon_level)
	return int(weapon_data.damage * multipliers.damage_multiplier * damage_multiplier)

## 获取伤害（别名，供子类使用）
func get_damage() -> int:
	return get_actual_damage()

## 设置武器外观
func _setup_weapon_appearance() -> void:
	if weapon_data == null or not weaponAni:
		return
	
	# 设置武器缩放
	self.scale = weapon_data.scale
	
	# 设置武器贴图
	if weapon_data.texture_path != "":
		var texture = load(weapon_data.texture_path)
		if texture:
			# 【关键修复】每个武器实例都创建独立的 SpriteFrames
			# 避免多个武器实例共享同一个 SpriteFrames 导致显示错误
			var sprite_frames = SpriteFrames.new()
			sprite_frames.add_animation("default")
			sprite_frames.set_animation_loop("default", true)
			sprite_frames.add_frame("default", texture)
			sprite_frames.set_animation_speed("default", 5.0)
			
			# 设置独立的 SpriteFrames 到这个武器
			weaponAni.sprite_frames = sprite_frames
			weaponAni.play("default")
			
			# 设置偏移
			if weapon_data.sprite_offset != Vector2.ZERO:
				weaponAni.position = weapon_data.sprite_offset

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
		var stored_level = 1
		if has_meta("weapon_level"):
			stored_level = get_meta("weapon_level")
		if stored_data is WeaponData:
			initialize(stored_data, stored_level)
			remove_meta("weapon_data")
			if has_meta("weapon_level"):
				remove_meta("weapon_level")

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
func _on_weapon_process(_delta: float) -> void:
	pass

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
