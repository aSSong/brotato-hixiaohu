extends Node
class_name ClassManager

## 职业管理器（重构版）
## 
## 管理职业技能的激活和失效
## 使用AttributeManager应用技能效果，移除所有硬编码

signal skill_activated(skill_name: String)
signal skill_deactivated(skill_name: String)

var current_class: ClassData = null
var active_skills: Dictionary = {}  # 存储技能CD: {skill_name: cooldown_time}
var skill_modifiers: Dictionary = {}  # 存储技能的AttributeModifier引用: {skill_name: modifier}

## 设置当前职业
func set_class(class_data: ClassData) -> void:
	current_class = class_data
	active_skills.clear()
	skill_modifiers.clear()

## 激活技能
func activate_skill() -> void:
	if current_class == null:
		return
	
	# 优先使用新的 SkillData 系统
	if current_class.skill_data:
		_activate_skill_from_data(current_class.skill_data)
		return
		
	# 兼容旧系统 (如果 skill_data 为空但 skill_name 不为空)
	if not current_class.skill_name.is_empty():
		push_warning("[ClassManager] ⚠️ 正在使用旧技能系统激活技能: %s (请迁移到 SkillData)" % current_class.skill_name)
		print("[ClassManager] ⚠️ 警告：调用了旧的技能系统！")
		_activate_skill_legacy()

## 从 SkillData 激活技能
func _activate_skill_from_data(skill_data: SkillData) -> void:
	var skill_name = skill_data.name
	
	# 检查冷却时间
	if active_skills.has(skill_name):
		if active_skills[skill_name] > 0:
			return  # 技能还在冷却中
	
	# 获取玩家引用
	var player = get_parent()
	if not player or not player.has_node("AttributeManager"):
		push_warning("[ClassManager] 玩家没有AttributeManager，无法激活技能")
		return
	
	# 如果技能已经激活（旧修改器还存在），先移除
	if skill_modifiers.has(skill_name):
		var old_modifier = skill_modifiers[skill_name]
		player.attribute_manager.remove_modifier_by_id(old_modifier.modifier_id)
		print("[ClassManager] 移除旧的技能修改器: %s" % skill_name)
	
	# 创建技能修改器
	var skill_modifier = AttributeModifier.new()
	skill_modifier.modifier_type = AttributeModifier.ModifierType.SKILL
	skill_modifier.modifier_id = "skill_" + skill_name
	skill_modifier.duration = skill_data.duration
	skill_modifier.initial_duration = skill_data.duration
	
	# 克隆属性加成 (必须克隆，否则会修改资源文件)
	if skill_data.stats_modifier:
		skill_modifier.stats_delta = skill_data.stats_modifier.clone()
	else:
		skill_modifier.stats_delta = CombatStats.new()
		# 确保默认值干净
		skill_modifier.stats_delta.max_hp = 0
		skill_modifier.stats_delta.speed = 0.0
	
	# 添加到AttributeManager
	player.attribute_manager.add_temporary_modifier(skill_modifier)
	
	# 保存修改器引用
	skill_modifiers[skill_name] = skill_modifier
	
	# 设置冷却时间
	if skill_data.cooldown > 0:
		active_skills[skill_name] = skill_data.cooldown
	
	# 发送信号
	skill_activated.emit(skill_name)
	print("[ClassManager] 技能激活: %s，持续时间: %.1f秒" % [skill_name, skill_modifier.duration])

## 激活技能（旧系统兼容）
func _activate_skill_legacy() -> void:
	var skill_name = current_class.skill_name
	var params = current_class.skill_params
	var cooldown = params.get("cooldown", 0.0)
	
	# 检查冷却时间
	if active_skills.has(skill_name):
		if active_skills[skill_name] > 0:
			return  # 技能还在冷却中
	
	# 获取玩家引用
	var player = get_parent()
	if not player or not player.has_node("AttributeManager"):
		push_warning("[ClassManager] 玩家没有AttributeManager，无法激活技能")
		return
	
	# 如果技能已经激活（旧修改器还存在），先移除
	if skill_modifiers.has(skill_name):
		var old_modifier = skill_modifiers[skill_name]
		player.attribute_manager.remove_modifier_by_id(old_modifier.modifier_id)
	
	# 创建技能修改器
	var skill_modifier = _create_skill_modifier_legacy(skill_name, params)
	if not skill_modifier:
		return
	
	# 添加到AttributeManager
	player.attribute_manager.add_temporary_modifier(skill_modifier)
	
	# 保存修改器引用
	skill_modifiers[skill_name] = skill_modifier
	
	# 设置冷却时间
	if cooldown > 0:
		active_skills[skill_name] = cooldown
	
	# 发送信号
	skill_activated.emit(skill_name)
	print("[ClassManager] 技能激活(旧系统): %s" % skill_name)

