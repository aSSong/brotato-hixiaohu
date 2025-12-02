extends Node
class_name UpgradeDatabase

## 升级数据库（重构版）
## 预定义各种升级选项及其属性
## 
## 说明：
##   - 仅从 resources/upgrades/ 加载 .tres 资源文件
##   - 硬编码初始化逻辑已移除
## 
## 新系统使用示例：
##   var upgrade = UpgradeData.new(...)
##   upgrade.stats_modifier = CombatStats.new()
##   upgrade.stats_modifier.melee_damage_mult = 1.1  # +10%近战伤害
##   upgrade.stats_modifier.max_hp = 50  # +50血量
##   upgrades["upgrade_id"] = upgrade

static var upgrades: Dictionary = {}

## 初始化所有基础升级选项
static func initialize_upgrades() -> void:
	if not upgrades.is_empty():
		return
	
	# 尝试从资源文件加载
	if _load_upgrades_from_resources():
		print("[UpgradeDatabase] 成功从资源文件加载升级数据")
	else:
		push_error("[UpgradeDatabase] 错误：未找到升级资源文件！请运行 upgrade_migration_tool.gd")

## 从资源文件加载升级数据
static func _load_upgrades_from_resources() -> bool:
	var root_dir = "res://resources/upgrades"
	var dir = DirAccess.open(root_dir)
	
	if not dir:
		return false
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	# 遍历类型子目录
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir_path = root_dir + "/" + file_name
			loaded_count += _load_upgrades_from_dir(sub_dir_path)
		file_name = dir.get_next()
	
	return loaded_count > 0

## 从指定目录加载升级资源
static func _load_upgrades_from_dir(path: String) -> int:
	var dir = DirAccess.open(path)
	if not dir:
		return 0
		
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
			
		var full_path = ""
		var id = ""
		
		# 兼容编辑器环境 (.tres) 和导出环境 (.tres.remap)
		if file_name.ends_with(".tres"):
			full_path = path + "/" + file_name
			id = file_name.get_basename()
		elif file_name.ends_with(".tres.remap"):
			# 导出后，文本资源可能会被转换为二进制并重命名为 .remap
			# 加载时需要去掉 .remap 后缀，DirAccess 会返回物理文件名
			full_path = path + "/" + file_name.trim_suffix(".remap")
			id = file_name.trim_suffix(".remap").get_basename()
			
		if full_path != "":
			var upgrade = ResourceLoader.load(full_path) as UpgradeData
			if upgrade:
				upgrades[id] = upgrade
				count += 1
				
		file_name = dir.get_next()
		
	return count

## 获取基础升级数据
static func get_upgrade_data(upgrade_id: String) -> UpgradeData:
	if upgrades.is_empty():
		initialize_upgrades()
	return upgrades.get(upgrade_id, null)

## 获取所有基础升级ID（不包括动态生成的）
static func get_all_upgrade_ids() -> Array:
	if upgrades.is_empty():
		initialize_upgrades()
	return upgrades.keys()

## 获取指定类型的所有基础升级
static func get_upgrades_by_type(type: UpgradeData.UpgradeType) -> Array[UpgradeData]:
	if upgrades.is_empty():
		initialize_upgrades()
	
	var result: Array[UpgradeData] = []
	for upgrade_id in upgrades.keys():
		var upgrade = upgrades[upgrade_id]
		if upgrade and upgrade.upgrade_type == type:
			result.append(upgrade)
	return result