extends Resource
class_name AttributeModifier

## 属性修改器
## 
## 职责：表示单个属性变化来源（职业、升级、技能、Buff等）
## 
## 使用场景：
##   - 职业基础属性（BASE，永久）
##   - 购买升级获得的加成（UPGRADE，永久）
##   - 技能激活的临时加成（SKILL，有持续时间）
##   - Buff效果（BUFF，有持续时间）
## 
## 使用示例：
##   var modifier = AttributeModifier.new()
##   modifier.modifier_type = AttributeModifier.ModifierType.UPGRADE
##   modifier.stats_delta = CombatStats.new()
##   modifier.stats_delta.melee_damage_mult = 0.1  # +10%近战伤害
##   player.attribute_manager.add_permanent_modifier(modifier)

## 修改器类型枚举
enum ModifierType {
	BASE,      ## 基础值（职业固有属性）
	UPGRADE,   ## 升级加成（永久）
	SKILL,     ## 技能效果（临时）
	BUFF       ## Buff效果（临时）
}

## 修改器类型
@export var modifier_type: ModifierType = ModifierType.UPGRADE

## 持续时间（秒）
## -1 表示永久，>0 表示临时效果的剩余时间
@export var duration: float = -1.0

## 属性变化量
## 存储这个修改器会应用的所有属性变化
@export var stats_delta: CombatStats = null

## 修改器的唯一标识（可选）
## 用于追踪和移除特定的修改器
@export var modifier_id: String = ""

## 初始化时的持续时间（用于重置）
var initial_duration: float = -1.0

func _init():
	stats_delta = CombatStats.new()
	
	# ⭐ 清零默认值，避免意外累加
	# 虽然大多数情况下会被立即覆盖，但为了安全起见还是清零
	stats_delta.max_hp = 0
	stats_delta.speed = 0.0
	stats_delta.crit_damage = 0.0

## 应用修改器到目标属性
## 
## 将 stats_delta 中的所有非零值累加到 target_stats
## 
## @param target_stats 目标属性对象
func apply_to(target_stats: CombatStats) -> void:
	if not stats_delta or not target_stats:
		return
	
	# 基础属性
	target_stats.max_hp += stats_delta.max_hp
	target_stats.speed += stats_delta.speed
	target_stats.defense += stats_delta.defense
	target_stats.luck += stats_delta.luck
	
	# 通用战斗属性
	target_stats.crit_chance += stats_delta.crit_chance
	target_stats.crit_damage += stats_delta.crit_damage
	target_stats.damage_reduction += stats_delta.damage_reduction
	
	# 全局武器属性
	target_stats.global_damage_add += stats_delta.global_damage_add
	target_stats.global_damage_mult *= stats_delta.global_damage_mult
	target_stats.global_attack_speed_add += stats_delta.global_attack_speed_add
	target_stats.global_attack_speed_mult *= stats_delta.global_attack_speed_mult
	
	# 近战武器属性
	target_stats.melee_damage_add += stats_delta.melee_damage_add
	target_stats.melee_damage_mult *= stats_delta.melee_damage_mult
	target_stats.melee_speed_add += stats_delta.melee_speed_add
	target_stats.melee_speed_mult *= stats_delta.melee_speed_mult
	target_stats.melee_range_add += stats_delta.melee_range_add
	target_stats.melee_range_mult *= stats_delta.melee_range_mult
	target_stats.melee_knockback_add += stats_delta.melee_knockback_add
	target_stats.melee_knockback_mult *= stats_delta.melee_knockback_mult
	
	# 远程武器属性
	target_stats.ranged_damage_add += stats_delta.ranged_damage_add
	target_stats.ranged_damage_mult *= stats_delta.ranged_damage_mult
	target_stats.ranged_speed_add += stats_delta.ranged_speed_add
	target_stats.ranged_speed_mult *= stats_delta.ranged_speed_mult
	target_stats.ranged_range_add += stats_delta.ranged_range_add
	target_stats.ranged_range_mult *= stats_delta.ranged_range_mult
	target_stats.ranged_penetration += stats_delta.ranged_penetration
	target_stats.ranged_projectile_count += stats_delta.ranged_projectile_count
	
	# 魔法武器属性
	target_stats.magic_damage_add += stats_delta.magic_damage_add
	target_stats.magic_damage_mult *= stats_delta.magic_damage_mult
	target_stats.magic_speed_add += stats_delta.magic_speed_add
	target_stats.magic_speed_mult *= stats_delta.magic_speed_mult
	target_stats.magic_range_add += stats_delta.magic_range_add
	target_stats.magic_range_mult *= stats_delta.magic_range_mult
	target_stats.magic_explosion_radius_add += stats_delta.magic_explosion_radius_add
	target_stats.magic_explosion_radius_mult *= stats_delta.magic_explosion_radius_mult
	
	# 特殊效果属性
	target_stats.lifesteal_percent += stats_delta.lifesteal_percent
	target_stats.burn_chance += stats_delta.burn_chance
	target_stats.burn_damage_per_second += stats_delta.burn_damage_per_second
	target_stats.freeze_chance += stats_delta.freeze_chance
	target_stats.poison_chance += stats_delta.poison_chance

## 检查修改器是否已过期
## 
## @return 如果是临时效果且已过期返回true，永久效果返回false
func is_expired() -> bool:
	# 如果初始设定为永久（initial_duration <= 0），则永不过期
	# 注意：不能只检查 duration < 0，因为倒计时结束时 duration 也会变成负数
	if initial_duration <= 0:
		return false
	
	# 临时效果检查剩余时间
	return duration <= 0.0

## 更新持续时间
## 
## @param delta 时间增量（秒）
func update(delta: float) -> void:
	if duration > 0:
		duration -= delta

## 重置持续时间（用于可重复使用的修改器）
func reset_duration() -> void:
	if initial_duration > 0:
		duration = initial_duration

