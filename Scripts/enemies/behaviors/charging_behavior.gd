extends EnemyBehavior
class_name ChargingBehavior

## 冲锋技能行为
## 当玩家在触发距离内时，敌人会高速冲向玩家

## 状态
enum ChargeState {
	IDLE,      # 待机，正常移动
	PREPARING, # 准备冲锋（短暂延迟）
	CHARGING,  # 冲锋中
	COOLDOWN   # 冷却中
}

var state: ChargeState = ChargeState.IDLE

## 配置参数（从config字典读取）
var trigger_distance: float = 500.0  # 触发距离
var charge_speed: float = 800.0     # 冲锋速度
var charge_distance: float = 600.0  # 冲锋距离
var cooldown: float = 3.0           # 冷却时间
var extra_damage: int = 10          # 冲锋命中额外伤害
var prepare_time: float = 0.3       # 准备时间

## 指示器
var indicator_sprite: Sprite2D = null
var indicator_texture: Texture2D = null
const DEFAULT_INDICATOR_TEXTURE_PATH: String = "res://assets/skill_indicator/charging-range-rect.png"

## 状态计时器
var state_timer: float = 0.0

## 冲锋相关
var charge_start_pos: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.ZERO
var is_charging: bool = false
var original_knockback_resistance: float = 0.0  # 保存原始击退抗性

func _on_initialize() -> void:
	# 从配置中读取参数
	trigger_distance = config.get("trigger_distance", 500.0)
	charge_speed = config.get("charge_speed", 800.0)
	charge_distance = config.get("charge_distance", 600.0)
	cooldown = config.get("cooldown", 3.0)
	extra_damage = config.get("extra_damage", 10)
	prepare_time = config.get("prepare_time", 0.3)
	
	# 加载指示器纹理（支持自定义配置）
	var custom_indicator_path = config.get("indicator_texture", "")
	if custom_indicator_path != "" and ResourceLoader.exists(custom_indicator_path):
		indicator_texture = load(custom_indicator_path)
	else:
		indicator_texture = load(DEFAULT_INDICATOR_TEXTURE_PATH)
	
	state = ChargeState.IDLE
	state_timer = 0.0
	is_charging = false
	_hide_indicator()

func _on_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return
	
	state_timer -= delta
	
	match state:
		ChargeState.IDLE:
			_check_trigger_charge()
		
		ChargeState.PREPARING:
			_update_indicator()
			if state_timer <= 0:
				_start_charge()
		
		ChargeState.CHARGING:
			_update_charge(delta)
		
		ChargeState.COOLDOWN:
			if state_timer <= 0:
				state = ChargeState.IDLE
				is_charging = false

func _on_physics_update(_delta: float) -> void:
	# 冲锋期间的移动在_update_charge中处理
	pass

## 检查是否触发冲锋
func _check_trigger_charge() -> void:
	var distance = get_distance_to_player()
	if distance <= trigger_distance:
		# 开始准备冲锋
		state = ChargeState.PREPARING
		state_timer = prepare_time
		is_charging = false
		_show_indicator()
		
		# 播放技能准备动画
		if enemy:
			enemy.play_animation("skill_prepare")
			enemy.play_skill_animation("skill_prepare")

## 开始冲锋
func _start_charge() -> void:
	var player = get_player()
	if not player or not enemy:
		state = ChargeState.IDLE
		return
	
	state = ChargeState.CHARGING
	charge_start_pos = enemy.global_position
	charge_direction = get_direction_to_player()
	is_charging = true
	_hide_indicator()
	
	# 冲锋期间完全无视击退
	original_knockback_resistance = enemy.knockback_resistance
	enemy.knockback_resistance = 1.0
	enemy.knockback_velocity = Vector2.ZERO  # 清除已有的击退速度
	
	# 设置冲锋距离的计时器（基于速度计算）
	var charge_duration = charge_distance / charge_speed
	state_timer = charge_duration
	
	# 播放技能执行动画
	enemy.play_animation("skill_execute")
	enemy.play_skill_animation("skill_execute")
	
	print("[ChargingBehavior] 开始冲锋 | 方向:", charge_direction, " 距离:", charge_distance)

