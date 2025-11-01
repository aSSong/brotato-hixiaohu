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
	var basic_enemy = EnemyData.new(
		"基础敌人",
		50,  # max_hp
		5,  # attack_damage
		300.0,  # move_speed
		"res://assets/enemy/enemy-sheet.png",
		Rect2(0, 0, 240, 240)  # 第一帧
	)
	basic_enemy.description = "标准敌人，平衡的属性"
	enemies["basic"] = basic_enemy
	
	# 快速敌人 - 低血量，高速度
	var fast_enemy = EnemyData.new(
		"快速敌人",
		30,  # max_hp
		3,  # attack_damage
		450.0,  # move_speed（更快）
		"res://assets/enemy/enemy-sheet.png",
		Rect2(240, 0, 240, 240)  # 第二帧
	)
	fast_enemy.description = "快速但脆弱的敌人"
	enemies["fast"] = fast_enemy
	
	# 坦克敌人 - 高血量，低速度
	var tank_enemy = EnemyData.new(
		"坦克敌人",
		150,  # max_hp（更高）
		8,  # attack_damage（更高）
		200.0,  # move_speed（更慢）
		"res://assets/enemy/enemy-sheet.png",
		Rect2(480, 0, 240, 240)  # 第三帧
	)
	tank_enemy.description = "高血量但移动缓慢的敌人"
	enemies["tank"] = tank_enemy
	
	# 精英敌人 - 全属性较高
	var elite_enemy = EnemyData.new(
		"精英敌人",
		100,  # max_hp
		10,  # attack_damage
		350.0,  # move_speed
		"res://assets/enemy/enemy-sheet.png",
		Rect2(720, 0, 240, 240)  # 第四帧
	)
	elite_enemy.description = "强化的精英敌人"
	elite_enemy.shake_amount = 12.0  # 更强的震动
	enemies["elite"] = elite_enemy

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

