extends Node
class_name ClassDatabase

## 职业数据库
## 预定义多个职业及其属性和技能

static var classes: Dictionary = {}

## 初始化所有职业
static func initialize_classes() -> void:
	if not classes.is_empty():
		return
	
	# 战士 - 高血量、近战加成
	var warrior = ClassData.new(
		"战士",
		150,  # max_hp
		350.0,  # speed (稍慢)
		1.2,  # attack_multiplier
		5,  # defense
		0.1,  # crit_chance
		2.0,  # crit_damage
		"狂暴",  # skill_name
		{
			"cooldown": 10.0,
			"duration": 5.0,
			"attack_speed_boost": 0.5,  # 攻击速度+50%
			"damage_boost": 1.3  # 伤害+30%
		}
	)
	warrior.description = "高血量的近战职业，擅长使用近战武器"
	warrior.traits = ["近战武器伤害+30%", "血量+50", "防御+5"]
	classes["warrior"] = warrior
	
	# 射手 - 高攻击速度、远程加成
	var ranger = ClassData.new(
		"射手",
		80,  # max_hp
		450.0,  # speed (较快)
		1.0,  # attack_multiplier
		0,  # defense
		0.2,  # crit_chance (高暴击)
		2.5,  # crit_damage
		"精准射击",  # skill_name
		{
			"cooldown": 8.0,
			"duration": 4.0,
			"crit_chance_boost": 0.5,  # 暴击率+50%
			"all_projectiles_crit": true  # 所有子弹必定暴击
		}
	)
	ranger.description = "高敏捷的远程职业，擅长使用远程武器"
	ranger.traits = ["远程武器伤害+25%", "攻击速度+20%", "暴击率+10%"]
	classes["ranger"] = ranger
	
	# 法师 - 低血量、魔法加成、范围伤害
	var mage = ClassData.new(
		"法师",
		60,  # max_hp (低血量)
		400.0,  # speed
		0.9,  # attack_multiplier (基础攻击稍低)
		0,  # defense
		0.15,  # crit_chance
		2.0,  # crit_damage
		"魔法爆发",  # skill_name
		{
			"cooldown": 12.0,
			"explosion_radius_multiplier": 2.0,  # 爆炸范围x2
			"damage_multiplier": 1.5,  # 伤害+50%
			"all_enemies_in_range": true  # 范围内所有敌人
		}
	)
	mage.description = "高智力的魔法职业，擅长使用魔法武器造成范围伤害"
	mage.traits = ["魔法武器伤害+40%", "爆炸范围+30%", "魔法冷却-20%"]
	classes["mage"] = mage
	
	# 平衡者 - 均衡属性
	var balanced = ClassData.new(
		"平衡者",
		10,  # max_hp
		400.0,  # speed
		1.0,  # attack_multiplier
		2,  # defense
		0.1,  # crit_chance
		1.8,  # crit_damage
		"全面强化",  # skill_name
		{
			"cooldown": 15.0,
			"duration": 6.0,
			"all_stats_boost": 1.2  # 所有属性+20%
		}
	)
	balanced.description = "均衡发展的职业，适合所有武器类型"
	balanced.traits = ["所有武器伤害+15%", "移动速度+10%"]
	classes["balanced"] = balanced
	
	# 坦克 - 超高血量、防御
	var tank = ClassData.new(
		"坦克",
		200,  # max_hp (超高)
		300.0,  # speed (慢)
		0.8,  # attack_multiplier (低攻击)
		10,  # defense (高防御)
		0.05,  # crit_chance
		1.5,  # crit_damage
		"护盾",  # skill_name
		{
			"cooldown": 20.0,
			"duration": 8.0,
			"damage_reduction": 0.5,  # 减伤50%
			"reflect_damage": 0.3  # 反弹30%伤害
		}
	)
	tank.description = "超高血量和防御的职业，生存能力强"
	tank.traits = ["血量+100", "防御+10", "受到伤害-20%"]
	classes["tank"] = tank

## 获取职业（重命名以避免与Node.get_class()冲突）
static func get_class_data(class_id: String) -> ClassData:
	if classes.is_empty():
		initialize_classes()
	return classes.get(class_id, classes["balanced"])

## 获取所有职业ID
static func get_all_class_ids() -> Array:
	if classes.is_empty():
		initialize_classes()
	return classes.keys()
