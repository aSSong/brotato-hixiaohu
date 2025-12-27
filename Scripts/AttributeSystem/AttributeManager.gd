extends Node
class_name AttributeManager

## 属性管理器
## 
## 职责：统一管理玩家的所有战斗属性，处理加成叠加和计算
## 
## 使用方法：
##   1. 设置base_stats（来自ClassData）
##   2. 通过add_permanent/temporary_modifier添加加成
##   3. 监听stats_changed信号获取最新属性
## 
## 注意事项：
##   - recalculate()是昂贵操作，避免频繁调用
##   - temporary_modifier会自动过期
##   - 所有modifier应用分层规则：先add后mult
## 
## 使用示例：
##   attribute_manager = AttributeManager.new()
##   add_child(attribute_manager)
##   attribute_manager.base_stats = class_data.base_stats.clone()
##   attribute_manager.stats_changed.connect(_on_stats_changed)
##   attribute_manager.recalculate()

## 基础属性（来自职业）
var base_stats: CombatStats = null

## 永久加成列表（来自升级）
var permanent_modifiers: Array[AttributeModifier] = []

## 临时加成列表（来自技能、Buff）
var temporary_modifiers: Array[AttributeModifier] = []

## 最终计算结果
var final_stats: CombatStats = null

## 属性变化信号
## 
## 当final_stats重新计算后发出
## @param new_stats 新的最终属性
signal stats_changed(new_stats: CombatStats)

## 属性日志信号
## 当属性发生变化产生日志时发出
signal stats_log(message: String)

func _ready():
	# 确保base_stats存在
	if not base_stats:
		base_stats = CombatStats.new()
	
	# 初始化final_stats
	if not final_stats:
		final_stats = CombatStats.new()
		recalculate()

## 重新计算最终属性
## 
## 应用所有modifier到base_stats，计算final_stats
## 计算顺序：
##   1. 从base_stats克隆开始
##   2. 应用所有永久modifier
##   3. 应用所有临时modifier
##   4. 发送stats_changed信号
## 
## 性能：O(n×m)，n=modifier数量，m=属性数量
## 
## 调用时机：添加/移除modifier后必须调用
## 
## @see add_permanent_modifier, add_temporary_modifier
func recalculate() -> void:
	if not base_stats:
		push_error("[AttributeManager] base_stats 未设置！")
		return
	
	# 保存旧值用于对比
	var old_stats = final_stats
	
	# 从基础属性开始
	final_stats = base_stats.clone()
	
	# 应用所有永久加成
	for modifier in permanent_modifiers:
		if modifier and modifier.stats_delta:
			var old_speed = final_stats.speed
			modifier.apply_to(final_stats)
			if not is_equal_approx(final_stats.speed, old_speed):
				print("[AttributeManager] 永久加成改变速度: %+.1f (ID: %s)" % [final_stats.speed - old_speed, modifier.modifier_id])
	
	# 应用所有临时加成
	for modifier in temporary_modifiers:
		if modifier and modifier.stats_delta and not modifier.is_expired():
			var old_speed = final_stats.speed
			modifier.apply_to(final_stats)
			if not is_equal_approx(final_stats.speed, old_speed):
				print("[AttributeManager] 临时加成改变速度: %+.1f (ID: %s)" % [final_stats.speed - old_speed, modifier.modifier_id])
	
	# 记录属性变化 Diff
	_log_stats_diff(old_stats, final_stats)
	
	# 发送变化信号
	stats_changed.emit(final_stats)

