extends BaseWeapon
class_name MeleeWeapon

## 近战武器（重构版）
## 
## 使用新的DamageCalculator和SpecialEffects系统
## 支持暴击、吸血、燃烧等特效

var rotation_angle: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var has_dealt_damage: bool = false
var knockback_multiplier: float = 1.0  # 旧系统兼容

## 设置击退系数
func set_knockback_multiplier(multiplier: float) -> void:
	knockback_multiplier = multiplier

func _on_weapon_initialized() -> void:
	rotation_angle = 0.0
	is_attacking = false
	attack_timer = 0.0
	has_dealt_damage = false

func _on_weapon_process(delta: float) -> void:
	if weapon_data == null:
		return
	
	# 如果正在攻击，执行旋转攻击
	if is_attacking:
		attack_timer -= delta
		
		# 旋转武器（相对于当前位置）
		if weapon_data.rotation_speed > 0:
			rotation_angle += weapon_data.rotation_speed * delta
			rotation_degrees = rotation_angle
		
		# 攻击结束
		if attack_timer <= 0:
			is_attacking = false
			has_dealt_damage = false
			rotation_angle = 0.0
			rotation_degrees = 0.0
	else:
		# 不攻击时，武器朝向环绕运动的方向（可选）
		# 或者保持默认朝向（0度），让武器跟随环绕运动自然旋转
		# 如果需要武器始终朝向敌人，可以取消下面的注释
		# if attack_enemies.size() > 0:
		# 	var target = attack_enemies[0]
		# 	if is_instance_valid(target):
		# 		look_at(target.global_position)
		rotation_degrees = 0.0

func _perform_attack() -> void:
	if weapon_data == null:
		return
	
	# 开始攻击动画
	_start_attack_animation()
	
	# 联网模式：通过 NetworkPlayerManager 广播攻击动画
	if GameMain.current_mode_id == "online":
		NetworkPlayerManager.broadcast_melee_attack(owner_peer_id)
	
	# 立即检查并造成伤害（只造成一次）
	_check_and_damage_enemies()


## 开始攻击动画
func _start_attack_animation() -> void:
	if weapon_data == null:
		return
	is_attacking = true
	attack_timer = weapon_data.attack_speed
	has_dealt_damage = false

## 检测并伤害范围内的敌人和 Boss 玩家
func _check_and_damage_enemies() -> void:
	if weapon_data == null:
		return
	
	# 使用新系统获取伤害
	var base_damage = get_damage()
	var hit_range = weapon_data.hit_range
	
	# 联网模式：攻击可攻击的玩家（PvP）
	var hit_players = NetworkPlayerManager.handle_melee_collision(owner_peer_id, global_position, hit_range, base_damage)
	for hit_player in hit_players:
		apply_special_effects(hit_player, base_damage)
	
	# 获取所有敌人
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 计算距离
		var distance = global_position.distance_to(enemy.global_position)
		
		# 如果在攻击范围内
		if distance <= hit_range:
			var final_damage = base_damage
			var is_critical = false
			
			# 暴击判定（使用新系统）
			if player_stats:
				is_critical = DamageCalculator.roll_critical(player_stats)
				if is_critical:
					final_damage = DamageCalculator.apply_critical_multiplier(base_damage, player_stats)
			
			# 造成伤害
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage, is_critical, owner_peer_id)
			
			# 应用特殊效果（统一方法）
			apply_special_effects(enemy, final_damage)
			
			# 击退效果（使用新系统）
			if weapon_data.knockback_force > 0:
				var player = get_tree().get_first_node_in_group("player")
				var player_pos = global_position
				if player and is_instance_valid(player):
					player_pos = player.global_position
				
				var knockback_dir = (enemy.global_position - player_pos).normalized()
				
				# 使用DamageCalculator计算最终击退力
				var final_knockback = weapon_data.knockback_force
				if player_stats:
					final_knockback = DamageCalculator.calculate_knockback(
						weapon_data.knockback_force,
						player_stats
					)
				else:
					# 降级方案：使用旧系统
					final_knockback *= knockback_multiplier
				
				# 应用击退
				if enemy is CharacterBody2D:
					if enemy.has_method("apply_knockback"):
						enemy.apply_knockback(knockback_dir * final_knockback)
					else:
						if "knockback_velocity" in enemy:
							enemy.knockback_velocity += knockback_dir * final_knockback
						else:
							enemy.velocity += knockback_dir * final_knockback
