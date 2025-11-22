extends BaseWeapon
class_name MagicWeapon

## 魔法武器（重构版）
## 
## 使用DamageCalculator计算爆炸范围
## 支持暴击、吸血、燃烧等特效

@onready var shoot_pos: Marker2D = $shoot_pos
var explosion_particles_scene = null

## 爆炸指示器脚本
var explosion_indicator_script = preload("res://Scripts/weapons/explosion_indicator.gd")

## 指示器持续时间
var indicator_duration: float = 0.3

## 当前正在施法的攻击列表
var casting_attacks: Array = []

## 爆炸范围系数（旧系统兼容）
var explosion_radius_multiplier: float = 1.0

## 设置爆炸范围系数
func set_explosion_radius_multiplier(multiplier: float) -> void:
	explosion_radius_multiplier = multiplier

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
	# 如果@onready初始化失败，手动获取节点
	if not shoot_pos:
		shoot_pos = get_node_or_null("shoot_pos")
		# 如果节点不存在，创建一个新的
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
		
		# 如果是锁敌模式，需要检查目标有效性
		if cast_data.is_locked:
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
		# 非锁敌模式不需要检查目标，只在固定位置爆炸
		
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
	var base_damage = cast_data.damage
	var explosion_radius = weapon_data.explosion_radius if weapon_data else 150.0
	
	# 使用DamageCalculator计算最终爆炸范围
	if player_stats:
		explosion_radius = DamageCalculator.calculate_explosion_radius(
			explosion_radius,
			player_stats
		)
	else:
		# 降级方案：使用旧系统
		explosion_radius *= explosion_radius_multiplier
	
	# 确定爆炸位置
	var explosion_position: Vector2
	
	if cast_data.is_locked:
		# 锁敌模式：在目标当前位置爆炸
		var target = cast_data.target
		if not is_instance_valid(target):
			if cast_data.indicator and is_instance_valid(cast_data.indicator):
				cast_data.indicator.hide_and_remove()
			return
		explosion_position = target.global_position
		
		# 暴击判定（新系统）
		var final_damage = base_damage
		var is_critical = false
		if player_stats:
			is_critical = DamageCalculator.roll_critical(player_stats)
			if is_critical:
				final_damage = DamageCalculator.apply_critical_multiplier(base_damage, player_stats)
		
		# 对目标造成直接伤害
		if target.has_method("enemy_hurt"):
			var damage_to_deal = int(final_damage * weapon_data.explosion_damage_multiplier)
			target.enemy_hurt(damage_to_deal, is_critical)
			
			# 应用特殊效果（统一方法）
			apply_special_effects(target, damage_to_deal)
		
		# 爆炸范围伤害
		if weapon_data.has_explosion_damage and explosion_radius > 0:
			_explode_at_position(explosion_position, explosion_radius, base_damage, target)
	else:
		# 非锁敌模式：在锁定的位置爆炸
		explosion_position = cast_data.target_position
		
		if weapon_data.has_explosion_damage and explosion_radius > 0:
			_explode_at_position(explosion_position, explosion_radius, base_damage, null)
	
	# 播放爆炸粒子效果
	_create_explosion_effect(explosion_position)
	
	# 清理指示器
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
	
	# 调试：打印攻击信息
	print("[MagicWeapon] %s 攻击 | 目标数:%d 延迟:%.1fs" % [weapon_data.weapon_name, targets.size(), weapon_data.attack_cast_delay])
	
	# 获取延迟时间
	var cast_delay = weapon_data.attack_cast_delay if weapon_data else 0.0
	var damage = get_damage()
	var explosion_radius = weapon_data.explosion_radius * explosion_radius_multiplier
	
	# 为每个目标显示指示器（现在全部显示）
	for i in range(targets.size()):
		var target = targets[i]
		if not is_instance_valid(target):
			continue
		
		# 如果有延迟，创建施法攻击
		if cast_delay > 0:
			# 现在每个目标都显示指示器
			_start_cast(target, damage, explosion_radius, cast_delay, true)
		else:
			# 无延迟，立即攻击
			_execute_immediate_attack(target, damage, explosion_radius, true)

