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
	_load_enemies_from_dir(ENEMY_DATA_DIR)
	print("[EnemyDatabase] 加载完成，共 %d 个敌人" % enemies.size())

## 递归加载目录下的敌人数据
## 支持子文件夹、.tres/.res 以及导出后的 .remap 后缀
static func _load_enemies_from_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("[EnemyDatabase] 无法打开目录: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			# 递归处理子文件夹
			_load_enemies_from_dir(path + file_name + "/")
		else:
			var full_path = ""
			var enemy_id = ""
			
			# 兼容编辑器 (.tres/.res) 和导出环境 (.tres.remap/.res.remap)
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				full_path = path + file_name
				enemy_id = file_name.get_basename()
			elif file_name.ends_with(".tres.remap") or file_name.ends_with(".res.remap"):
				full_path = path + file_name.trim_suffix(".remap")
				enemy_id = file_name.trim_suffix(".remap").get_basename()
			
			if full_path != "":
				var data = load(full_path)
				if data and data is EnemyData:
					enemies[enemy_id] = data
					print("[EnemyDatabase] ✓ 加载敌人: %s" % enemy_id)
				else:
					push_warning("[EnemyDatabase] ✗ 无法加载: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

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
