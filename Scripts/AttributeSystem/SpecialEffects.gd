extends Node
class_name SpecialEffects

## 特殊效果处理器（重构版）
## 
## 职责：统一管理所有特殊战斗效果
## 支持：燃烧、流血、冰冻、减速、中毒、吸血、治愈
## 
## 所有方法都是静态方法，可以直接调用
## 
## 使用示例：
##   SpecialEffects.try_apply_status_effect(
##       attacker_stats, 
##       target, 
##       "burn", 
##       {"chance": 0.3, "tick_interval": 1.0, "damage": 10, "duration": 5.0}
##   )

## 异常效果类型枚举
enum StatusEffectType {
	BURN,      ## 燃烧
	BLEED,     ## 流血
	FREEZE,    ## 冰冻
	SLOW,      ## 减速
	POISON,    ## 中毒
	LIFESTEAL, ## 吸血
	HEAL       ## 治愈
}

## 统一应用异常效果
## 
## @param attacker_stats 攻击者的战斗属性
## @param target 目标对象
## @param effect_type 效果类型（字符串："burn", "bleed", "freeze", "slow", "poison", "lifesteal", "heal"）
## @param effect_params 效果参数字典
##   - 燃烧/流血/中毒: {"chance": float, "tick_interval": float, "damage": float, "duration": float}
##   - 冰冻: {"chance": float, "duration": float}
##   - 减速: {"chance": float, "duration": float, "slow_percent": float}
##   - 吸血/治愈: {"amount": float} 或 {"percent": float}
## @return 是否成功应用效果
static func try_apply_status_effect(
	attacker_stats: CombatStats, 
	target, 
	effect_type: String, 
	effect_params: Dictionary
) -> bool:
	if not attacker_stats:
		return false
	
	# 吸血效果不需要target（敌人），只需要attacker（玩家）
	if effect_type.to_lower() != "lifesteal" and not target:
		return false
	
	# 根据效果类型调用对应的处理方法
	match effect_type.to_lower():
		"burn":
			return _apply_burn(attacker_stats, target, effect_params)
		"bleed":
			return _apply_bleed(attacker_stats, target, effect_params)
		"freeze":
			return _apply_freeze(attacker_stats, target, effect_params)
		"slow":
			return _apply_slow(attacker_stats, target, effect_params)
		"poison":
			return _apply_poison(attacker_stats, target, effect_params)
		"lifesteal":
			return _apply_lifesteal(attacker_stats, target, effect_params)
		"heal":
			return _apply_heal(attacker_stats, target, effect_params)
		_:
			push_warning("[SpecialEffects] 未知的效果类型: %s" % effect_type)
			return false