## 更新冲锋
func _update_charge(_delta: float) -> void:
	if not enemy:
		return
	
	# 冲锋期间持续清除击退速度，确保不受干扰
	enemy.knockback_velocity = Vector2.ZERO
	
	# 计算冲锋移动
	var charge_velocity = charge_direction * charge_speed
	
	# 检查是否已经冲锋足够距离
	var traveled_distance = enemy.global_position.distance_to(charge_start_pos)
	if traveled_distance >= charge_distance:
		_end_charge()
		return
	
	# 检查是否命中玩家
	var player = get_player()
	if player:
		var player_distance = enemy.global_position.distance_to(player.global_position)
		var attack_range_value = enemy.enemy_data.attack_range if enemy.enemy_data else 80.0
		if player_distance < attack_range_value:
			# 命中玩家，造成额外伤害
			_hit_player_with_charge()
			_end_charge()
			return
	
	# 应用冲锋速度（覆盖正常移动）
	enemy.velocity = charge_velocity
	enemy.move_and_slide()
	
	# 检查计时器
	if state_timer <= 0:
		_end_charge()

## 冲锋命中玩家
func _hit_player_with_charge() -> void:
	var player = get_player()
	if player and player.has_method("player_hurt"):
		var total_damage = enemy.attack_damage + extra_damage
		player.player_hurt(total_damage)
		print("[ChargingBehavior] 冲锋命中玩家 | 伤害:", total_damage)

## 结束冲锋
func _end_charge() -> void:
	state = ChargeState.COOLDOWN
	state_timer = cooldown
	is_charging = false
	enemy.velocity = Vector2.ZERO
	_hide_indicator()
	
	# 恢复原始击退抗性
	if enemy:
		enemy.knockback_resistance = original_knockback_resistance
		enemy.play_animation("walk")
		enemy.stop_skill_animation()
	
	print("[ChargingBehavior] 冲锋结束，进入冷却")

## 是否正在冲锋（供Enemy类查询，用于覆盖正常移动）
func is_charging_now() -> bool:
	return is_charging and state == ChargeState.CHARGING

## 指示器相关
func _create_indicator() -> void:
	if is_instance_valid(indicator_sprite):
		return
	
	if not enemy:
		return
		
	indicator_sprite = Sprite2D.new()
	indicator_sprite.texture = indicator_texture
	indicator_sprite.centered = false
	if indicator_texture:
		indicator_sprite.offset = Vector2(0, -indicator_texture.get_height() / 2.0)
	
	indicator_sprite.visible = false
	indicator_sprite.top_level = true
	indicator_sprite.z_index = -1
	enemy.add_child(indicator_sprite)

func _show_indicator() -> void:
	_create_indicator()
	if is_instance_valid(indicator_sprite):
		indicator_sprite.visible = true
		_update_indicator()

func _hide_indicator() -> void:
	if is_instance_valid(indicator_sprite):
		indicator_sprite.visible = false

func _update_indicator() -> void:
	if not is_instance_valid(indicator_sprite) or not indicator_sprite.visible or not enemy:
		return
	
	var player = get_player()
	if not player:
		return
		
	# 更新位置
	indicator_sprite.global_position = enemy.global_position
	
	# 更新朝向
	var dir = (player.global_position - enemy.global_position).normalized()
	indicator_sprite.rotation = dir.angle()
	
	# 更新缩放（长度）
	if indicator_texture:
		var texture_width = indicator_texture.get_width()
		if texture_width > 0:
			var scale_x = charge_distance / texture_width
			indicator_sprite.scale = Vector2(scale_x, 1.0)