## 创建技能修改器（旧系统兼容）
func _create_skill_modifier_legacy(skill_name: String, params: Dictionary) -> AttributeModifier:
	var modifier = AttributeModifier.new()
	modifier.modifier_type = AttributeModifier.ModifierType.SKILL
	modifier.modifier_id = "skill_" + skill_name
	modifier.stats_delta = CombatStats.new()
	
	var duration = params.get("duration", 0.0)
	modifier.duration = duration
	modifier.initial_duration = duration
	
	# 将默认值重置为0
	modifier.stats_delta.max_hp = 0
	modifier.stats_delta.speed = 0.0
	modifier.stats_delta.defense = 0
	modifier.stats_delta.luck = 0.0
	modifier.stats_delta.crit_chance = 0.0
	modifier.stats_delta.crit_damage = 0.0
	modifier.stats_delta.damage_reduction = 0.0
	
	# 根据技能类型设置属性变化
	match skill_name:
		"狂暴":
			var attack_speed_boost = params.get("attack_speed_boost", 0.0)
			var damage_boost = params.get("damage_boost", 1.0)
			modifier.stats_delta.global_attack_speed_mult = 1.0 + attack_speed_boost
			modifier.stats_delta.global_damage_mult = damage_boost
		
		"精准射击":
			var crit_boost = params.get("crit_chance_boost", 0.0)
			modifier.stats_delta.crit_chance = crit_boost
		
		"魔法爆发":
			var radius_mult = params.get("explosion_radius_multiplier", 1.0)
			var damage_mult = params.get("damage_multiplier", 1.0)
			modifier.stats_delta.magic_explosion_radius_mult = radius_mult
			modifier.stats_delta.magic_damage_mult = damage_mult
		
		"全面强化":
			var all_boost = params.get("all_stats_boost", 1.0)
			modifier.stats_delta.global_damage_mult = all_boost
			modifier.stats_delta.global_attack_speed_mult = all_boost
			var speed_boost = (all_boost - 1.0) * 400.0
			modifier.stats_delta.speed = speed_boost
		
		"护盾":
			var damage_reduction = params.get("damage_reduction", 0.0)
			modifier.stats_delta.damage_reduction = damage_reduction
		
		_:
			push_warning("[ClassManager] 未知技能: " + skill_name)
			return null
	
	return modifier

## 更新冷却时间
func _process(delta: float) -> void:
	var skills_to_remove = []
	
	# 更新所有技能的CD
	for skill_name in active_skills.keys():
		active_skills[skill_name] -= delta
		
		# CD结束
		if active_skills[skill_name] <= 0:
			skills_to_remove.append(skill_name)
	
	# 移除已结束CD的技能
	for skill_name in skills_to_remove:
		active_skills.erase(skill_name)

## 检查技能是否在冷却中
func is_skill_on_cooldown(skill_name: String) -> bool:
	return active_skills.has(skill_name) and active_skills[skill_name] > 0

## 获取技能剩余冷却时间
func get_skill_cooldown(skill_name: String) -> float:
	return active_skills.get(skill_name, 0.0)

## 检查技能是否激活
func is_skill_active(skill_name: String) -> bool:
	return skill_modifiers.has(skill_name)

## 获取技能效果值（已废弃）
@warning_ignore("unused_parameter")
func get_skill_effect(effect_name: String, default_value = 0.0):
	push_warning("[ClassManager] get_skill_effect() 已废弃，请直接访问 player.attribute_manager.final_stats")
	return default_value

## 获取被动效果值（已废弃）
@warning_ignore("unused_parameter")
func get_passive_effect(effect_name: String, default_value = 1.0):
	push_warning("[ClassManager] get_passive_effect() 已废弃，请直接访问 current_class.base_stats")
	return default_value