## 应用燃烧效果
static func _apply_burn(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var chance = params.get("chance", 0.0)
	var tick_interval = params.get("tick_interval", 1.0)
	var damage = params.get("damage", 0.0)
	var duration = params.get("duration", 3.0)
	
	# 应用异常概率加成
	chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 应用异常持续时间系数
	duration *= attacker_stats.status_duration_mult
	
	# 应用异常效果加成
	damage *= attacker_stats.status_effect_mult
	
	# 检查目标是否有BuffSystem
	var buff_system = _get_buff_system(target)
	if not buff_system:
		return false
	
	# 应用燃烧Buff
	buff_system.add_buff("burn", duration, {
		"dps": damage / tick_interval,  # 转换为每秒伤害
		"tick_interval": tick_interval,
		"damage": damage
	}, tick_interval)
	
	# 显示效果名称浮动文字
	if FloatingText:
		FloatingText.create_floating_text(
			target.global_position + Vector2(0, -50),
			"燃烧",
			Color(1.0, 0.5, 0.0),  # 橙色
			false
		)
	
	print("[SpecialEffects] 燃烧效果触发！伤害: %.1f/%.1fs, 持续: %.1fs" % [damage, tick_interval, duration])
	return true

## 应用流血效果
static func _apply_bleed(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var chance = params.get("chance", 0.0)
	var tick_interval = params.get("tick_interval", 1.0)
	var damage = params.get("damage", 0.0)
	var duration = params.get("duration", 5.0)
	
	# 应用异常概率加成
	chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 应用异常持续时间系数
	duration *= attacker_stats.status_duration_mult
	
	# 应用异常效果加成
	damage *= attacker_stats.status_effect_mult
	
	# 检查目标是否有BuffSystem
	var buff_system = _get_buff_system(target)
	if not buff_system:
		return false
	
	# 应用流血Buff
	buff_system.add_buff("bleed", duration, {
		"dps": damage / tick_interval,
		"tick_interval": tick_interval,
		"damage": damage
	}, tick_interval, true)  # 允许堆叠
	
	# 显示效果名称浮动文字
	if FloatingText:
		FloatingText.create_floating_text(
			target.global_position + Vector2(0, -50),
			"流血",
			Color(1.0, 0.0, 0.0),  # 红色
			false
		)
	
	print("[SpecialEffects] 流血效果触发！目标: %s, 伤害: %.1f/%.1fs, 持续: %.1fs" % [target.name if target.has_method("get") and "name" in target else "未知", damage, tick_interval, duration])
	return true

## 应用冰冻效果
static func _apply_freeze(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var chance = params.get("chance", 0.0)
	var duration = params.get("duration", 2.0)
	
	# 应用异常概率加成
	chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 应用异常持续时间系数
	duration *= attacker_stats.status_duration_mult
	
	# 检查目标是否有BuffSystem
	var buff_system = _get_buff_system(target)
	if not buff_system:
		return false
	
	# 应用冰冻Buff（无法移动）
	buff_system.add_buff("freeze", duration, {
		"can_move": false
	})
	
	# 显示效果名称浮动文字
	if FloatingText:
		FloatingText.create_floating_text(
			target.global_position + Vector2(0, -50),
			"冰冻",
			Color(0.3, 0.8, 1.0),  # 蓝色
			false
		)
	
	print("[SpecialEffects] 冰冻效果触发！目标: %s, 持续: %.1fs" % [target.name if target.has_method("get") and "name" in target else "未知", duration])
	return true

## 应用减速效果
static func _apply_slow(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var chance = params.get("chance", 0.0)
	var duration = params.get("duration", 3.0)
	var slow_percent = params.get("slow_percent", 0.5)  # 默认减速50%
	
	# 应用异常概率加成
	chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 应用异常持续时间系数
	duration *= attacker_stats.status_duration_mult
	
	# 应用异常效果加成（影响减速效果）
	slow_percent *= attacker_stats.status_effect_mult
	slow_percent = clamp(slow_percent, 0.0, 1.0)  # 限制在0-100%之间
	
	# 检查目标是否有BuffSystem
	var buff_system = _get_buff_system(target)
	if not buff_system:
		return false
	
	# 应用减速Buff
	buff_system.add_buff("slow", duration, {
		"slow_multiplier": 1.0 - slow_percent  # 移动速度倍数
	})
	
	# 显示效果名称浮动文字
	if FloatingText:
		FloatingText.create_floating_text(
			target.global_position + Vector2(0, -50),
			"减速",
			Color(0.3, 0.6, 1.0, 0.8),  # 半透明蓝色
			false
		)
	
	print("[SpecialEffects] 减速效果触发！减速: %.1f%%, 持续: %.1fs" % [slow_percent * 100, duration])
	return true

## 应用中毒效果
static func _apply_poison(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var chance = params.get("chance", 0.0)
	var tick_interval = params.get("tick_interval", 1.0)
	var damage = params.get("damage", 5.0)
	var duration = params.get("duration", 5.0)
	
	# 应用异常概率加成
	chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 应用异常持续时间系数
	duration *= attacker_stats.status_duration_mult
	
	# 应用异常效果加成
	damage *= attacker_stats.status_effect_mult
	
	# 检查目标是否有BuffSystem
	var buff_system = _get_buff_system(target)
	if not buff_system:
		return false
	
	# 应用中毒Buff（可堆叠）
	buff_system.add_buff("poison", duration, {
		"dps": damage / tick_interval,
		"tick_interval": tick_interval,
		"damage": damage
	}, tick_interval, true)  # 允许堆叠
	
	# 显示效果名称浮动文字
	if FloatingText:
		FloatingText.create_floating_text(
			target.global_position + Vector2(0, -50),
			"中毒",
			Color(0.5, 1.0, 0.0),  # 绿色
			false
		)
	
	print("[SpecialEffects] 中毒效果触发！伤害: %.1f/%.1fs, 持续: %.1fs" % [damage, tick_interval, duration])
	return true

## 应用吸血效果
static func _apply_lifesteal(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var damage_dealt = params.get("damage_dealt", 0)
	var lifesteal_percent = params.get("percent", attacker_stats.lifesteal_percent if attacker_stats else 0.0)
	var chance = params.get("chance", 1.0)  # 默认100%触发
	
	if damage_dealt <= 0:
		return false
	
	if lifesteal_percent <= 0:
		return false
	
	# 应用异常概率加成
	if attacker_stats:
		chance *= attacker_stats.status_chance_mult
	
	# 概率判定
	if chance <= 0 or not _roll_chance(chance):
		return false
	
	# 获取攻击者（通常是玩家）
	var attacker = params.get("attacker", null)
	if not attacker:
		return false
	
	# 应用异常效果加成（影响吸血百分比）
	if attacker_stats:
		lifesteal_percent *= attacker_stats.status_effect_mult
	
	# 计算吸血量
	var heal_amount = int(damage_dealt * lifesteal_percent)
	# 确保至少恢复1点HP
	if heal_amount < 1:
		heal_amount = 1
	
	# 恢复生命值
	if not "now_hp" in attacker or not "max_hp" in attacker:
		return false
	
	var old_hp = attacker.now_hp
	attacker.now_hp = min(attacker.now_hp + heal_amount, attacker.max_hp)
	var actual_heal = attacker.now_hp - old_hp
	
	# 发送血量变化信号
	if attacker.has_signal("hp_changed"):
		attacker.hp_changed.emit(attacker.now_hp, attacker.max_hp)
	
	if actual_heal > 0:
		# 显示吸血跳字
		if FloatingText:
			FloatingText.create_floating_text(
				attacker.global_position + Vector2(0, -40),
				"+%d" % actual_heal,
				Color(0.0, 1.0, 0.0)  # 绿色
			)
		
		print("[SpecialEffects] 吸血效果触发！恢复: +%d HP (伤害: %d, 比例: %.1f%%)" % [actual_heal, damage_dealt, lifesteal_percent * 100])
	
	return true

## 应用治愈效果
static func _apply_heal(attacker_stats: CombatStats, target, params: Dictionary) -> bool:
	var heal_amount = params.get("amount", 0.0)
	var heal_percent = params.get("percent", 0.0)
	
	# 应用异常效果加成
	if heal_amount > 0:
		heal_amount *= attacker_stats.status_effect_mult
	elif heal_percent > 0:
		heal_percent *= attacker_stats.status_effect_mult
	
	# 检查目标是否有生命值属性
	if not "now_hp" in target or not "max_hp" in target:
		return false
	
	# 计算治愈量
	var actual_heal = 0
	if heal_amount > 0:
		actual_heal = int(heal_amount)
	elif heal_percent > 0:
		actual_heal = int(target.max_hp * heal_percent)
	
	if actual_heal <= 0:
		return false
	
	# 恢复生命值
	var old_hp = target.now_hp
	target.now_hp = min(target.now_hp + actual_heal, target.max_hp)
	actual_heal = target.now_hp - old_hp
	
	# 发送血量变化信号
	if target.has_signal("hp_changed"):
		target.hp_changed.emit(target.now_hp, target.max_hp)
	
	if actual_heal > 0:
		print("[SpecialEffects] 治愈: +%d HP" % actual_heal)
		
		# 显示治愈跳字
		if FloatingText:
			FloatingText.create_floating_text(
				target.global_position + Vector2(0, -40),
				"+%d" % actual_heal,
				Color(0.0, 1.0, 0.5)  # 青绿色
			)
	
	return true

## 获取目标的BuffSystem
static func _get_buff_system(target) -> Node:
	if not target:
		return null
	
	var buff_system = null
	if target.has_node("BuffSystem"):
		buff_system = target.get_node("BuffSystem")
	elif "buff_system" in target:
		buff_system = target.buff_system
	
	return buff_system

## 概率判定
static func _roll_chance(chance: float) -> bool:
	if chance <= 0:
		return false
	if chance >= 1.0:
		return true
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randf() <= chance

## 处理Buff Tick伤害（用于燃烧、流血、中毒等DoT效果）
## 
## 应该在监听BuffSystem.buff_tick信号的函数中调用
## 
## @param target 受伤的目标
## @param tick_data Buff tick数据
static func apply_dot_damage(target, tick_data: Dictionary) -> void:
	if not target:
		return
	
	if not tick_data.has("effects"):
		return
	
	var effects = tick_data["effects"]
	var stacks = tick_data.get("stacks", 1)
	var buff_id = tick_data.get("buff_id", "unknown")
	
	# 检查是否有DPS数据
	if not effects.has("dps"):
		return
	
	var dps = effects["dps"]
	var damage = int(dps * stacks)  # 堆叠层数影响伤害
	
	if damage <= 0:
		return
	
	# 根据buff_id确定DoT伤害颜色（与效果名称颜色一致）
	var dot_color = Color(1.0, 0.0, 0.0)  # 默认红色
	match buff_id:
		"burn":
			dot_color = Color(1.0, 0.5, 0.0)  # 橙色（与"燃烧"一致）
		"bleed":
			dot_color = Color(1.0, 0.0, 0.0)  # 红色（与"流血"一致）
		"poison":
			dot_color = Color(0.5, 1.0, 0.0)  # 绿色（与"中毒"一致）
	
	# 对目标造成伤害（DoT伤害颜色与效果名称一致）
	if target.has_method("enemy_hurt"):
		# 直接减少HP，不调用enemy_hurt（避免重复显示伤害数字和flash效果）
		if "enemyHP" in target and not target.is_dead:
			# 检查无敌状态
			if target.is_invincible:
				return
			
			target.enemyHP -= damage
			
			# 显示DoT伤害数字（颜色与效果名称一致）
			if FloatingText:
				FloatingText.create_floating_text(
					target.global_position + Vector2(randf_range(-20, 20), -30),
					"-" + str(damage),
					dot_color,
					false
				)
			
			# 检查死亡
			if target.enemyHP <= 0:
				target.enemyHP = 0
				if not target.is_dead:
					target.enemy_dead()
	elif target.has_method("player_hurt"):
		# 玩家DoT伤害
		if "now_hp" in target:
			target.now_hp -= damage
			if target.now_hp < 0:
				target.now_hp = 0
		
		# 显示DoT伤害数字（颜色与效果名称一致）
		if FloatingText:
			FloatingText.create_floating_text(
				target.global_position + Vector2(randf_range(-20, 20), -30),
				"-" + str(damage),
				dot_color,
				false
			)
	
	print("[SpecialEffects] DoT伤害: %s - %d (层数: %d)" % [buff_id, damage, stacks])

## 应用吸血效果（兼容性方法）
## 
## 保留此方法以兼容旧代码
## 新代码应使用 try_apply_status_effect() 方法
static func apply_lifesteal(attacker, damage_dealt: int, lifesteal_percent: float) -> void:
	if not attacker:
		return
	
	# 创建临时CombatStats用于传递参数
	var temp_stats = CombatStats.new()
	temp_stats.lifesteal_percent = lifesteal_percent
	temp_stats.status_effect_mult = 1.0  # 默认值
	temp_stats.status_chance_mult = 1.0  # 默认值
	temp_stats.status_duration_mult = 1.0  # 默认值
	
	try_apply_status_effect(temp_stats, null, "lifesteal", {
		"attacker": attacker,
		"damage_dealt": damage_dealt,
		"percent": lifesteal_percent
	})
