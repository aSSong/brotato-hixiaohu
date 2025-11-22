extends Node2D
class_name BaseWeapon

## 武器基类（重构版）
## 
## 使用新的DamageCalculator系统计算所有战斗属性
## 移除手动倍数管理，直接引用玩家的CombatStats
## 
## 重要变化：
##   - 移除 damage_multiplier, attack_speed_multiplier, range_multiplier
##   - 添加 player_stats 引用
##   - 所有计算通过 DamageCalculator

@onready var weaponAni: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer
@onready var detection_area: Area2D = $Area2D

## 武器数据
var weapon_data: WeaponData = null

## 敌人列表
var attack_enemies: Array = []

## ===== 新属性系统 =====
## 玩家属性引用（从AttributeManager.final_stats获取）
var player_stats: CombatStats = null

## ===== 旧系统（已废弃，保留兼容） =====
## 注意：这些字段将被忽略，请设置 player_stats
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var range_multiplier: float = 1.0

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
		push_error("[BaseWeapon] 武器数据为空！")
		return
	
	# 确保在场景树中
	if not is_inside_tree():
		push_error("[BaseWeapon] initialize() 调用时节点不在场景树中")
		return
	
	# 确保@onready节点已准备好（双重检查）
	if not weaponAni:
		weaponAni = get_node_or_null("AnimatedSprite2D")
	if not timer:
		timer = get_node_or_null("Timer")
	if not detection_area:
		detection_area = get_node_or_null("Area2D")
	
	# 如果关键节点仍然缺失，无法初始化
	if not weaponAni or not timer or not detection_area:
		push_error("[BaseWeapon] initialize() 时关键节点缺失，无法继续")
		return
	
	# 刷新武器属性（攻速、范围等）
	refresh_weapon_stats()
	
	# 设置武器贴图
	_setup_weapon_appearance()
	
	# 设置武器等级颜色和描边
	_update_weapon_level_appearance()
	
	# 调用子类的初始化
	_on_weapon_initialized()

## 刷新武器属性
## 
## 当player_stats变化时调用此方法更新武器的攻速和范围
func refresh_weapon_stats() -> void:
	if not weapon_data:
		return
	
	# 更新攻击间隔
	if timer:
		var final_attack_speed = get_attack_speed()
		timer.wait_time = final_attack_speed
		if not timer.autostart:
			timer.autostart = true
	
	# 更新检测范围
	if detection_area and detection_area.get_child(0) is CollisionShape2D:
		var collision_shape = detection_area.get_child(0) as CollisionShape2D
		# 创建新的独立 CircleShape2D 资源
		var new_shape = CircleShape2D.new()
		new_shape.radius = get_range()
		collision_shape.shape = new_shape

## 获取最终伤害
## 
## 使用DamageCalculator计算，考虑武器等级、玩家属性等
func get_damage() -> int:
	if not weapon_data:
		return 0
	
	if player_stats:
		# 新系统：使用DamageCalculator
		return DamageCalculator.calculate_weapon_damage(
			weapon_data.damage,
			weapon_level,
			weapon_data.weapon_type,
			player_stats
		)
	else:
		# 降级方案：使用旧系统
		var multipliers = WeaponData.get_level_multipliers(weapon_level)
		return int(weapon_data.damage * multipliers.damage_multiplier * damage_multiplier)

## 获取最终攻击速度（攻击间隔）
func get_attack_speed() -> float:
	if not weapon_data:
		return 1.0
	
	if player_stats:
		# 新系统：使用DamageCalculator
		return DamageCalculator.calculate_attack_speed(
			weapon_data.attack_speed,
			weapon_level,
			weapon_data.weapon_type,
			player_stats
		)
	else:
		# 降级方案：使用旧系统
		var multipliers = WeaponData.get_level_multipliers(weapon_level)
		return weapon_data.attack_speed / (attack_speed_multiplier * multipliers.attack_speed_multiplier)

## 获取最终攻击范围
func get_range() -> float:
	if not weapon_data:
		return 100.0
	
	if player_stats:
		# 新系统：使用DamageCalculator
		return DamageCalculator.calculate_range(
			weapon_data.range,
			weapon_level,
			weapon_data.weapon_type,
			player_stats
		)
	else:
		# 降级方案：使用旧系统
		var multipliers = WeaponData.get_level_multipliers(weapon_level)
		return weapon_data.range * multipliers.range_multiplier * range_multiplier

