extends Node
class_name MapRegistry

## 地图注册表
## 集中管理所有可用的地图配置

## 已注册的地图配置
static var registered_maps: Dictionary = {}

## 初始化标志
static var _initialized: bool = false

## 初始化注册表（注册所有地图）
static func initialize() -> void:
	if _initialized:
		return
	
	print("[MapRegistry] 初始化地图注册表")
	
	# 注册默认地图
	_register_default_map()
	
	# 未来可以从文件或目录加载更多地图配置
	# _load_maps_from_directory("res://maps/configs/")
	
	_initialized = true
	print("[MapRegistry] 已注册 %d 个地图" % registered_maps.size())

## 注册默认地图
static func _register_default_map() -> void:
	var default_config = MapConfig.new()
	default_config.map_id = "default"
	default_config.map_name = "默认竞技场"
	default_config.map_description = "标准战斗地图"
	default_config.map_scene_path = "res://scenes/map/bg_map.tscn"
	default_config.map_size = Vector2(2000, 2000)
	default_config.spawn_point_count = 10
	default_config.background_music = "fight"
	default_config.difficulty = 1
	
	register_map(default_config)

## 注册地图配置
## @param config: 地图配置资源
static func register_map(config: MapConfig) -> void:
	if not config:
		push_error("[MapRegistry] 地图配置为空")
		return
	
	if registered_maps.has(config.map_id):
		push_warning("[MapRegistry] 地图已存在，覆盖: %s" % config.map_id)
	
	registered_maps[config.map_id] = config
	print("[MapRegistry] 注册地图: %s (%s)" % [config.map_id, config.map_name])

## 从文件注册地图
## @param config_path: 地图配置文件路径（.tres或.res）
static func register_map_from_file(config_path: String) -> void:
	var config = load(config_path)
	if not config or not config is MapConfig:
		push_error("[MapRegistry] 无法加载地图配置: %s" % config_path)
		return
	
	register_map(config)

## 获取地图配置
## @param map_id: 地图ID
## @return: 地图配置资源，如果不存在返回null
static func get_map_config(map_id: String) -> MapConfig:
	if not _initialized:
		initialize()
	
	if not registered_maps.has(map_id):
		push_error("[MapRegistry] 地图不存在: %s" % map_id)
		return null
	
	return registered_maps[map_id]

## 获取所有地图ID
static func get_all_map_ids() -> Array[String]:
	if not _initialized:
		initialize()
	
	var ids: Array[String] = []
	for key in registered_maps.keys():
		ids.append(key)
	return ids

## 检查地图是否存在
static func has_map(map_id: String) -> bool:
	if not _initialized:
		initialize()
	
	return registered_maps.has(map_id)

## 获取地图信息
static func get_map_info(map_id: String) -> Dictionary:
	var config = get_map_config(map_id)
	if not config:
		return {}
	
	return config.get_info()

## 获取所有地图信息
static func get_all_map_infos() -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	
	for map_id in get_all_map_ids():
		var info = get_map_info(map_id)
		if not info.is_empty():
			infos.append(info)
	
	return infos

## 打印所有注册的地图
static func print_registered_maps() -> void:
	print("[MapRegistry] 已注册的地图:")
	for map_id in get_all_map_ids():
		var info = get_map_info(map_id)
		print("  - %s: %s" % [map_id, info.get("name", "Unknown")])
		print("    场景: %s" % info.get("scene", "未指定"))
		print("    大小: %s" % info.get("size", Vector2.ZERO))
		print("    难度: %d" % info.get("difficulty", 1))

