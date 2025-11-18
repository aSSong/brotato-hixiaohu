extends Node
class_name UpgradeDatabaseHelper

## 升级数据库辅助类
## 提供创建stats_modifier的辅助方法

## 创建一个干净的CombatStats实例（所有加法属性清零）
static func create_clean_stats() -> CombatStats:
	var stats = CombatStats.new()
	# 清零所有加法属性的默认值
	stats.max_hp = 0
	stats.speed = 0.0
	stats.defense = 0
	stats.luck = 0.0
	stats.crit_chance = 0.0
	stats.crit_damage = 0.0  # 默认1.5也要清零
	stats.damage_reduction = 0.0
	# 乘法属性保持默认值1.0（正确行为）
	return stats

## 创建攻击速度升级的stats_modifier
static func create_attack_speed_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.global_attack_speed_mult = multiplier
	return stats

## 创建HP上限升级的stats_modifier
static func create_max_hp_stats(hp_add: int) -> CombatStats:
	var stats = create_clean_stats()
	stats.max_hp = hp_add
	return stats

## 创建移动速度升级的stats_modifier
static func create_move_speed_stats(speed_add: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.speed = speed_add
	return stats

## 创建减伤升级的stats_modifier
static func create_damage_reduction_stats(reduction: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.damage_reduction = reduction
	return stats

## 创建近战伤害升级的stats_modifier
static func create_melee_damage_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.melee_damage_mult = multiplier
	return stats

## 创建远程伤害升级的stats_modifier
static func create_ranged_damage_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.ranged_damage_mult = multiplier
	return stats

## 创建魔法伤害升级的stats_modifier
static func create_magic_damage_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.magic_damage_mult = multiplier
	return stats

## 创建近战速度升级的stats_modifier
static func create_melee_speed_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.melee_speed_mult = multiplier
	return stats

## 创建远程速度升级的stats_modifier
static func create_ranged_speed_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.ranged_speed_mult = multiplier
	return stats

## 创建魔法速度升级的stats_modifier
static func create_magic_speed_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.magic_speed_mult = multiplier
	return stats

## 创建近战范围升级的stats_modifier
static func create_melee_range_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.melee_range_mult = multiplier
	return stats

## 创建远程范围升级的stats_modifier
static func create_ranged_range_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.ranged_range_mult = multiplier
	return stats

## 创建魔法范围升级的stats_modifier
static func create_magic_range_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.magic_range_mult = multiplier
	return stats

## 创建近战击退升级的stats_modifier
static func create_melee_knockback_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.melee_knockback_mult = multiplier
	return stats

## 创建魔法爆炸范围升级的stats_modifier
static func create_magic_explosion_stats(multiplier: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.magic_explosion_radius_mult = multiplier
	return stats

## 创建幸运升级的stats_modifier
static func create_luck_stats(luck_add: float) -> CombatStats:
	var stats = create_clean_stats()
	stats.luck = luck_add
	return stats
