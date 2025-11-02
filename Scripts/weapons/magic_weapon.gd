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

## 当前正在施法的攻击列表
var casting_attacks: Array = []  # [{target, indicator, timer, damage}]

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

func _process(delta: float) -> void:
	# 处理正在施法的攻击
	_update_casting_attacks(delta)

## 更新施法攻击
func _update_casting_attacks(delta: float) -> void:
	var attacks_to_remove = []
	
	for i in range(casting_attacks.size()):
		var cast_data = casting_attacks[i]
		
		# 检查目标是否仍然有效
		if not is_instance_valid(cast_data.target) or cast_data.target.get("is_dead"):
			# 目标无效，取消攻击
			_cancel_cast(cast_data)
			attacks_to_remove.append(i)
			continue
		
		# 检查目标是否还在范围内
		if not attack_enemies.has(cast_data.target):
			# 目标离开范围，取消攻击
			_cancel_cast(cast_data)
			attacks_to_remove.append(i)
			continue
		
		# 更新倒计时
		cast_data.timer -= delta
		
		# 时间到，执行攻击
		if cast_data.timer <= 0:
			_execute_cast(cast_data)
			attacks_to_remove.append(i)
	
	# 移除已完成的攻击（从后往前删除）
	attacks_to_remove.reverse()
	for i in attacks_to_remove:
		casting_attacks.remove_at(i)

## 取消施法
func _cancel_cast(cast_data: Dictionary) -> void:
	# 淡出并删除指示器
	if cast_data.indicator and is_instance_valid(cast_data.indicator):
		if cast_data.indicator.has_method("fade_out_and_remove"):
			cast_data.indicator.fade_out_and_remove(0.1)

## 执行施法
func _execute_cast(cast_data: Dictionary) -> void:
	var target = cast_data.target
	var damage = cast_data.damage
	
	if not is_instance_valid(target):
		# 清理指示器
		if cast_data.indicator and is_instance_valid(cast_data.indicator):
			cast_data.indicator.hide_and_remove()
		return
	
	var explosion_radius = weapon_data.explosion_radius if weapon_data else 150.0
	
	# 对目标造成直接伤害
	if target.has_method("enemy_hurt"):
		var final_damage = int(damage * weapon_data.explosion_damage_multiplier)
		target.enemy_hurt(final_damage)
	
	# 爆炸范围伤害（如果启用）
	if weapon_data.has_explosion_damage and explosion_radius > 0:
		_explode_at_position(target.global_position, explosion_radius, damage, target)
	
	# 指示器会自动淡出删除（持续时间到）
	# 但我们可以立即删除以同步攻击时机
	if cast_data.indicator and is_instance_valid(cast_data.indicator):
		cast_data.indicator.hide_and_remove()

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
	
	# 获取延迟时间
	var cast_delay = weapon_data.attack_cast_delay if weapon_data else 0.0
	var damage = get_damage()
	var explosion_radius = weapon_data.explosion_radius
	
	# 只对第一个目标显示指示器（避免太多圈）
	for i in range(targets.size()):
		var target = targets[i]
		if not is_instance_valid(target):
			continue
		
		# 如果有延迟，创建施法攻击
		if cast_delay > 0:
			_start_cast(target, damage, explosion_radius, cast_delay, i == 0)
		else:
			# 无延迟，立即攻击（只显示第一个目标的指示器）
			if i == 0 and explosion_radius > 0:
				_show_explosion_indicator(target.global_position, explosion_radius)
			
			# 直接伤害
			if target.has_method("enemy_hurt"):
				var final_damage = int(damage * weapon_data.explosion_damage_multiplier)
				target.enemy_hurt(final_damage)
			
			# 爆炸范围伤害
			if weapon_data.has_explosion_damage and explosion_radius > 0:
				_explode_at_position(target.global_position, explosion_radius, damage, target)

## 开始施法
func _start_cast(target: Node2D, damage: int, radius: float, delay: float, show_indicator: bool) -> void:
	var indicator = null
	
	# 只为主要目标显示指示器
	if show_indicator and radius > 0:
		indicator = _create_persistent_indicator(target, radius, delay)
	
	# 添加到施法列表
	casting_attacks.append({
		"target": target,
		"indicator": indicator,
		"timer": delay,
		"damage": damage
	})

## 创建持续指示器
func _create_persistent_indicator(target: Node2D, radius: float, duration: float) -> Node2D:
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	# 添加到场景树
	get_tree().root.add_child(indicator)
	
	# 初始化
	indicator._ready()
	
	# 获取颜色
	var indicator_color = _get_indicator_color()
	
	# 显示持续指示器
	if indicator.has_method("show_persistent"):
		indicator.show_persistent(target, radius, indicator_color, duration)
	
	return indicator

## 在指定位置产生爆炸效果（排除主目标避免重复伤害）
func _explode_at_position(pos: Vector2, radius: float, base_damage: int, exclude_target = null) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 跳过主目标（已经受到直接伤害）
		if enemy == exclude_target:
			continue
		
		var distance = pos.distance_to(enemy.global_position)
		
		# 如果在爆炸范围内
		if distance <= radius:
			# 根据距离计算伤害（距离越近伤害越高）
			var explosion_damage_mult = 1.0 - (distance / radius) * 0.5  # 最多衰减50%
			var final_damage = int(base_damage * explosion_damage_mult * weapon_data.explosion_damage_multiplier)
			
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage)

## 创建爆炸特效（可选）
func _create_explosion_effect(_pos: Vector2) -> void:
	# 这里可以添加粒子效果或其他视觉特效
	# 例如：GameMain.animation_scene_obj.run_animation({...})
	pass

## 显示爆炸范围指示器（短暂显示，用于无延迟攻击）
func _show_explosion_indicator(pos: Vector2, radius: float) -> void:
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	get_tree().root.add_child(indicator)
	indicator._ready()
	
	var indicator_color = _get_indicator_color()
	
	if indicator.has_method("show_at"):
		indicator.show_at(pos, radius, indicator_color, 0.3)