## 记录属性变化 Diff
func _log_stats_diff(old_stats: CombatStats, new_stats: CombatStats) -> void:
	if not old_stats or not new_stats:
		return
		
	var diffs = []
	
	# 基础属性
	if old_stats.max_hp != new_stats.max_hp:
		diffs.append("MaxHP: %d -> %d (%+d)" % [old_stats.max_hp, new_stats.max_hp, new_stats.max_hp - old_stats.max_hp])
	if not is_equal_approx(old_stats.speed, new_stats.speed):
		diffs.append("Speed: %.1f -> %.1f (%+.1f)" % [old_stats.speed, new_stats.speed, new_stats.speed - old_stats.speed])
	if old_stats.defense != new_stats.defense:
		diffs.append("Defense: %d -> %d (%+d)" % [old_stats.defense, new_stats.defense, new_stats.defense - old_stats.defense])
	if not is_equal_approx(old_stats.luck, new_stats.luck):
		diffs.append("Luck: %.1f -> %.1f (%+.1f)" % [old_stats.luck, new_stats.luck, new_stats.luck - old_stats.luck])
		
	# 战斗属性
	if not is_equal_approx(old_stats.crit_chance, new_stats.crit_chance):
		diffs.append("CritChance: %.1f%% -> %.1f%% (%+.1f%%)" % [old_stats.crit_chance * 100, new_stats.crit_chance * 100, (new_stats.crit_chance - old_stats.crit_chance) * 100])
	if not is_equal_approx(old_stats.crit_damage, new_stats.crit_damage):
		diffs.append("CritDamage: %.1f%% -> %.1f%% (%+.1f%%)" % [old_stats.crit_damage * 100, new_stats.crit_damage * 100, (new_stats.crit_damage - old_stats.crit_damage) * 100])
	if not is_equal_approx(old_stats.damage_reduction, new_stats.damage_reduction):
		diffs.append("DamageReduction: %.0f -> %.0f (%+.0f)" % [old_stats.damage_reduction, new_stats.damage_reduction, (new_stats.damage_reduction - old_stats.damage_reduction)])
		
	# 全局属性
	if not is_equal_approx(old_stats.global_damage_mult, new_stats.global_damage_mult):
		diffs.append("GlobalDamage: x%.2f -> x%.2f" % [old_stats.global_damage_mult, new_stats.global_damage_mult])
	if not is_equal_approx(old_stats.global_attack_speed_mult, new_stats.global_attack_speed_mult):
		diffs.append("GlobalAttackSpeed: x%.2f -> x%.2f" % [old_stats.global_attack_speed_mult, new_stats.global_attack_speed_mult])
	
	# 异常效果系数
	if not is_equal_approx(old_stats.status_duration_mult, new_stats.status_duration_mult):
		diffs.append("StatusDurationMult: x%.2f -> x%.2f" % [old_stats.status_duration_mult, new_stats.status_duration_mult])
	if not is_equal_approx(old_stats.status_effect_mult, new_stats.status_effect_mult):
		diffs.append("StatusEffectMult: x%.2f -> x%.2f" % [old_stats.status_effect_mult, new_stats.status_effect_mult])
	if not is_equal_approx(old_stats.status_chance_mult, new_stats.status_chance_mult):
		diffs.append("StatusChanceMult: x%.2f -> x%.2f" % [old_stats.status_chance_mult, new_stats.status_chance_mult])
		
	if not diffs.is_empty():
		var msg = "[AttributeManager] 属性变更:\n  " + "\n  ".join(diffs)
		print(msg)
		stats_log.emit(msg)

## 添加永久加成
## 
## 永久加成不会过期，通常来自升级系统
## 
## @param modifier 要添加的修改器
func add_permanent_modifier(modifier: AttributeModifier) -> void:
	if not modifier:
		push_warning("[AttributeManager] 尝试添加空的永久加成")
		return
	
	permanent_modifiers.append(modifier)
	recalculate()
	
	print("[AttributeManager] 添加永久加成，当前永久加成数量: ", permanent_modifiers.size())

## 添加临时加成
## 
## 临时加成有持续时间，会自动过期
## 通常来自技能和Buff系统
## 
## @param modifier 要添加的修改器（必须设置duration > 0）
func add_temporary_modifier(modifier: AttributeModifier) -> void:
	if not modifier:
		push_warning("[AttributeManager] 尝试添加空的临时加成")
		return
	
	# 保存初始持续时间
	if modifier.duration > 0:
		modifier.initial_duration = modifier.duration
	
	temporary_modifiers.append(modifier)
	recalculate()
	
	print("[AttributeManager] 添加临时加成，持续时间: %.1f秒" % modifier.duration)

