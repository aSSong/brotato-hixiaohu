extends BaseWeapon
class_name MagicWeapon

## 魔法武器
## 对范围内的多个敌人造成爆炸/范围伤害

@onready var shoot_pos: Marker2D = $shoot_pos
var explosion_particles_scene = null  # 可选：爆炸粒子效果

## 爆炸指示器脚本
var explosion_indicator_script = preload("res://Scripts/weapons/explosion_indicator.gd")

## 指示器持续时间
var indicator_duration: float = 0.3  # 显示持续时间

## 获取指示器颜色（根据武器类型）
func _get_indicator_color() -> Color:
	if weapon_data == null:
		return Color(1.0, 0.5, 0.0, 0.35)  # 默认橙色
	
	# 根据武器名称设置不同颜色
	match weapon_data.weapon_name:
		"火球":
			return Color(1.0, 0.4, 0.0, 0.4)  # 橙红色（火系）
		"冰刺":
			return Color(0.3, 0.8, 1.0, 0.35)  # 青蓝色（冰系）
		"陨石":
			return Color(1.0, 0.2, 0.0, 0.45)  # 深红色（陨石）
		_:
			return Color(0.8, 0.3, 1.0, 0.35)  # 紫色（其他魔法）

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
		
		# 显示爆炸范围指示器
		if explosion_radius > 0:
			_show_explosion_indicator(target.global_position, explosion_radius)
		
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
			var explosion_damage_mult = 1.0 - (distance / radius) * 0.5  # 最多衰减50%
			var final_damage = int(base_damage * explosion_damage_mult * weapon_data.explosion_damage_multiplier)
			
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage)
			
			# 可以在这里添加爆炸特效
			# _create_explosion_effect(pos)

## 创建爆炸特效（可选）
func _create_explosion_effect(_pos: Vector2) -> void:
	# 这里可以添加粒子效果或其他视觉特效
	# 例如：GameMain.animation_scene_obj.run_animation({...})
	pass

## 显示爆炸范围指示器
func _show_explosion_indicator(pos: Vector2, radius: float) -> void:
	# 创建指示器节点
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	# 添加到场景树（添加到根节点，确保不受武器旋转影响）
	get_tree().root.add_child(indicator)
	
	# 调用 _ready() 手动初始化（避免等待一帧）
	indicator._ready()
	
	# 获取当前武器的指示器颜色
	var indicator_color = _get_indicator_color()
	
	# 显示指示器
	if indicator.has_method("show_at"):
		indicator.show_at(pos, radius, indicator_color, indicator_duration)
