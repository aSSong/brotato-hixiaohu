extends Resource
class_name CombatStats

## 战斗属性统一容器
## 
## 职责：存储所有战斗相关的属性值
## 使用分层加成系统：同类型属性先累加(add)，然后所有乘法(mult)相乘
## 
## 设计原则：
##   - 所有属性使用类型化字段，确保类型安全
##   - add属性表示加法层，mult属性表示乘法层
##   - 所有属性都有合理的默认值
## 
## 使用示例：
##   var stats = CombatStats.new()
##   stats.max_hp = 100
##   stats.global_damage_mult = 1.5  # +50%伤害
##   var final_damage_mult = stats.get_final_damage_multiplier(WeaponData.WeaponType.MELEE)

# ========== 基础属性 ==========
@export var max_hp: int = 100  ## 最大生命值
@export var speed: float = 400.0  ## 移动速度
@export var defense: int = 0  ## 防御力（固定减伤）
@export var luck: float = 0.0  ## 幸运值（影响掉落和品质）

# ========== 通用战斗属性 ==========
@export var crit_chance: float = 0.0  ## 暴击率（0-1）
@export var crit_damage: float = 1.5  ## 暴击伤害倍数
@export var damage_reduction: float = 0.0  ## 受伤减免（0-1，如0.2表示减伤20%）

# ========== 全局武器属性 ==========
@export var global_damage_add: float = 0.0  ## 全局伤害加成（加法层）
@export var global_damage_mult: float = 1.0  ## 全局伤害倍数（乘法层）
@export var global_attack_speed_add: float = 0.0  ## 全局攻速加成（加法层）
@export var global_attack_speed_mult: float = 1.0  ## 全局攻速倍数（乘法层）

# ========== 近战武器属性 ==========
@export var melee_damage_add: float = 0.0  ## 近战伤害加成（加法层）
@export var melee_damage_mult: float = 1.0  ## 近战伤害倍数（乘法层）
@export var melee_speed_add: float = 0.0  ## 近战攻速加成（加法层）
@export var melee_speed_mult: float = 1.0  ## 近战攻速倍数（乘法层）
@export var melee_range_add: float = 0.0  ## 近战范围加成（加法层）
@export var melee_range_mult: float = 1.0  ## 近战范围倍数（乘法层）
@export var melee_knockback_add: float = 0.0  ## 近战击退加成（加法层）
@export var melee_knockback_mult: float = 1.0  ## 近战击退倍数（乘法层）

# ========== 远程武器属性 ==========
@export var ranged_damage_add: float = 0.0  ## 远程伤害加成（加法层）
@export var ranged_damage_mult: float = 1.0  ## 远程伤害倍数（乘法层）
@export var ranged_speed_add: float = 0.0  ## 远程攻速加成（加法层）
@export var ranged_speed_mult: float = 1.0  ## 远程攻速倍数（乘法层）
@export var ranged_range_add: float = 0.0  ## 远程范围加成（加法层）
@export var ranged_range_mult: float = 1.0  ## 远程范围倍数（乘法层）
@export var ranged_penetration: int = 0  ## 穿透力（可穿透的敌人数量）
@export var ranged_projectile_count: int = 0  ## 额外弹药数

# ========== 魔法武器属性 ==========
@export var magic_damage_add: float = 0.0  ## 魔法伤害加成（加法层）
@export var magic_damage_mult: float = 1.0  ## 魔法伤害倍数（乘法层）
@export var magic_speed_add: float = 0.0  ## 魔法攻速加成（加法层）
@export var magic_speed_mult: float = 1.0  ## 魔法攻速倍数（乘法层）
@export var magic_range_add: float = 0.0  ## 魔法范围加成（加法层）
@export var magic_range_mult: float = 1.0  ## 魔法范围倍数（乘法层）
@export var magic_explosion_radius_add: float = 0.0  ## 魔法爆炸范围加成（加法层）
@export var magic_explosion_radius_mult: float = 1.0  ## 魔法爆炸范围倍数（乘法层）

# ========== 特殊效果属性（被动） ==========
@export var lifesteal_percent: float = 0.0  ## 吸血百分比（0-1）
@export var burn_chance: float = 0.0  ## 燃烧触发概率（0-1）
@export var burn_damage_per_second: float = 0.0  ## 燃烧每秒伤害
@export var freeze_chance: float = 0.0  ## 冰冻触发概率（0-1）
@export var poison_chance: float = 0.0  ## 中毒触发概率（0-1）

# ========== 异常效果系数 ==========
@export var status_duration_mult: float = 1.0  ## 异常持续时间系数（影响所有异常状态的持续时间）
@export var status_effect_mult: float = 1.0  ## 异常效果加成系数（影响异常状态的伤害/效果强度）
@export var status_chance_mult: float = 1.0  ## 异常概率加成系数（影响异常状态的触发概率）

func _init() -> void:
	pass

## 获取指定武器类型的最终伤害倍数
## 
## 计算公式：(1 + global_add + type_add) × global_mult × type_mult
## 
## @param weapon_type 武器类型枚举
## @return 最终伤害倍数
func get_final_damage_multiplier(weapon_type: int) -> float:
	# 全局加法层
	var total_add = global_damage_add
	# 全局乘法层
	var total_mult = global_damage_mult
	
	# 根据武器类型添加特定加成
	match weapon_type:
		0:  # WeaponData.WeaponType.RANGED
			total_add += ranged_damage_add
			total_mult *= ranged_damage_mult
		1:  # WeaponData.WeaponType.MELEE
			total_add += melee_damage_add
			total_mult *= melee_damage_mult
		2:  # WeaponData.WeaponType.MAGIC
			total_add += magic_damage_add
			total_mult *= magic_damage_mult
	
	# 应用分层计算：先加法，后乘法
	return (1.0 + total_add) * total_mult

