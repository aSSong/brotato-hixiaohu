extends Node
class_name EnemyAIController

## Enemy AI 控制器（独立于 enemy.gd）
## 仅负责“正常移动逻辑”的决策与 idle/walk 动画切换
## 不改变碰撞攻击（enemy.gd 中的 _attack_player 触发条件保持原样）

var enemy: Enemy = null

## ========== RANGED 内部状态 ==========
var _ranged_reposition_cooldown_left: float = 0.0

## ========== ESCAPE 内部状态 ==========
enum EscapeState { IDLE, FLEEING, COOLDOWN }
var _escape_state: EscapeState = EscapeState.IDLE
var _flee_time_left: float = 0.0
var _flee_dir: Vector2 = Vector2.ZERO
var _escape_cooldown_left: float = 0.0

func initialize(enemy_ref: Enemy) -> void:
	enemy = enemy_ref
	_ranged_reposition_cooldown_left = 0.0
	_escape_state = EscapeState.IDLE
	_flee_time_left = 0.0
	_flee_dir = Vector2.ZERO
	_escape_cooldown_left = 0.0

## 是否允许根据目标进行朝向翻转（供 enemy.gd 调用）
## 需求：STILL 类型支持 can_flip=false 时不随目标翻转
func can_flip_towards_target() -> bool:
	if not enemy or not enemy.enemy_data:
		return true
	if enemy.enemy_data.ai_type != EnemyData.EnemyAIType.STILL:
		return true
	return bool(enemy.enemy_data.ai_config.get("can_flip", true))

## 受击回调：仅 ESCAPE 类型会使用
func on_hurt() -> void:
	if not enemy or enemy.is_dead:
		return
	if not enemy.enemy_data:
		return
	if enemy.enemy_data.ai_type != EnemyData.EnemyAIType.ESCAPE:
		return
	_try_start_flee()

## AI 更新：由 enemy.gd 在“无技能接管移动”时调用
func update_ai(delta: float, separation: Vector2) -> void:
	if not enemy or enemy.is_dead:
		return
	
	# STILL 类型（树等）坐标应始终不变：不受分离力/击退/AI 影响
	# 注意：冰冻分支在下面会处理动画；这里优先硬锁位置
	if enemy.enemy_data and enemy.enemy_data.ai_type == EnemyData.EnemyAIType.STILL:
		# 动画保持 idle/walk 的既有规则（不强行覆盖技能动画）
		if not _is_skill_controlling_animation():
			_play_idle_or_walk()
		enemy.knockback_velocity = Vector2.ZERO
		enemy.velocity = Vector2.ZERO
		return

	if not enemy.target or not is_instance_valid(enemy.target):
		_set_velocity_and_anim(Vector2.ZERO, false, separation)
		return
	
	# 冰冻：完全不动（保持与原逻辑一致）
	if enemy.is_frozen():
		# 冰冻应完全静止：不叠加击退/分离（否则会出现“冰冻也被推着走”的副作用）
		if not _is_skill_controlling_animation():
			_play_idle_or_walk()
		enemy.velocity = Vector2.ZERO
		return
	
	var player_pos: Vector2 = enemy.target.global_position
	var self_pos: Vector2 = enemy.global_position
	var player_distance: float = self_pos.distance_to(player_pos)
	var attack_range_value: float = enemy.enemy_data.attack_range if enemy.enemy_data else 80.0
	var dir_to_player: Vector2 = (player_pos - self_pos).normalized()
	var dir_away: Vector2 = -dir_to_player
	
	# 应用减速效果（保持与原逻辑一致）
	var slow_mul: float = enemy.get_slow_multiplier()
	
	# 默认：近战
	var ai_type: int = EnemyData.EnemyAIType.MELEE
	var ai_config: Dictionary = {}
	if enemy.enemy_data:
		ai_type = enemy.enemy_data.ai_type
		ai_config = enemy.enemy_data.ai_config
	
	var desired: Vector2 = Vector2.ZERO
	var is_actively_moving: bool = false
	
	match ai_type:
		EnemyData.EnemyAIType.MELEE:
			var min_distance: float = attack_range_value - 20.0
			if player_distance > min_distance:
				desired = dir_to_player * enemy.speed * slow_mul
				is_actively_moving = true
			else:
				desired = Vector2.ZERO
				is_actively_moving = false
		
		EnemyData.EnemyAIType.RANGED:
			desired = _update_ranged(delta, player_distance, dir_to_player, dir_away, ai_config, slow_mul)
			is_actively_moving = (desired.length() > 0.1)
		
		EnemyData.EnemyAIType.ESCAPE:
			desired = _update_escape(delta, player_distance, dir_to_player, dir_away, ai_config, slow_mul)
			is_actively_moving = (desired.length() > 0.1)
		
		EnemyData.EnemyAIType.STILL:
			desired = Vector2.ZERO
			is_actively_moving = false
		
		_:
			# 兜底：近战
			var min_distance_fallback: float = attack_range_value - 20.0
			if player_distance > min_distance_fallback:
				desired = dir_to_player * enemy.speed * slow_mul
				is_actively_moving = true
			else:
				desired = Vector2.ZERO
				is_actively_moving = false
	
	_set_velocity_and_anim(desired, is_actively_moving, separation)