## 移除指定的加成
## 
## 从永久或临时列表中移除指定的modifier
## 
## @param modifier 要移除的修改器
## @return 是否成功移除
func remove_modifier(modifier: AttributeModifier) -> bool:
	var removed = false
	
	# 尝试从永久列表移除
	if permanent_modifiers.has(modifier):
		permanent_modifiers.erase(modifier)
		removed = true
	
	# 尝试从临时列表移除
	if temporary_modifiers.has(modifier):
		temporary_modifiers.erase(modifier)
		removed = true
	
	# 如果成功移除，重新计算
	if removed:
		recalculate()
		print("[AttributeManager] 移除加成")
	
	return removed

## 根据ID移除加成
## 
## @param modifier_id 加成的唯一标识
## @return 是否成功移除
func remove_modifier_by_id(modifier_id: String) -> bool:
	if modifier_id.is_empty():
		return false
	
	var removed = false
	
	# 从永久列表移除
	for i in range(permanent_modifiers.size() - 1, -1, -1):
		if permanent_modifiers[i].modifier_id == modifier_id:
			permanent_modifiers.remove_at(i)
			removed = true
	
	# 从临时列表移除
	for i in range(temporary_modifiers.size() - 1, -1, -1):
		if temporary_modifiers[i].modifier_id == modifier_id:
			temporary_modifiers.remove_at(i)
			removed = true
	
	if removed:
		recalculate()
		print("[AttributeManager] 根据ID移除加成: ", modifier_id)
	
	return removed

## 清除所有永久加成
func clear_permanent_modifiers() -> void:
	permanent_modifiers.clear()
	recalculate()
	print("[AttributeManager] 清除所有永久加成")

## 清除所有临时加成
func clear_temporary_modifiers() -> void:
	temporary_modifiers.clear()
	recalculate()
	print("[AttributeManager] 清除所有临时加成")

## 更新临时加成的持续时间
## 
## 每帧调用，更新所有临时加成的剩余时间
## 移除已过期的加成
## 
## @param delta 时间增量（秒）
func _process(delta: float) -> void:
	if temporary_modifiers.is_empty():
		return
	
	var need_recalculate = false
	var expired_indices = []
	
	# 更新持续时间，收集过期的索引
	for i in range(temporary_modifiers.size()):
		var modifier = temporary_modifiers[i]
		if modifier.duration > 0:
			modifier.update(delta)
			
			# 检查是否过期
			if modifier.is_expired():
				expired_indices.append(i)
	
	# 从后向前移除过期的加成（避免索引错位）
	if not expired_indices.is_empty():
		expired_indices.reverse()
		for i in expired_indices:
			var expired_modifier = temporary_modifiers[i]
			print("[AttributeManager] 临时加成过期: ", expired_modifier.modifier_type)
			temporary_modifiers.remove_at(i)
		
		# 重新计算属性
		recalculate()

## 调试输出：打印所有加成信息
func debug_print_modifiers() -> void:
	print("=== AttributeManager Debug ===")
	print("永久加成数量: ", permanent_modifiers.size())
	for i in range(permanent_modifiers.size()):
		var m = permanent_modifiers[i]
		print("  [%d] Type: %s" % [i, ModifierType.keys()[m.modifier_type]])
	
	print("临时加成数量: ", temporary_modifiers.size())
	for i in range(temporary_modifiers.size()):
		var m = temporary_modifiers[i]
		print("  [%d] Type: %s, Duration: %.1f" % [i, ModifierType.keys()[m.modifier_type], m.duration])
	
	print("最终属性:")
	if final_stats:
		final_stats.debug_print()
	print("==============================")

## ModifierType枚举（用于调试显示）
enum ModifierType {
	BASE,
	UPGRADE,
	SKILL,
	BUFF
}