## 获取指定武器类型的最终攻速倍数
## 
## @param weapon_type 武器类型枚举
## @return 最终攻速倍数
func get_final_attack_speed_multiplier(weapon_type: int) -> float:
	var total_add = global_attack_speed_add
	var total_mult = global_attack_speed_mult
	
	match weapon_type:
		0:  # RANGED
			total_add += ranged_speed_add
			total_mult *= ranged_speed_mult
		1:  # MELEE
			total_add += melee_speed_add
			total_mult *= melee_speed_mult
		2:  # MAGIC
			total_add += magic_speed_add
			total_mult *= magic_speed_mult
	
	return (1.0 + total_add) * total_mult

## 获取指定武器类型的最终范围倍数
## 
## @param weapon_type 武器类型枚举
## @return 最终范围倍数
func get_final_range_multiplier(weapon_type: int) -> float:
	var total_add = 0.0
	var total_mult = 1.0
	
	match weapon_type:
		0:  # RANGED
			total_add += ranged_range_add
			total_mult *= ranged_range_mult
		1:  # MELEE
			total_add += melee_range_add
			total_mult *= melee_range_mult
		2:  # MAGIC
			total_add += magic_range_add
			total_mult *= magic_range_mult
	
	return (1.0 + total_add) * total_mult

## 获取近战击退的最终倍数
## 
## @return 最终击退倍数
func get_final_knockback_multiplier() -> float:
	return (1.0 + melee_knockback_add) * melee_knockback_mult

## 获取魔法爆炸范围的最终倍数
## 
## @return 最终爆炸范围倍数
func get_final_explosion_radius_multiplier() -> float:
	return (1.0 + magic_explosion_radius_add) * magic_explosion_radius_mult

## 克隆当前属性
## 
## 创建一个完全独立的副本，所有字段值都被复制
## 
## @return 新的CombatStats实例
func clone() -> CombatStats:
	var result = CombatStats.new()
	
	# 基础属性
	result.max_hp = max_hp
	result.speed = speed
	result.defense = defense
	result.luck = luck
	
	# 通用战斗属性
	result.crit_chance = crit_chance
	result.crit_damage = crit_damage
	result.damage_reduction = damage_reduction
	
	# 全局武器属性
	result.global_damage_add = global_damage_add
	result.global_damage_mult = global_damage_mult
	result.global_attack_speed_add = global_attack_speed_add
	result.global_attack_speed_mult = global_attack_speed_mult
	
	# 近战武器属性
	result.melee_damage_add = melee_damage_add
	result.melee_damage_mult = melee_damage_mult
	result.melee_speed_add = melee_speed_add
	result.melee_speed_mult = melee_speed_mult
	result.melee_range_add = melee_range_add
	result.melee_range_mult = melee_range_mult
	result.melee_knockback_add = melee_knockback_add
	result.melee_knockback_mult = melee_knockback_mult
	
	# 远程武器属性
	result.ranged_damage_add = ranged_damage_add
	result.ranged_damage_mult = ranged_damage_mult
	result.ranged_speed_add = ranged_speed_add
	result.ranged_speed_mult = ranged_speed_mult
	result.ranged_range_add = ranged_range_add
	result.ranged_range_mult = ranged_range_mult
	result.ranged_penetration = ranged_penetration
	result.ranged_projectile_count = ranged_projectile_count
	
	# 魔法武器属性
	result.magic_damage_add = magic_damage_add
	result.magic_damage_mult = magic_damage_mult
	result.magic_speed_add = magic_speed_add
	result.magic_speed_mult = magic_speed_mult
	result.magic_range_add = magic_range_add
	result.magic_range_mult = magic_range_mult
	result.magic_explosion_radius_add = magic_explosion_radius_add
	result.magic_explosion_radius_mult = magic_explosion_radius_mult
	
	# 特殊效果属性
	result.lifesteal_percent = lifesteal_percent
	result.burn_chance = burn_chance
	result.burn_damage_per_second = burn_damage_per_second
	result.freeze_chance = freeze_chance
	result.poison_chance = poison_chance
	
	# 异常效果系数
	result.status_duration_mult = status_duration_mult
	result.status_effect_mult = status_effect_mult
	result.status_chance_mult = status_chance_mult
	
	return result

## 调试输出：打印所有非默认值的属性
## 
## 用于调试和检查属性值
func debug_print() -> void:
	print("=== CombatStats Debug ===")
	if max_hp != 100: print("  max_hp: ", max_hp)
	if speed != 400.0: print("  speed: ", speed)
	if defense != 0: print("  defense: ", defense)
	if luck != 0.0: print("  luck: ", luck)
	
	if crit_chance != 0.0: print("  crit_chance: ", crit_chance)
	if crit_damage != 1.5: print("  crit_damage: ", crit_damage)
	if damage_reduction != 0.0: print("  damage_reduction: ", damage_reduction)
	
	if global_damage_add != 0.0: print("  global_damage_add: ", global_damage_add)
	if global_damage_mult != 1.0: print("  global_damage_mult: ", global_damage_mult)
	if global_attack_speed_add != 0.0: print("  global_attack_speed_add: ", global_attack_speed_add)
	if global_attack_speed_mult != 1.0: print("  global_attack_speed_mult: ", global_attack_speed_mult)
	
	print("========================")

