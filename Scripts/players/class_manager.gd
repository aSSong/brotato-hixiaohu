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
	if current_class == null or current_class.skill_name.is_empty():
		return
	
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
	
	# ⭐ 如果技能已经激活（旧修改器还存在），先移除
	if skill_modifiers.has(skill_name):
		var old_modifier = skill_modifiers[skill_name]
		player.attribute_manager.remove_modifier_by_id(old_modifier.modifier_id)
		print("[ClassManager] 移除旧的技能修改器: %s" % skill_name)
	
	# 创建技能修改器
	var skill_modifier = _create_skill_modifier(skill_name, params)
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
	print("[ClassManager] 技能激活: %s，持续时间: %.1f秒" % [skill_name, skill_modifier.duration])

## 创建技能修改器
## 
## 根据技能名称和参数创建对应的AttributeModifier
func _create_skill_modifier(skill_name: String, params: Dictionary) -> AttributeModifier:
	var modifier = AttributeModifier.new()
	modifier.modifier_type = AttributeModifier.ModifierType.SKILL
	modifier.modifier_id = "skill_" + skill_name
	modifier.stats_delta = CombatStats.new()
	
	var duration = params.get("duration", 0.0)
	modifier.duration = duration
	modifier.initial_duration = duration
	
	# ⭐ 重要：将默认值重置为0，避免意外累加
	# 对于加法属性，默认值应该是0
	modifier.stats_delta.max_hp = 0
	modifier.stats_delta.speed = 0.0
	modifier.stats_delta.defense = 0
	modifier.stats_delta.luck = 0.0
	modifier.stats_delta.crit_chance = 0.0
	modifier.stats_delta.crit_damage = 0.0  # 默认值1.5改为0
	modifier.stats_delta.damage_reduction = 0.0
	
	# 对于乘法属性，默认值应该是1.0（不修改）
	# global_damage_mult, global_attack_speed_mult 等默认值是1.0，保持不变
	# 因为在 apply_to() 中使用 *= 运算符
	
	# 根据技能类型设置属性变化
	match skill_name:
		"狂暴":
			# 战士技能：攻击速度+50%，伤害+30%
			var attack_speed_boost = params.get("attack_speed_boost", 0.0)
			var damage_boost = params.get("damage_boost", 1.0)
			# ⭐ 修正：attack_speed_boost 是加成百分比（0.5 = +50%），转换为乘法倍数
			modifier.stats_delta.global_attack_speed_mult = 1.0 + attack_speed_boost
			modifier.stats_delta.global_damage_mult = damage_boost
		
		"精准射击":
			# 射手技能：暴击率+50%
			var crit_boost = params.get("crit_chance_boost", 0.0)
			modifier.stats_delta.crit_chance = crit_boost
			# 全部暴击效果由武器层面处理，这里只设置暴击率
		
		"魔法爆发":
			# 法师技能：爆炸范围x2，伤害+50%
			# 注意：这里使用乘法层
			var radius_mult = params.get("explosion_radius_multiplier", 1.0)
			var damage_mult = params.get("damage_multiplier", 1.0)
			modifier.stats_delta.magic_explosion_radius_mult = radius_mult
			modifier.stats_delta.magic_damage_mult = damage_mult
		
		"全面强化":
			# 平衡者技能：所有属性+20%
			var all_boost = params.get("all_stats_boost", 1.0)
			# 应用到所有武器类型
			modifier.stats_delta.global_damage_mult = all_boost
			modifier.stats_delta.global_attack_speed_mult = all_boost
			# 也可以应用到速度
			var speed_boost = (all_boost - 1.0) * 400.0
			modifier.stats_delta.speed = speed_boost
		
		"护盾":
			# 坦克技能：减伤50%
			var damage_reduction = params.get("damage_reduction", 0.0)
			modifier.stats_delta.damage_reduction = damage_reduction
			# 反弹伤害需要特殊处理（不是属性，是效果）
		
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

## 检查技能是否激活（兼容旧代码）
## 
## 注意：技能效果现在由AttributeManager管理
## 这个方法主要用于检查modifier是否存在
func is_skill_active(skill_name: String) -> bool:
	return skill_modifiers.has(skill_name)

## 获取技能效果值（已废弃）
## 
## 旧方法保留以兼容，但建议直接从player.attribute_manager.final_stats读取
@warning_ignore("unused_parameter")
func get_skill_effect(effect_name: String, default_value = 0.0):
	push_warning("[ClassManager] get_skill_effect() 已废弃，请直接访问 player.attribute_manager.final_stats")
	return default_value

## 获取被动效果值（已废弃）
## 
## 旧方法保留以兼容，但建议直接从current_class.base_stats读取
@warning_ignore("unused_parameter")
func get_passive_effect(effect_name: String, default_value = 1.0):
	push_warning("[ClassManager] get_passive_effect() 已废弃，请直接访问 current_class.base_stats")
	return default_value