func _update_ranged(
	delta: float,
	player_distance: float,
	dir_to_player: Vector2,
	dir_away: Vector2,
	ai_config: Dictionary,
	slow_mul: float
) -> Vector2:
	# 参数默认值
	var min_distance: float = float(ai_config.get("minDistance", 200.0))
	var max_distance: float = float(ai_config.get("maxDistance", 600.0))
	var angle_variance_deg: float = float(ai_config.get("retreatAngleVariance", 30.0))
	var reposition_cooldown: float = float(ai_config.get("repositionCooldown", 2.0))
	
	# 倒计时
	if _ranged_reposition_cooldown_left > 0.0:
		_ranged_reposition_cooldown_left = maxf(0.0, _ranged_reposition_cooldown_left - delta)
	
	# 过近：优先后退（不受 cooldown 限制，避免贴脸）
	if player_distance < min_distance:
		var retreat_dir = _randomized_dir(dir_away, angle_variance_deg)
		return retreat_dir * enemy.speed * slow_mul
	
	# 过远：接近（可受 cooldown 限制，减少抽搐）
	if player_distance > max_distance:
		if _ranged_reposition_cooldown_left > 0.0:
			return Vector2.ZERO
		return dir_to_player * enemy.speed * slow_mul
	
	# 区间内：待机。进入区间后启动冷却，防止边界抖动
	if reposition_cooldown > 0.0 and _ranged_reposition_cooldown_left <= 0.0:
		_ranged_reposition_cooldown_left = reposition_cooldown
	return Vector2.ZERO

func _update_escape(
	delta: float,
	_player_distance: float,
	_dir_to_player: Vector2,
	_dir_away: Vector2,
	ai_config: Dictionary,
	slow_mul: float
) -> Vector2:
	var flee_speed: float = float(ai_config.get("fleeSpeed", 600.0))
	var reposition_cooldown: float = float(ai_config.get("repositionCooldown", 2.0))
	
	match _escape_state:
		EscapeState.FLEEING:
			_flee_time_left -= delta
			if _flee_time_left <= 0.0:
				_escape_state = EscapeState.COOLDOWN
				_escape_cooldown_left = maxf(0.0, reposition_cooldown)
				return Vector2.ZERO
			return _flee_dir * flee_speed * slow_mul
		
		EscapeState.COOLDOWN:
			_escape_cooldown_left -= delta
			if _escape_cooldown_left <= 0.0:
				_escape_state = EscapeState.IDLE
			return Vector2.ZERO
		
		_:
			# 待机不动（受击时 on_hurt() 会尝试进入 flee）
			return Vector2.ZERO

func _try_start_flee() -> void:
	if _escape_state == EscapeState.FLEEING:
		return
	if _escape_state == EscapeState.COOLDOWN and _escape_cooldown_left > 0.0:
		return
	if not enemy or not enemy.target or not is_instance_valid(enemy.target):
		return
	
	var ai_config: Dictionary = enemy.enemy_data.ai_config if enemy.enemy_data else {}
	var flee_duration_min: float = float(ai_config.get("fleeDurationmin", 1.5))
	var flee_duration_max: float = float(ai_config.get("fleeDurationmax", 5.5))
	var angle_variance_deg: float = float(ai_config.get("retreatAngleVariance", 30.0))
	
	var dir_away: Vector2 = (enemy.global_position - enemy.target.global_position).normalized()
	if dir_away == Vector2.ZERO:
		dir_away = Vector2.LEFT
	
	_flee_dir = _randomized_dir(dir_away, angle_variance_deg)
	_flee_time_left = randf_range(flee_duration_min, flee_duration_max)
	_escape_state = EscapeState.FLEEING

func _randomized_dir(base_dir: Vector2, variance_deg: float) -> Vector2:
	if base_dir == Vector2.ZERO:
		return Vector2.ZERO
	var rad: float = deg_to_rad(randf_range(-variance_deg, variance_deg))
	return base_dir.normalized().rotated(rad).normalized()

func _set_velocity_and_anim(desired_velocity: Vector2, is_actively_moving: bool, separation: Vector2) -> void:
	# 如果有技能正在控制动画，不覆盖动画
	if not _is_skill_controlling_animation():
		# 动画：移动=walk，停=idle（无idle则walk）
		if is_actively_moving:
			enemy.play_animation("walk")
		else:
			_play_idle_or_walk()
	
	# 速度叠加：保持与原逻辑尽量一致
	# - 主动移动：追击/走位速度 + 击退 + 软分离
	# - 停止/待机：仍然需要响应击退（推开敌人），但不应主动移动
	if is_actively_moving:
		enemy.velocity = desired_velocity + enemy.knockback_velocity + separation
	else:
		enemy.velocity = enemy.knockback_velocity + separation

func _play_idle_or_walk() -> void:
	if enemy.enemy_data and enemy.enemy_data.animations.get("idle", "") != "":
		enemy.play_animation("idle")
	else:
		enemy.play_animation("walk")

## 检查是否有技能正在控制动画
## 遍历敌人的 behaviors，检查是否有技能激活
func _is_skill_controlling_animation() -> bool:
	if not enemy:
		return false
	
	for behavior in enemy.behaviors:
		if not is_instance_valid(behavior):
			continue
		
		# 检查 ShootingBehavior
		if behavior is ShootingBehavior:
			var shooting = behavior as ShootingBehavior
			if shooting.is_skill_active():
				return true
		
		# 检查 BossShootingBehavior
		if behavior is BossShootingBehavior:
			var boss_shooting = behavior as BossShootingBehavior
			if boss_shooting.is_skill_active():
				return true
		
		# 检查 ChargingBehavior
		if behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			if charging.is_charging_now():
				return true
		
		# 检查 ExplodingBehavior（倒数或爆炸中都需要控制动画）
		if behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.is_skill_active():
				return true
	
	return false


