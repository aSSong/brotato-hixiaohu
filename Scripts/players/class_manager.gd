extends Node
class_name ClassManager

## 职业管理器
## 管理职业的被动技能效果和触发

signal skill_activated(skill_name: String)
signal skill_deactivated(skill_name: String)

var current_class: ClassData = null
var active_skills: Dictionary = {}  # 存储激活的技能及其剩余时间

## 设置当前职业
func set_class(class_data: ClassData) -> void:
	current_class = class_data
	active_skills.clear()
	
	if current_class == null:
		return
	
	# 不再需要解析特性，直接从 ClassData 读取属性即可

## 激活技能
func activate_skill() -> void:
	if current_class == null or current_class.skill_name.is_empty():
		return
	
	var skill_name = current_class.skill_name
	var params = current_class.skill_params
	var cooldown = params.get("cooldown", 0.0)
	
	# 检查冷却时间
	var cd_key = skill_name + "_cd"
	if active_skills.has(cd_key):
		var remaining_cd_value = active_skills[cd_key]
		# 确保是数值类型
		if typeof(remaining_cd_value) == TYPE_FLOAT or typeof(remaining_cd_value) == TYPE_INT:
			var remaining_cd = float(remaining_cd_value)
			if remaining_cd > 0:
				return  # 技能还在冷却中
	
	# 激活技能
	var duration = params.get("duration", 0.0)
	active_skills[skill_name] = duration
	
	# 设置冷却时间
	if cooldown > 0:
		active_skills[cd_key] = cooldown
	
	skill_activated.emit(skill_name)
	
	# 根据技能名称执行对应效果
	_execute_skill_effect(skill_name, params)

## 执行技能效果
func _execute_skill_effect(skill_name: String, params: Dictionary) -> void:
	match skill_name:
		"狂暴":
			# 攻击速度和伤害提升
			var attack_speed_boost = params.get("attack_speed_boost", 0.0)
			var damage_boost = params.get("damage_boost", 1.0)
			active_skills["狂暴_attack_speed"] = attack_speed_boost
			active_skills["狂暴_damage"] = damage_boost
		
		"精准射击":
			# 暴击率提升，所有子弹必定暴击
			var crit_boost = params.get("crit_chance_boost", 0.0)
			active_skills["精准射击_crit"] = crit_boost
			active_skills["精准射击_all_crit"] = params.get("all_projectiles_crit", false)
		
		"魔法爆发":
			# 爆炸范围和伤害提升
			var radius_mult = params.get("explosion_radius_multiplier", 1.0)
			var damage_mult = params.get("damage_multiplier", 1.0)
			active_skills["魔法爆发_radius"] = radius_mult
			active_skills["魔法爆发_damage"] = damage_mult
		
		"全面强化":
			# 所有属性提升
			var all_boost = params.get("all_stats_boost", 1.0)
			active_skills["全面强化_multiplier"] = all_boost
		
		"护盾":
			# 减伤和反弹伤害
			var damage_reduction = params.get("damage_reduction", 0.0)
			var reflect_damage = params.get("reflect_damage", 0.0)
			active_skills["护盾_reduction"] = damage_reduction
			active_skills["护盾_reflect"] = reflect_damage

## 更新技能持续时间
func _process(delta: float) -> void:
	var keys_to_update = active_skills.keys().duplicate()
	var skills_to_deactivate = []  # 收集需要取消激活的技能
	
	for key in keys_to_update:
		# 确保: 键仍然存在（可能已被其他代码删除）
		if not active_skills.has(key):
			continue
		
		var value = active_skills[key]
		
		# 只处理数值类型（时间），跳过布尔值等其他类型
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		
		var remaining_time = float(value)
		if remaining_time > 0:
			remaining_time -= delta
			# 再次检查键是否存在
			if active_skills.has(key):
				active_skills[key] = remaining_time
			
			# 如果是技能持续时间（不是CD，也不是子效果），检查是否结束
			if not key.contains("_cd") and not key.contains("_"):
				if remaining_time <= 0:
					# 收集需要取消激活的技能，稍后处理
					skills_to_deactivate.append(key)
	
	# 在所有时间更新完成后，再取消激活技能
	for skill_name in skills_to_deactivate:
		_deactivate_skill(skill_name)

## 取消激活技能
func _deactivate_skill(skill_name: String) -> void:
	# 先发送信号，通知技能结束
	skill_deactivated.emit(skill_name)
	
	# 移除技能持续时间，但保留CD计时器
	# CD计时器键名是 skill_name + "_cd"，不应该被删除
	var keys_to_remove = []
	var keys_copy = active_skills.keys().duplicate()  # 创建键的副本
	for key in keys_copy:
		# 只删除技能效果相关的键，不包括CD键
		# 确保键存在后再检查
		if active_skills.has(key) and key.begins_with(skill_name) and not key.ends_with("_cd"):
			keys_to_remove.append(key)
	
	# 删除所有相关键
	for key in keys_to_remove:
		if active_skills.has(key):
			active_skills.erase(key)

## 获取被动效果值（直接从 ClassData 读取）
func get_passive_effect(effect_name: String, default_value = 1.0):
	if current_class == null:
		return default_value
	
	# 根据效果名称映射到 ClassData 的对应属性
	match effect_name:
		"attack_speed_multiplier":
			return current_class.attack_speed_multiplier
		"speed_multiplier":
			# 移动速度系数（基于 speed 相对于 400 的比例）
			return current_class.speed / 400.0
		"all_weapon_damage_multiplier":
			return current_class.attack_multiplier
		"melee_damage_multiplier":
			return current_class.melee_damage_multiplier
		"ranged_damage_multiplier":
			return current_class.ranged_damage_multiplier
		"magic_damage_multiplier":
			return current_class.magic_damage_multiplier
		"melee_speed_multiplier":
			return current_class.melee_speed_multiplier
		"ranged_speed_multiplier":
			return current_class.ranged_speed_multiplier
		"magic_speed_multiplier":
			return current_class.magic_speed_multiplier
		"melee_range_multiplier":
			return current_class.melee_range_multiplier
		"ranged_range_multiplier":
			return current_class.ranged_range_multiplier
		"magic_range_multiplier":
			return current_class.magic_range_multiplier
		"melee_knockback_multiplier":
			return current_class.melee_knockback_multiplier
		"magic_explosion_radius_multiplier":
			return current_class.magic_explosion_radius_multiplier
		"damage_reduction_multiplier":
			return current_class.damage_reduction_multiplier
		"hp_bonus":
			# 血量加成（相对于基础 100）
			return current_class.max_hp - 100
		"defense_bonus":
			return current_class.defense
		_:
			return default_value

## 获取技能效果值
func get_skill_effect(effect_name: String, default_value = 0.0):
	# 双重检查：先检查键是否存在
	if not active_skills.has(effect_name):
		return default_value
	
	# 使用 get() 方法安全获取值，避免键在检查后被删除
	var value = active_skills.get(effect_name, default_value)
	
	# 确保返回数值类型
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return default_value

## 检查技能是否激活
func is_skill_active(skill_name: String) -> bool:
	# 双重检查：先检查键是否存在
	if not active_skills.has(skill_name):
		return false
	
	# 使用 get() 方法安全获取值，避免键在检查后被删除
	var value = active_skills.get(skill_name, 0.0)
	
	# 确保是数值类型
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) > 0
	return false
