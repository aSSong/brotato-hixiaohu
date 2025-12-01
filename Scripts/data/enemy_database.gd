extends Node
class_name EnemyDatabase

## 敌人数据库
## 预定义多种敌人及其属性

static var enemies: Dictionary = {}

## 初始化所有敌人
static func initialize_enemies() -> void:
	if not enemies.is_empty():
		return
	
	# 基础敌人 - 标准属性
	# 假设sheet有5帧，横向排列，每帧240x240
	var basic_enemy = EnemyData.new(
		"基础敌人-爬虫",
		10,  # max_hp
		5,  # attack_damage
		330.0,  # move_speed
		"res://assets/enemy/creeper-run-Sheet.png",
		634,  # frame_width
		500,  # frame_height
		7     # frame_count（根据你的实际帧数修改）
	)
	basic_enemy.description = "标准敌人，平衡的属性"
	basic_enemy.scale = Vector2(0.2, 0.2)  # 1.2倍大小
	basic_enemy.animation_speed = 14.0  # 8 FPS
	# 配置shadow：由于敌人scale是0.5，需要补偿shadow的scale使其可见
	# 场景默认shadow scale是Vector2(1.1, 0.8)，补偿后应该是Vector2(2.2, 1.6)
	basic_enemy.shadow_scale = Vector2(0.6, 0.4)
	basic_enemy.shadow_offset = Vector2(20,-115) # 使用默认位置
	enemies["basic"] = basic_enemy
	
	## 示例1：只设置shadow大小
	#enemy.shadow_scale = Vector2(2.0, 1.5)  # 自定义大小
	#enemy.shadow_offset = Vector2.ZERO  # 使用默认位置
	#
	## 示例2：只设置shadow位置偏移
	#enemy.shadow_scale = Vector2.ZERO  # 使用默认大小
	#enemy.shadow_offset = Vector2(10, 20)  # 相对默认位置偏移(10, 20)
	
		# 订书机
	var stapler_enemy = EnemyData.new(
		"订书机",
		20,  # max_hp
		4,  # attack_damage
		400.0,  # move_speed（更快）
		"res://assets/enemy/stapler-run-Sheet.png",
		664,
		500,
		4
	)
	stapler_enemy.description = "这是一个订书机"
	stapler_enemy.scale = Vector2(0.4, 0.4)  # 0.4倍大小
	stapler_enemy.shadow_offset = Vector2(15.0,-95) 
	stapler_enemy.shadow_scale = Vector2(1.0, 0.5)
	stapler_enemy.animation_speed = 12.0  #  FPS
	enemies["stapler"] = stapler_enemy
	
	var basic00_enemy = EnemyData.new(
		"基础敌人-绿史莱姆",
		10,  # max_hp
		5,  # attack_damage
		300.0,  # move_speed
		"res://assets/enemy/enemy-green-sheet.png",
		357,  # frame_width
		240,  # frame_height
		5     # frame_count（根据你的实际帧数修改）
	)
	basic00_enemy.description = "标准敌人，平衡的属性"
	basic00_enemy.animation_speed = 8.0  # 8 FPS
	enemies["basic00"] = basic00_enemy
	
	# 快速敌人 - 低血量，高速度
	var fast_enemy = EnemyData.new(
		"快速敌人-蚊子",
		8,  # max_hp
		3,  # attack_damage
		500.0,  # move_speed（更快）
		"res://assets/enemy/masquito-run-Sheet.png",
		321,
		500,
		4
	)
	fast_enemy.description = "快速但脆弱的敌人"
	fast_enemy.scale = Vector2(0.4, 0.4)  # 0.4倍大小
	fast_enemy.shadow_offset = Vector2(30,-80) 
	fast_enemy.animation_speed = 8.0  # 8 FPS
	enemies["fast"] = fast_enemy
	
	# 快速敌人 - 低血量，高速度
	var fast00_enemy = EnemyData.new(
		"快速敌人-紫翅膀史莱姆",
		8,  # max_hp
		3,  # attack_damage
		500.0,  # move_speed（更快）
		"res://assets/enemy/enemy-puerple-sheet.png",
		357,
		240,
		5
	)
	fast00_enemy.description = "快速但脆弱的敌人"
	fast00_enemy.animation_speed = 12.0  # 更快的动画
	enemies["fast00"] = fast00_enemy
	
	# 坦克敌人 - 高血量，低速度
	var tank_enemy = EnemyData.new(
		"坦克敌人",
		30,  # max_hp（更高）
		8,  # attack_damage（更高）
		200.0,  # move_speed（更慢）
		"res://assets/enemy/enemy-slow-sheet.png",
		357,
		240,
		5
	)
	tank_enemy.description = "高血量但移动缓慢的敌人"
	tank_enemy.animation_speed = 6.0  # 更慢的动画
	enemies["tank"] = tank_enemy
	
	# 精英敌人 - 全属性较高
	var elite_enemy = EnemyData.new(
		"精英敌人",
		25,  # max_hp
		10,  # attack_damage
		350.0,  # move_speed
		"res://assets/enemy/enemy-red-sheet.png",
		357,
		240,
		5
	)
	elite_enemy.description = "强化的精英敌人"
	elite_enemy.shake_amount = 12.0  # 更强的震动
	elite_enemy.animation_speed = 10.0
	enemies["elite"] = elite_enemy
	
	# 波次Boss敌人 - 每波最后一个，掉落Master Key
	var last_enemy = EnemyData.new(
		"波次首领",
		45,  # max_hp
		8,  # attack_damage
		380.0,  # move_speed
		"res://assets/enemy/boss01-sheet.png",  # 特殊外观
		360,  # frame_width（根据boss的实际尺寸修改）
		240,  # frame_height
		4     # frame_count（根据boss的实际帧数修改）
	)
	last_enemy.description = "每波最后的首领，掉落Master Key"
	last_enemy.shake_amount = 15.0  # 强震动
	last_enemy.scale = Vector2(1.2, 1.2)  # 1.2倍大小
	last_enemy.animation_speed = 8.0
	# 添加冲锋技能
	last_enemy.skill_type = EnemyData.EnemySkillType.CHARGING
	last_enemy.skill_config = {
		"trigger_distance": 600.0,   # 触发距离（更远）
		"charge_speed": 900.0,        # 冲锋速度（更快）
		"charge_distance": 700.0,     # 冲锋距离（更远）
		"cooldown": 2.5,              # 冷却时间（更短）
		"extra_damage": 15,           # 额外伤害（更高）
		"prepare_time": 0.2           # 准备时间（更短）
	}
	enemies["last_enemy"] = last_enemy
	
	# ========== 技能敌人 ==========
	
	# 冲锋敌人 - 带有冲锋技能
	var charging_enemy = EnemyData.new(
		"冲锋敌人",
		20,  # max_hp
		6,   # attack_damage
		350.0,  # move_speed
		"res://assets/enemy/enemy-wings-yellow-sheet.png",
		357,
		240,
		5
	)
	charging_enemy.description = "会冲锋攻击的敌人"
	charging_enemy.skill_type = EnemyData.EnemySkillType.CHARGING
	charging_enemy.skill_config = {
		"trigger_distance": 500.0,   # 触发距离
		"charge_speed": 800.0,        # 冲锋速度
		"charge_distance": 600.0,     # 冲锋距离
		"cooldown": 3.0,              # 冷却时间
		"extra_damage": 10,           # 额外伤害
		"prepare_time": 0.3           # 准备时间
	}
	enemies["charging_enemy"] = charging_enemy
	
	# 射击敌人 - 带有射击技能
	var shooting_enemy = EnemyData.new(
		"射击敌人",
		15,  # max_hp
		4,   # attack_damage
		250.0,  # move_speed（较慢，因为远程）
		"res://assets/enemy/slime-indgo-sheet.png",
		357,
		240,
		5
	)
	shooting_enemy.description = "会远程射击的敌人"
	shooting_enemy.skill_type = EnemyData.EnemySkillType.SHOOTING
	shooting_enemy.skill_config = {
		"shoot_range": 600.0,         # 射击范围
		"shoot_interval": 1.0,        # 射击间隔
		"bullet_speed": 350.0,        # 子弹速度
		"bullet_damage": 5,          # 子弹伤害
		"bullet_id": "basic"          # 子弹ID（从数据库获取）
	}
	enemies["shooting_enemy"] = shooting_enemy
	
	# 自爆敌人 - 带有自爆技能
	var exploding_enemy = EnemyData.new(
		"自爆敌人",
		12,  # max_hp（较低，因为会自爆）
		3,   # attack_damage
		280.0,  # move_speed
		"res://assets/enemy/mashroom-run-Sheet.png",
		425,
		500,
		11
	)
	exploding_enemy.description = "低血量时会自爆的敌人"
	exploding_enemy.scale = Vector2(0.4, 0.4)  # 0.4倍大小
	exploding_enemy.shadow_offset = Vector2(17,-87) 
	exploding_enemy.shadow_scale = Vector2(0.8, 0.6)
	exploding_enemy.animation_speed = 16.0  # FPS
	exploding_enemy.skill_type = EnemyData.EnemySkillType.EXPLODING
	exploding_enemy.skill_config = {
		"trigger_condition": "low_hp",  # 触发条件：低血量
		"explosion_range": 300.0,        # 爆炸范围
		"explosion_damage": 30,          # 爆炸伤害
		"low_hp_threshold": 0.3,        # 低血量阈值（30%）
		"countdown_duration": 3.0        # 倒数时长（秒）
	}
	enemies["exploding_enemy"] = exploding_enemy
	
	
	# 自爆敌人 - 带有自爆技能
	var exploding00_enemy = EnemyData.new(
		"自爆敌人",
		12,  # max_hp（较低，因为会自爆）
		3,   # attack_damage
		280.0,  # move_speed
		"res://assets/enemy/slime-red-sheet.png",
		357,
		240,
		5
	)
	exploding00_enemy.description = "低血量时会自爆的敌人"
	exploding00_enemy.skill_type = EnemyData.EnemySkillType.EXPLODING
	exploding00_enemy.skill_config = {
		"trigger_condition": "low_hp",  # 触发条件：低血量
		"explosion_range": 300.0,        # 爆炸范围
		"explosion_damage": 30,          # 爆炸伤害
		"low_hp_threshold": 0.3,        # 低血量阈值（30%）
		"countdown_duration": 3.0        # 倒数时长（秒）
	}
	enemies["exploding00_enemy"] = exploding00_enemy

## 获取敌人数据
static func get_enemy_data(enemy_id: String) -> EnemyData:
	if enemies.is_empty():
		initialize_enemies()
	return enemies.get(enemy_id, enemies["basic"])

## 获取所有敌人ID
static func get_all_enemy_ids() -> Array:
	if enemies.is_empty():
		initialize_enemies()
	return enemies.keys()
