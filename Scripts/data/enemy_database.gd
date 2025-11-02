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
		"基础敌人",
		40,  # max_hp
		5,  # attack_damage
		300.0,  # move_speed
		"res://assets/enemy/enemy-green-sheet.png",
		357,  # frame_width
		240,  # frame_height
		5     # frame_count（根据你的实际帧数修改）
	)
	basic_enemy.description = "标准敌人，平衡的属性"
	basic_enemy.animation_speed = 8.0  # 8 FPS
	enemies["basic"] = basic_enemy
	
	# 快速敌人 - 低血量，高速度
	var fast_enemy = EnemyData.new(
		"快速敌人",
		30,  # max_hp
		3,  # attack_damage
		500.0,  # move_speed（更快）
		"res://assets/enemy/enemy-puerple-sheet.png",
		357,
		240,
		5
	)
	fast_enemy.description = "快速但脆弱的敌人"
	fast_enemy.animation_speed = 12.0  # 更快的动画
	enemies["fast"] = fast_enemy
	
	# 坦克敌人 - 高血量，低速度
	var tank_enemy = EnemyData.new(
		"坦克敌人",
		150,  # max_hp（更高）
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
		100,  # max_hp
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
		80,  # max_hp
		8,  # attack_damage
		320.0,  # move_speed
		"res://assets/enemy/boss01-sheet.png",  # 特殊外观
		360,  # frame_width（根据boss的实际尺寸修改）
		240,  # frame_height
		4     # frame_count（根据boss的实际帧数修改）
	)
	last_enemy.description = "每波最后的首领，掉落Master Key"
	last_enemy.shake_amount = 15.0  # 强震动
	last_enemy.scale = Vector2(1.2, 1.2)  # 1.2倍大小
	last_enemy.animation_speed = 8.0
	enemies["last_enemy"] = last_enemy

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
