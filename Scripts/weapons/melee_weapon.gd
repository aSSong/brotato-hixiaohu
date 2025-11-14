extends BaseWeapon
class_name MeleeWeapon

## 近战武器
## 通过旋转或挥砍攻击范围内的敌人

var rotation_angle: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var has_dealt_damage: bool = false  # 标记本次攻击是否已造成伤害
var knockback_multiplier: float = 1.0  # 击退系数

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
	
	# 开始攻击
	is_attacking = true
	attack_timer = weapon_data.attack_speed
	has_dealt_damage = false  # 重置伤害标记
	
	# 立即检查并造成伤害（只造成一次）
	_check_and_damage_enemies()

## 检测并伤害范围内的敌人
func _check_and_damage_enemies() -> void:
	if weapon_data == null:
		return
	
	var damage = get_damage()
	var hit_range = weapon_data.hit_range
	
	# 获取所有敌人
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 计算距离
		var distance = global_position.distance_to(enemy.global_position)
		
		# 如果在攻击范围内
		if distance <= hit_range:
			# 造成伤害
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(damage)
			
			# 如果有击退效果（应用击退系数）
			if weapon_data.knockback_force > 0:
				var knockback_dir = (enemy.global_position - global_position).normalized()
				var final_knockback = weapon_data.knockback_force * knockback_multiplier
				if enemy is CharacterBody2D:
					# 使用敌人的击退速度变量
					if enemy.has_method("apply_knockback"):
						enemy.apply_knockback(knockback_dir * final_knockback)
					else:
						# 兼容旧代码：直接设置 knockback_velocity（如果存在）
						if "knockback_velocity" in enemy:
							enemy.knockback_velocity += knockback_dir * final_knockback
						else:
							enemy.velocity += knockback_dir * final_knockback
