extends Node
class_name SpecialEffects

## 特殊效果处理器
## 
## 职责：处理燃烧、冰冻、吸血等特殊战斗效果
## 
## 所有方法都是静态方法，可以直接调用
## 
## 使用示例：
##   if SpecialEffects.try_apply_burn(player_stats, enemy):
##       print("敌人被点燃了！")
##   SpecialEffects.apply_lifesteal(player, damage, 0.1)

## 尝试应用燃烧效果
## 
## 根据攻击者的burn_chance概率判定是否触发
## 如果触发，在目标身上添加燃烧Buff
## 
## @param attacker_stats 攻击者的战斗属性
## @param target 目标对象（必须有buff_system）
## @return 是否成功应用燃烧
static func try_apply_burn(attacker_stats: CombatStats, target) -> bool:
	if not attacker_stats or not target:
		return false
	
	# 检查是否有燃烧概率
	if attacker_stats.burn_chance <= 0:
		return false
	
	# 概率判定
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > attacker_stats.burn_chance:
		return false
	
	# 检查目标是否有BuffSystem
	if not target.has_node("BuffSystem") and not "buff_system" in target:
		push_warning("[SpecialEffects] 目标没有BuffSystem，无法应用燃烧")
		return false
	
	# 获取BuffSystem
	var buff_system = null
	if target.has_node("BuffSystem"):
		buff_system = target.get_node("BuffSystem")
	elif "buff_system" in target:
		buff_system = target.buff_system
	
	if not buff_system:
		return false
	
	# 应用燃烧Buff
	var burn_duration = 3.0  # 默认3秒
	var burn_dps = attacker_stats.burn_damage_per_second
	
	buff_system.add_buff("burn", burn_duration, {
		"dps": burn_dps,
		"total_damage": burn_dps * burn_duration
	}, 1.0)  # 每秒Tick一次
	
	print("[SpecialEffects] 燃烧效果触发！DPS: %.1f" % burn_dps)
	return true

## 尝试应用冰冻效果
## 
## 根据攻击者的freeze_chance概率判定是否触发
## 
## @param attacker_stats 攻击者的战斗属性
## @param target 目标对象
## @return 是否成功应用冰冻
static func try_apply_freeze(attacker_stats: CombatStats, target) -> bool:
	if not attacker_stats or not target:
		return false
	
	# 检查是否有冰冻概率
	if attacker_stats.freeze_chance <= 0:
		return false
	
	# 概率判定
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > attacker_stats.freeze_chance:
		return false
	
	# 检查目标是否有BuffSystem
	var buff_system = null
	if target.has_node("BuffSystem"):
		buff_system = target.get_node("BuffSystem")
	elif "buff_system" in target:
		buff_system = target.buff_system
	
	if not buff_system:
		push_warning("[SpecialEffects] 目标没有BuffSystem，无法应用冰冻")
		return false
	
	# 应用冰冻Buff（减速效果）
	var freeze_duration = 2.0  # 默认2秒
	
	buff_system.add_buff("freeze", freeze_duration, {
		"slow_multiplier": 0.5  # 减速50%
	})
	
	print("[SpecialEffects] 冰冻效果触发！")
	return true

## 尝试应用中毒效果
## 
## @param attacker_stats 攻击者的战斗属性
## @param target 目标对象
## @return 是否成功应用中毒
static func try_apply_poison(attacker_stats: CombatStats, target) -> bool:
	if not attacker_stats or not target:
		return false
	
	# 检查是否有中毒概率
	if attacker_stats.poison_chance <= 0:
		return false
	
	# 概率判定
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() > attacker_stats.poison_chance:
		return false
	
	# 检查目标是否有BuffSystem
	var buff_system = null
	if target.has_node("BuffSystem"):
		buff_system = target.get_node("BuffSystem")
	elif "buff_system" in target:
		buff_system = target.buff_system
	
	if not buff_system:
		push_warning("[SpecialEffects] 目标没有BuffSystem，无法应用中毒")
		return false
	
	# 应用中毒Buff（可堆叠的DoT）
	var poison_duration = 5.0  # 默认5秒
	var poison_dps = 5.0  # 默认每秒5点伤害
	
	buff_system.add_buff("poison", poison_duration, {
		"dps": poison_dps
	}, 1.0, true)  # 允许堆叠
	
	print("[SpecialEffects] 中毒效果触发！")
	return true

## 应用吸血效果
## 
## 根据造成的伤害和吸血百分比，恢复攻击者的生命值
## 
## @param attacker 攻击者对象（必须有now_hp和max_hp）
## @param damage_dealt 造成的伤害
## @param lifesteal_percent 吸血百分比（0-1）
static func apply_lifesteal(attacker, damage_dealt: int, lifesteal_percent: float) -> void:
	if not attacker or lifesteal_percent <= 0 or damage_dealt <= 0:
		return
	
	# 检查攻击者是否有生命值属性
	if not "now_hp" in attacker or not "max_hp" in attacker:
		push_warning("[SpecialEffects] 攻击者没有生命值属性，无法吸血")
		return
	
	# 计算吸血量
	var heal_amount = int(damage_dealt * lifesteal_percent)
	if heal_amount <= 0:
		return
	
	# 恢复生命值（不超过最大值）
	var old_hp = attacker.now_hp
	attacker.now_hp = min(attacker.now_hp + heal_amount, attacker.max_hp)
	var actual_heal = attacker.now_hp - old_hp
	
	# 发送血量变化信号（如果有）
	if attacker.has_signal("hp_changed"):
		attacker.hp_changed.emit(attacker.now_hp, attacker.max_hp)
	
	if actual_heal > 0:
		print("[SpecialEffects] 吸血: +%d HP" % actual_heal)
		
		# 显示吸血跳字（如果有FloatingText）
		if FloatingText:
			FloatingText.create_floating_text(
				attacker.global_position + Vector2(0, -40),
				"+%d" % actual_heal,
				Color(0.0, 1.0, 0.0)  # 绿色
			)

## 计算燃烧总伤害
## 
## @param burn_dps 每秒伤害
## @param duration 持续时间
## @return 总伤害
static func calculate_burn_damage(burn_dps: float, duration: float) -> float:
	return burn_dps * duration

## 处理Buff Tick伤害（用于燃烧、中毒等DoT效果）
## 
## 应该在监听BuffSystem.buff_tick信号的函数中调用
## 
## @param target 受伤的目标
## @param tick_data Buff tick数据
static func apply_dot_damage(target, tick_data: Dictionary) -> void:
	if not target or not tick_data.has("effects"):
		return
	
	var effects = tick_data["effects"]
	var stacks = tick_data.get("stacks", 1)
	
	# 检查是否有DPS数据
	if not effects.has("dps"):
		return
	
	var dps = effects["dps"]
	var damage = int(dps * stacks)  # 堆叠层数影响伤害
	
	# 对目标造成伤害
	if target.has_method("enemy_hurt"):
		target.enemy_hurt(damage)
	elif target.has_method("player_hurt"):
		target.player_hurt(damage)
	
	print("[SpecialEffects] DoT伤害: %d (层数: %d)" % [damage, stacks])

