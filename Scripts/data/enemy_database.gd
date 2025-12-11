extends Node
class_name EnemyDatabase

## 敌人数据库
## 从资源文件加载敌人数据

static var enemies: Dictionary = {}

## 敌人数据资源目录
const ENEMY_DATA_DIR = "res://resources/enemies/data/"

## 初始化所有敌人（从资源文件加载）
static func initialize_enemies() -> void:
	if not enemies.is_empty():
		return
	
	print("[EnemyDatabase] 开始加载敌人数据...")
	
	# 加载所有 .tres 资源
	var dir = DirAccess.open(ENEMY_DATA_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var enemy_id = file_name.replace(".tres", "")
				var data = load(ENEMY_DATA_DIR + file_name)
				if data and data is EnemyData:
					enemies[enemy_id] = data
					print("[EnemyDatabase] ✓ 加载敌人: %s" % enemy_id)
				else:
					push_warning("[EnemyDatabase] ✗ 无法加载: %s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("[EnemyDatabase] 无法打开敌人数据目录: %s" % ENEMY_DATA_DIR)
	
	print("[EnemyDatabase] 加载完成，共 %d 个敌人" % enemies.size())

## 获取敌人数据
static func get_enemy_data(enemy_id: String) -> EnemyData:
	if enemies.is_empty():
		initialize_enemies()
	
	if enemies.has(enemy_id):
		return enemies[enemy_id]
	
	# 如果找不到，返回默认敌人
	if enemies.has("basic"):
		push_warning("[EnemyDatabase] 未找到敌人: %s，使用默认敌人" % enemy_id)
		return enemies["basic"]
	
	push_error("[EnemyDatabase] 未找到敌人: %s，且没有默认敌人" % enemy_id)
	return null

## 获取所有敌人ID
static func get_all_enemy_ids() -> Array:
	if enemies.is_empty():
		initialize_enemies()
	return enemies.keys()

## 重新加载敌人数据（用于热重载）
static func reload_enemies() -> void:
	enemies.clear()
	initialize_enemies()
