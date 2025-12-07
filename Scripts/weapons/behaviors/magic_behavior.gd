extends WeaponBehavior
class_name MagicBehavior

## 魔法行为
## 
## 实现定点打击攻击方式
## 
## 参数 (params):
##   - damage: int 基础伤害
##   - explosion_radius: float 爆炸范围
##   - explosion_damage_multiplier: float 爆炸伤害倍数
##   - cast_delay: float 施法延迟（秒）
##   - is_target_locked: bool 是否锁定目标（跟随）
##   - max_targets: int 最大目标数量
##   - has_explosion_damage: bool 是否有范围爆炸伤害
##   - attack_speed: float 攻击间隔（秒）
##   - range: float 检测范围

## 爆炸指示器脚本
var explosion_indicator_script: GDScript = null

## 当前正在施法的攻击列表
var casting_attacks: Array = []

## 指示器颜色（可由武器配置覆盖，默认白色保留纹理原色）
var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.8)

## 缓存的自定义指示器纹理
var _cached_indicator_texture: Texture2D = null

func _on_initialize() -> void:
	casting_attacks.clear()
	
	# 加载爆炸指示器脚本
	explosion_indicator_script = preload("res://Scripts/weapons/explosion_indicator.gd")
	
	# 读取指示器颜色
	if params.has("indicator_color"):
		indicator_color = params.get("indicator_color")

	# 预加载并缓存指示器纹理
	_cached_indicator_texture = null
	var texture_path = params.get("indicator_texture_path", "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_cached_indicator_texture = load(texture_path)

func get_behavior_type() -> int:
	return WeaponData.BehaviorType.MAGIC

## 获取爆炸范围
func get_explosion_radius() -> float:
	var base_radius = params.get("explosion_radius", 150.0)
	
	if player_stats:
		return DamageCalculator.calculate_explosion_radius(base_radius, player_stats)
	
	return base_radius

## 获取爆炸伤害倍数
func get_explosion_damage_multiplier() -> float:
	return params.get("explosion_damage_multiplier", 1.0)

## 获取施法延迟
func get_cast_delay() -> float:
	return params.get("cast_delay", 0.0)

## 是否锁定目标
func is_target_locked() -> bool:
	return params.get("is_target_locked", true)

## 获取最大目标数
func get_max_targets() -> int:
	return params.get("max_targets", 1)

## 是否有爆炸伤害
func has_explosion_damage() -> bool:
	return params.get("has_explosion_damage", true)

func process(delta: float) -> void:
	_update_casting_attacks(delta)

## 更新施法攻击
func _update_casting_attacks(delta: float) -> void:
	var attacks_to_remove = []
	
	for i in range(casting_attacks.size()):
		var cast_data = casting_attacks[i]
		
		# 如果是锁敌模式，检查目标有效性
		if cast_data.is_locked:
			if not is_instance_valid(cast_data.target) or cast_data.target.get("is_dead"):
				_cancel_cast(cast_data)
				attacks_to_remove.append(i)
				continue
		
		# 更新倒计时
		cast_data.timer -= delta
		
		# 时间到，执行攻击
		if cast_data.timer <= 0:
			_execute_cast(cast_data)
			attacks_to_remove.append(i)
	
	# 移除已完成的攻击
	attacks_to_remove.reverse()
	for i in attacks_to_remove:
		casting_attacks.remove_at(i)

## 取消施法
func _cancel_cast(cast_data: Dictionary) -> void:
	if cast_data.indicator and is_instance_valid(cast_data.indicator):
		if cast_data.indicator.has_method("fade_out_and_remove"):
			cast_data.indicator.fade_out_and_remove(0.1)

## 执行施法
func _execute_cast(cast_data: Dictionary) -> void:
	var base_damage = cast_data.damage
	var explosion_radius = get_explosion_radius()
	var explosion_position: Vector2
	
	if cast_data.is_locked:
		# 锁敌模式：在目标当前位置爆炸
		var target = cast_data.target
		if not is_instance_valid(target):
			if cast_data.indicator and is_instance_valid(cast_data.indicator):
				cast_data.indicator.hide_and_remove() if cast_data.indicator.has_method("hide_and_remove") else cast_data.indicator.queue_free()
			return
		
		explosion_position = target.global_position
		
		# 暴击判定
		var final_damage = base_damage
		var is_critical = roll_critical()
		if is_critical:
			final_damage = apply_critical(base_damage)
		
		# 对目标造成直接伤害
		if target.has_method("enemy_hurt"):
			var damage_to_deal = int(final_damage * get_explosion_damage_multiplier())
			target.enemy_hurt(damage_to_deal, is_critical)
			apply_special_effects(target, damage_to_deal)
		
		# 爆炸范围伤害
		if has_explosion_damage() and explosion_radius > 0:
			_explode_at_position(explosion_position, explosion_radius, base_damage, target)
	else:
		# 非锁敌模式：在锁定的位置爆炸
		explosion_position = cast_data.target_position
		
		if has_explosion_damage() and explosion_radius > 0:
			_explode_at_position(explosion_position, explosion_radius, base_damage, null)
	
	# 播放爆炸特效
	_create_explosion_effect(explosion_position)
	
	# 清理指示器
	if cast_data.indicator and is_instance_valid(cast_data.indicator):
		if cast_data.indicator.has_method("hide_and_remove"):
			cast_data.indicator.hide_and_remove()
		else:
			cast_data.indicator.queue_free()

func perform_attack(enemies: Array) -> void:
	if enemies.is_empty() or not weapon:
		return
	
	var max_targets = get_max_targets()
	var cast_delay = get_cast_delay()
	var damage = get_final_damage()
	var explosion_radius = get_explosion_radius()
	
	# 选择目标
	var targets = []
	for i in range(min(enemies.size(), max_targets)):
		var enemy = enemies[i]
		if is_instance_valid(enemy):
			targets.append(enemy)
	
	if targets.is_empty():
		return
	
	# 为每个目标创建攻击
	for target in targets:
		if cast_delay > 0:
			_start_cast(target, damage, explosion_radius, cast_delay)
		else:
			_execute_immediate_attack(target, damage, explosion_radius)

## 开始施法
func _start_cast(target: Node2D, damage: int, radius: float, delay: float) -> void:
	var is_locked = is_target_locked()
	var indicator = null
	var target_position = target.global_position
	
	if radius > 0:
		if is_locked:
			indicator = _create_persistent_indicator(target, radius, delay)
		else:
			indicator = _create_fixed_indicator(target_position, radius, delay)
	
	casting_attacks.append({
		"target": target,
		"target_position": target_position,
		"indicator": indicator,
		"timer": delay,
		"damage": damage,
		"is_locked": is_locked
	})

## 立即执行攻击（无延迟）
func _execute_immediate_attack(target: Node2D, damage: int, radius: float) -> void:
	var is_locked = is_target_locked()
	var explosion_position = target.global_position
	
	# 显示短暂指示器
	if radius > 0:
		_show_explosion_indicator(explosion_position, radius)
	
	# 暴击判定
	var final_damage = damage
	var is_critical = roll_critical()
	if is_critical:
		final_damage = apply_critical(damage)
	
	if is_locked:
		# 锁敌模式：直接伤害 + 爆炸伤害
		if target.has_method("enemy_hurt"):
			var damage_to_deal = int(final_damage * get_explosion_damage_multiplier())
			target.enemy_hurt(damage_to_deal, is_critical)
			apply_special_effects(target, damage_to_deal)
	
	# 爆炸范围伤害
	if has_explosion_damage() and radius > 0:
		_explode_at_position(explosion_position, radius, damage, target if is_locked else null)
	
	# 播放爆炸特效
	_create_explosion_effect(explosion_position)

## 在指定位置产生爆炸效果
func _explode_at_position(pos: Vector2, radius: float, base_damage: int, exclude_target = null) -> void:
	if not weapon:
		return
	
	var enemies = weapon.get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 跳过主目标（已受到直接伤害）
		if enemy == exclude_target:
			continue
		
		var distance = pos.distance_to(enemy.global_position)
		
		if distance <= radius:
			# 根据距离计算伤害衰减
			var damage_mult = 1.0 - (distance / radius) * 0.5
			var final_damage = int(base_damage * damage_mult * get_explosion_damage_multiplier())
			
			if enemy.has_method("enemy_hurt"):
				enemy.enemy_hurt(final_damage)
				apply_special_effects(enemy, final_damage)

## 创建爆炸特效
func _create_explosion_effect(pos: Vector2) -> void:
	# 使用统一的特效管理器
	var weapon_name = params.get("weapon_name", "")
	if weapon_name != "" and weapon:
		CombatEffectManager.play_explosion(weapon_name, pos)

## 创建持续指示器（跟随目标）
func _create_persistent_indicator(target: Node2D, radius: float, duration: float) -> Node2D:
	if not weapon or not explosion_indicator_script:
		return null
	
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	weapon.get_tree().root.add_child(indicator)
	indicator._ready()
	
	# 设置自定义纹理
	var texture = _get_indicator_texture()
	if texture and indicator.has_method("set_texture"):
		indicator.set_texture(texture)
	
	if indicator.has_method("show_persistent"):
		indicator.show_persistent(target, radius, indicator_color, duration)
	
	return indicator

## 创建固定位置指示器
func _create_fixed_indicator(position: Vector2, radius: float, duration: float) -> Node2D:
	if not weapon or not explosion_indicator_script:
		return null
	
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	indicator.global_position = position
	weapon.get_tree().root.add_child(indicator)
	indicator._ready()
	
	# 设置自定义纹理
	var texture = _get_indicator_texture()
	if texture and indicator.has_method("set_texture"):
		indicator.set_texture(texture)
	
	if indicator.has_method("show_persistent"):
		indicator.show_persistent(null, radius, indicator_color, duration)
	
	return indicator

## 显示短暂指示器
func _show_explosion_indicator(pos: Vector2, radius: float) -> void:
	if not weapon or not explosion_indicator_script:
		return
	
	var indicator = Node2D.new()
	indicator.set_script(explosion_indicator_script)
	weapon.get_tree().root.add_child(indicator)
	indicator._ready()
	
	# 设置自定义纹理
	var texture = _get_indicator_texture()
	if texture and indicator.has_method("set_texture"):
		indicator.set_texture(texture)
	
	if indicator.has_method("show_at"):
		indicator.show_at(pos, radius, indicator_color, 0.3)

## 获取指示器纹理
func _get_indicator_texture() -> Texture2D:
	return _cached_indicator_texture

