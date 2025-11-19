extends CombatStats
class_name StatsModifier

## 属性修改器资源
## 
## 专门用于编辑器配置的CombatStats子类
## 自动将所有加法属性默认值设为0，避免编辑器默认值(如max_hp=100)污染属性计算

func _init() -> void:
	# super._init() # 父类没有定义_init，不需要调用
	# 清零所有加法属性
	max_hp = 0
	speed = 0.0
	defense = 0
	luck = 0.0
	
	crit_chance = 0.0
	crit_damage = 0.0
	damage_reduction = 0.0
	
	global_damage_add = 0.0
	global_attack_speed_add = 0.0
	
	melee_damage_add = 0.0
	melee_speed_add = 0.0
	melee_range_add = 0.0
	melee_knockback_add = 0.0
	
	ranged_damage_add = 0.0
	ranged_speed_add = 0.0
	ranged_range_add = 0.0
	ranged_penetration = 0
	ranged_projectile_count = 0
	
	magic_damage_add = 0.0
	magic_speed_add = 0.0
	magic_range_add = 0.0
	magic_explosion_radius_add = 0.0
	
	lifesteal_percent = 0.0
	burn_chance = 0.0
	burn_damage_per_second = 0.0
	freeze_chance = 0.0
	poison_chance = 0.0
	
	# 乘法属性保持默认值 1.0