## 立即执行攻击（无延迟）
func _execute_immediate_attack(target: Node2D, damage: int, radius: float, show_indicator: bool) -> void:
	var is_locked = weapon_data.is_target_locked if weapon_data else true
	
	# 只显示第一个目标的指示器
	if show_indicator and radius > 0:
		_show_explosion_indicator(target.global_position, radius)
	
		if is_locked:
			# 锁敌模式：直接伤害 + 爆炸伤害
			if target.has_method("enemy_hurt"):
				# 暴击判定
				var final_damage = damage
				var is_critical = false
				if player_stats:
					is_critical = DamageCalculator.roll_critical(player_stats)
					if is_critical:
						final_damage = DamageCalculator.apply_critical_multiplier(damage, player_stats)
				
				var damage_to_deal = int(final_damage * weapon_data.explosion_damage_multiplier)
				target.enemy_hurt(damage_to_deal, is_critical)
				
				# 应用特殊效果（统一方法）
				apply_special_effects(target, damage_to_deal)
		
		# 爆炸范围伤害（排除主目标）
		if weapon_data.has_explosion_damage and radius > 0:
			_explode_at_position(target.global_position, radius, damage, target)
		
		# 播放爆炸粒子效果
		_create_explosion_effect(target.global_position)
	else:
		# 非锁敌模式：只有爆炸伤害
		if weapon_data.has_explosion_damage and radius > 0:
			_explode_at_position(target.global_position, radius, damage, null)
		
		# 播放爆炸粒子效果
		_create_explosion_effect(target.global_position)

## 开始施法
func _start_cast(target: Node2D, damage: int, radius: float, delay: float, show_indicator: bool) -> void:
	var is_locked = weapon_data.is_target_locked if weapon_data else true
	var indicator = null
	var target_position = target.global_position  # 记录初始位置
	
	# 只为主要目标显示指示器
	if show_indicator and radius > 0:
		if is_locked:
			# 锁敌模式：指示器跟随目标
			indicator = _create_persistent_indicator(target, radius, delay)
		else:
			# 非锁敌模式：指示器固定在位置
			indicator = _create_fixed_indicator(target_position, radius, delay)
	
	# 添加到施法列表
	casting_attacks.append({
		"target": target,
		"target_position": target_position,  # 记录初始位置
		"indicator": indicator,
		"timer": delay,
		"damage": damage,
		"is_locked": is_locked
	})

## 创建持续指示器（跟随目标）
func _create_persistent_indicator(target: Node2D, radius: float, duration: float) -> Node2D:
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	# 添加到场景树
	get_tree().root.add_child(indicator)
	
	# 初始化
	indicator._ready()
	
	# 获取颜色
	var indicator_color = _get_indicator_color()
	
	# 显示持续指示器（跟随模式）
	if indicator.has_method("show_persistent"):
		indicator.show_persistent(target, radius, indicator_color, duration)
	
	print("[MagicWeapon] 创建跟随指示器 | 武器:%s 目标位置:(%.0f, %.0f) 颜色:%s" % [weapon_data.weapon_name, target.global_position.x, target.global_position.y, indicator_color])
	
	return indicator

## 创建固定位置指示器（不跟随目标）
func _create_fixed_indicator(position: Vector2, radius: float, duration: float) -> Node2D:
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	# 先设置位置（在添加到场景树之前）
	indicator.global_position = position
	
	# 添加到场景树
	get_tree().root.add_child(indicator)
	
	# 初始化
	indicator._ready()
	
	# 获取颜色
	var indicator_color = _get_indicator_color()
	
	# 显示持续指示器（固定位置模式）
	# 传null作为target，指示器会保持在当前位置
	if indicator.has_method("show_persistent"):
		indicator.show_persistent(null, radius, indicator_color, duration)
	
	print("[MagicWeapon] 创建固定位置指示器 | 武器:%s 位置:(%.0f, %.0f) 颜色:%s" % [weapon_data.weapon_name, position.x, position.y, indicator_color])
	
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
				
				# 应用特殊效果（统一方法）
				apply_special_effects(enemy, final_damage)

## 创建爆炸特效
func _create_explosion_effect(pos: Vector2) -> void:
	if weapon_data == null:
		return
	
	# 使用统一的特效管理器
	CombatEffectManager.play_explosion(weapon_data.weapon_name, pos)

## 显示爆炸范围指示器（短暂显示，用于无延迟攻击）
func _show_explosion_indicator(pos: Vector2, radius: float) -> void:
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	
	get_tree().root.add_child(indicator)
	indicator._ready()
	
	var indicator_color = _get_indicator_color()
	
	if indicator.has_method("show_at"):
		indicator.show_at(pos, radius, indicator_color, 0.3)
