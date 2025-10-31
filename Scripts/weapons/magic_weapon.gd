extends BaseWeapon
class_name MagicWeapon

## 魔法武器
## 对范围内的多个敌人造成爆炸/范围伤害

@onready var shoot_pos: Marker2D = $shoot_pos
var explosion_particles_scene = null  # 可选：爆炸粒子效果

func _on_weapon_initialized() -> void:
	# 确保有射击位置节点（用于魔法效果位置）
	if not shoot_pos:
		shoot_pos = Marker2D.new()
		shoot_pos.name = "shoot_pos"
		shoot_pos.position = Vector2(16.142859, 1.1428572)
		add_child(shoot_pos)

func _perform_attack() -> void:
	if attack_enemies.is_empty() or weapon_data == null:
		return
	
	# 选择目标（最近的敌人或最多目标数）
	var targets = []
	var max_targets = weapon_data.max_targets if weapon_data.max_targets > 0 else 999
	
	for i in range(min(attack_enemies.size(), max_targets)):
		var enemy = attack_enemies[i]
		if is_instance_valid(enemy):
			targets.append(enemy)
	
	if targets.is_empty():
		return
	
	# 对每个目标造成伤害
	var damage = get_damage()
	var explosion_radius = weapon_data.explosion_radius
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# 对目标造成伤害
		if target.has_method("enemy_hurt"):
			var final_damage = int(damage * weapon_data.explosion_damage_multiplier)
			target.enemy_hurt(final_damage)
		
		# 爆炸范围伤害（对目标周围的敌人）
		if explosion_radius > 0:
			_explode_at_position(target.global_position, explosion_radius, damage)

## 在指定位置产生爆炸效果
func _explode_at_position(pos: Vector2, radius: float, base_damage: int) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = pos.distance_to(enemy.global_position)
		
		# 如果在爆炸范围内
		if distance <= radius:
			# 根据距离计算伤害（距离越近伤害越高）
			var damage_multiplier = 1.0 - (distance / radius) * 0.5  # 最多衰减50%
			var final_damage = int(base_damage * damage_multiplier * weapon_data.explosion_damage_multiplier)
			
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage)
			
			# 可以在这里添加爆炸特效
			# _create_explosion_effect(pos)

## 创建爆炸特效（可选）
func _create_explosion_effect(pos: Vector2) -> void:
	# 这里可以添加粒子效果或其他视觉特效
	# 例如：GameMain.animation_scene_obj.run_animation({...})
	pass

