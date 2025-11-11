extends Node

## 地图注册表 - 管理所有可用的地图

var _maps: Dictionary = {}  # map_id -> MapConfig
var current_map_id: String = ""

func _ready() -> void:
	_register_builtin_maps()
	print("[MapRegistry] 地图注册表就绪，已注册 %d 个地图" % _maps.size())

## 注册内置地图
func _register_builtin_maps() -> void:
	# 注册默认地图（survival模式）
	var default_map = MapConfig.new("default", "默认战场", "res://scenes/map/bg_map.tscn")
	default_map.map_description = "标准生存模式地图"
	default_map.spawn_position = Vector2(960, 540)
	default_map.enemy_spawn_radius = 800.0
	default_map.supported_modes = ["survival"]
	register_map(default_map)
	
	# 注册Multi模式第一张地图
	var multi_stage1 = MapConfig.new("model2_stage1", "Multi模式-第一关", "res://scenes/map/model_2_stage_1.tscn")
	multi_stage1.map_description = "Multi模式的第一张地图"
	multi_stage1.spawn_position = Vector2(960, 540)
	multi_stage1.enemy_spawn_radius = 800.0
	multi_stage1.supported_modes = ["multi"]
	register_map(multi_stage1)

## 注册地图
func register_map(map_config: MapConfig) -> void:
	if map_config.map_id.is_empty():
		push_error("[MapRegistry] 地图ID为空，无法注册")
		return
	
	if _maps.has(map_config.map_id):
		push_warning("[MapRegistry] 地图已存在，覆盖: %s" % map_config.map_id)
	
	_maps[map_config.map_id] = map_config
	print("[MapRegistry] 注册地图: %s (%s)" % [map_config.map_name, map_config.map_id])

## 获取地图配置
func get_map(map_id: String) -> MapConfig:
	if not _maps.has(map_id):
		push_error("[MapRegistry] 地图不存在: %s" % map_id)
		return null
	return _maps[map_id]

## 设置当前地图
func set_current_map(map_id: String) -> bool:
	if not _maps.has(map_id):
		push_error("[MapRegistry] 地图不存在: %s" % map_id)
		return false
	
	current_map_id = map_id
	print("[MapRegistry] 当前地图设置为: %s" % _maps[map_id].map_name)
	return true

## 获取所有地图
func get_all_maps() -> Array:
	var maps: Array = []
	for map_cfg in _maps.values():
		maps.append(map_cfg)
	return maps

## 获取支持指定模式的地图
func get_maps_for_mode(mode_id: String) -> Array:
	var compatible_maps: Array = []
	for map_cfg in _maps.values():
		if map_cfg.is_mode_supported(mode_id):
			compatible_maps.append(map_cfg)
	return compatible_maps
