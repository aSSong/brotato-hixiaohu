extends WeaponBehavior
class_name MeleeBehavior

## 近战行为
## 
## 实现环绕触碰攻击方式
## 
## 参数 (params):
##   - damage: int 基础伤害
##   - orbit_radius: float 环绕半径
##   - orbit_speed: float 环绕速度（度/秒）
##   - hit_range: float 攻击判定范围
##   - knockback_force: float 击退力度
##   - rotation_speed: float 武器自转速度（度/秒）
##   - attack_speed: float 攻击间隔（秒）
##   - range: float 检测范围

## 当前旋转角度（用于攻击动画）
var rotation_angle: float = 0.0

## 是否正在攻击
var is_attacking: bool = false

## 攻击计时器
var attack_timer: float = 0.0

## 已造成伤害的敌人列表（防止重复伤害）
var damaged_enemies: Array = []

func _on_initialize() -> void:
	rotation_angle = 0.0
	is_attacking = false
	attack_timer = 0.0
	damaged_enemies.clear()

func get_behavior_type() -> int:
	return WeaponData.BehaviorType.MELEE

## 获取环绕半径
func get_orbit_radius() -> float:
	return params.get("orbit_radius", 230.0)

## 获取环绕速度
func get_orbit_speed() -> float:
	return params.get("orbit_speed", 90.0)

## 获取攻击判定范围
func get_hit_range() -> float:
	var base_hit_range = params.get("hit_range", 100.0)
	
	if player_stats:
		# 近战攻击范围受结算类型的范围加成影响
		return DamageCalculator.calculate_range_by_calc_type(
			base_hit_range,
			weapon_level,
			calculation_type,
			player_stats
		)
	else:
		var level_mults = WeaponData.get_level_multipliers(weapon_level)
		return base_hit_range * level_mults.range_multiplier

## 获取击退力度
func get_knockback_force() -> float:
	var base_knockback = params.get("knockback_force", 0.0)
	
	if player_stats:
		return DamageCalculator.calculate_knockback(base_knockback, player_stats)
	
	return base_knockback

## 获取武器自转速度
func get_rotation_speed() -> float:
	return params.get("rotation_speed", 360.0)

func process(delta: float) -> void:
	if not weapon:
		return
	
	# 如果正在攻击，执行旋转攻击
	if is_attacking:
		attack_timer -= delta
		
		# 旋转武器
		var rotation_speed = get_rotation_speed()
		if rotation_speed > 0:
			rotation_angle += rotation_speed * delta
			weapon.rotation_degrees = rotation_angle
		
		# 攻击结束
		if attack_timer <= 0:
			is_attacking = false
			damaged_enemies.clear()
			rotation_angle = 0.0
			weapon.rotation_degrees = 0.0
	else:
		weapon.rotation_degrees = 0.0

func perform_attack(enemies: Array) -> void:
	if enemies.is_empty():
		return
	
	# 开始攻击
	is_attacking = true
	attack_timer = get_attack_interval()
	damaged_enemies.clear()
	
	# 立即检查并造成伤害
	_check_and_damage_enemies()

## 检测并伤害范围内的敌人
func _check_and_damage_enemies() -> void:
	if not weapon:
		return
	
	var base_damage = get_final_damage()
	var hit_range = get_hit_range()
	var knockback = get_knockback_force()
	
	# 获取所有敌人
	var enemies = weapon.get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 跳过已伤害的敌人
		if damaged_enemies.has(enemy):
			continue
		
		# 计算距离
		var distance = weapon.global_position.distance_to(enemy.global_position)
		
		# 如果在攻击范围内
		if distance <= hit_range:
			var final_damage = base_damage
			var is_critical = roll_critical()
			
			if is_critical:
				final_damage = apply_critical(base_damage)
			
			# 造成伤害
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage, is_critical)
			
			# 应用特殊效果
			apply_special_effects(enemy, final_damage)
			
			# 击退效果
			if knockback > 0:
				_apply_knockback(enemy, knockback)
			
			# 标记已伤害
			damaged_enemies.append(enemy)

## 应用击退效果
func _apply_knockback(enemy: Node2D, force: float) -> void:
	if not weapon:
		return
	
	var player = weapon.get_tree().get_first_node_in_group("player")
	var player_pos = weapon.global_position
	if player and is_instance_valid(player):
		player_pos = player.global_position
	
	var knockback_dir = (enemy.global_position - player_pos).normalized()
	
	if enemy is CharacterBody2D:
		if enemy.has_method("apply_knockback"):
			# 优先使用 apply_knockback 方法（会自动应用击退抗性）
			enemy.apply_knockback(knockback_dir * force)
		elif "knockback_velocity" in enemy:
			# 备用方案：手动考虑击退抗性
			var resistance = enemy.knockback_resistance if "knockback_resistance" in enemy else 0.0
			var resistance_multiplier = 1.0 - resistance
			enemy.knockback_velocity += knockback_dir * force * resistance_multiplier
		elif "velocity" in enemy:
			enemy.velocity += knockback_dir * force
