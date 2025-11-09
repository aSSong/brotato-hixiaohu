extends BaseWeapon
class_name MeleeWeapon

## 近战武器
## 通过旋转或挥砍攻击范围内的敌人

var rotation_angle: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var has_dealt_damage: bool = false  # 标记本次攻击是否已造成伤害

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
		
		# 旋转武器
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
		# 朝向最近的敌人（如果没有攻击）
		if attack_enemies.size() > 0:
			var target = attack_enemies[0]
			if is_instance_valid(target):
				look_at(target.global_position)

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
			
			# 如果有击退效果
			if weapon_data.knockback_force > 0:
				var knockback_dir = (enemy.global_position - global_position).normalized()
				if enemy is CharacterBody2D:
					# 使用敌人的击退速度变量
					if enemy.has_method("apply_knockback"):
						enemy.apply_knockback(knockback_dir * weapon_data.knockback_force)
					else:
						# 兼容旧代码：直接设置 knockback_velocity（如果存在）
						if "knockback_velocity" in enemy:
							enemy.knockback_velocity += knockback_dir * weapon_data.knockback_force
						else:
							enemy.velocity += knockback_dir * weapon_data.knockback_force