## 升级武器等级
func upgrade_level() -> bool:
	if weapon_level >= 5:
		return false  # 已达到最高等级
	
	weapon_level += 1
	
	# 刷新属性（使用新的统一方法）
	refresh_weapon_stats()
	
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
			#sprite_frames.add_animation("default")
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
	# 确保在场景树中
	if not is_inside_tree():
		push_error("[BaseWeapon] _ready() 调用时节点不在场景树中")
		return
	
	# 【关键修复】手动初始化@onready变量（防止set_script后@onready失效）
	# 如果@onready初始化失败（通常发生在set_script替换脚本后），手动获取节点引用
	if not weaponAni:
		weaponAni = get_node_or_null("AnimatedSprite2D")
		if not weaponAni:
			push_error("[BaseWeapon] 无法找到 AnimatedSprite2D 节点")
	
	if not timer:
		timer = get_node_or_null("Timer")
		if not timer:
			push_error("[BaseWeapon] 无法找到 Timer 节点")
	
	if not detection_area:
		detection_area = get_node_or_null("Area2D")
		if not detection_area:
			push_error("[BaseWeapon] 无法找到 Area2D 节点")
	
	# 如果关键节点缺失，无法继续初始化
	if not weaponAni or not timer or not detection_area:
		push_error("[BaseWeapon] 关键节点缺失，武器初始化失败")
		push_error("[BaseWeapon] weaponAni: %s, timer: %s, detection_area: %s" % [
			"存在" if weaponAni else "缺失",
			"存在" if timer else "缺失",
			"存在" if detection_area else "缺失"
		])
		# 注意：不销毁实例，让调用者处理
		return
	
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
	# 近战武器不自动朝向敌人（由环绕运动控制位置）
	# 其他武器类型朝向最近的敌人
	if weapon_data and weapon_data.weapon_type != WeaponData.WeaponType.MELEE:
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

## 设置范围倍数
func set_range_multiplier(multiplier: float) -> void:
	range_multiplier = multiplier
	# 更新检测范围
	if detection_area and detection_area.get_child(0) is CollisionShape2D and weapon_data:
		var collision_shape = detection_area.get_child(0) as CollisionShape2D
		var shape = collision_shape.shape
		if shape is CircleShape2D:
			var multipliers = WeaponData.get_level_multipliers(weapon_level)
			shape.radius = weapon_data.range * multipliers.range_multiplier * range_multiplier

## 应用特殊效果到目标
## 
## 统一的方法，所有武器都可以使用
## 
## @param target 目标对象
## @param damage_dealt 造成的伤害（用于吸血等效果）
## @param effect_configs 效果配置数组，每个元素为 {"type": String, "params": Dictionary}
##   示例: [{"type": "burn", "params": {"chance": 0.3, "tick_interval": 1.0, "damage": 10, "duration": 5.0}}]
func apply_special_effects(target: Node, damage_dealt: int = 0, effect_configs: Array = []) -> void:
	if not player_stats:
		return
	
	# 如果没有提供配置，尝试从weapon_data中读取
	if effect_configs.is_empty() and weapon_data and weapon_data.special_effects:
		if weapon_data.special_effects is Dictionary and weapon_data.special_effects.has("effects"):
			effect_configs = weapon_data.special_effects.get("effects", [])
	
	# 应用每个效果
	for effect_config in effect_configs:
		if not effect_config is Dictionary:
			continue
		
		var effect_type = effect_config.get("type", "")
		var effect_params = effect_config.get("params", {})
		
		# 检查是否需要target（吸血效果不需要target）
		if effect_type != "lifesteal" and not target:
			continue
		
		# 如果是吸血效果，需要传递伤害和攻击者
		if effect_type == "lifesteal":
			effect_params["damage_dealt"] = damage_dealt
			var attacker = get_tree().get_first_node_in_group("player")
			effect_params["attacker"] = attacker
		
		# 应用效果（吸血效果时target可以为null）
		SpecialEffects.try_apply_status_effect(player_stats, target, effect_type, effect_params)
