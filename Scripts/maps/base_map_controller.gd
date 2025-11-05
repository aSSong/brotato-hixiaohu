extends Node2D
class_name BaseMapController

## 地图控制器基类
## 为多地图支持建立抽象接口

## 地图配置
var map_config: MapConfig = null

## 生成点列表
var spawn_points: Array[Vector2] = []

## 地图边界
var map_bounds: Rect2 = Rect2()

## 信号
signal map_loaded()
signal spawn_points_generated()

func _init() -> void:
	print("[BaseMapController] 地图控制器初始化")

## 初始化地图
func initialize(config: MapConfig = null) -> void:
	if config:
		map_config = config
		print("[BaseMapController] 使用地图配置: %s" % map_config.map_name)
	else:
		# 创建默认配置
		map_config = MapConfig.new()
		print("[BaseMapController] 使用默认地图配置")
	
	# 设置地图边界
	if map_config.has_boundaries:
		map_bounds = map_config.boundaries
	else:
		map_bounds = Rect2(Vector2.ZERO, map_config.map_size)
	
	_setup_map()

# ========== 虚函数：子类可以重写 ==========

## 设置地图（生成生成点等）
func _setup_map() -> void:
	# 生成默认的生成点
	_generate_spawn_points()
	map_loaded.emit()

## 生成生成点
func _generate_spawn_points() -> void:
	spawn_points.clear()
	
	# 简单的网格生成
	var grid_size = ceil(sqrt(map_config.spawn_point_count))
	var cell_width = map_bounds.size.x / grid_size
	var cell_height = map_bounds.size.y / grid_size
	
	for i in range(map_config.spawn_point_count):
		var row = i / int(grid_size)
		var col = i % int(grid_size)
		
		var x = map_bounds.position.x + (col + 0.5) * cell_width
		var y = map_bounds.position.y + (row + 0.5) * cell_height
		
		spawn_points.append(Vector2(x, y))
	
	print("[BaseMapController] 生成了 %d 个生成点" % spawn_points.size())
	spawn_points_generated.emit()

# ========== 公共接口 ==========

## 获取随机生成点
func get_random_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		# 如果没有生成点，返回地图中心
		return map_bounds.get_center()
	
	return spawn_points[randi() % spawn_points.size()]

## 获取安全的复活位置（远离给定位置）
func get_safe_respawn_position(avoid_position: Vector2 = Vector2.ZERO, min_distance: float = 500.0) -> Vector2:
	if spawn_points.is_empty():
		return get_random_spawn_position()
	
	# 尝试找一个远离avoid_position的生成点
	var valid_points: Array[Vector2] = []
	
	for point in spawn_points:
		if avoid_position == Vector2.ZERO or point.distance_to(avoid_position) >= min_distance:
			valid_points.append(point)
	
	if valid_points.is_empty():
		# 如果找不到足够远的点，返回最远的点
		var farthest_point = spawn_points[0]
		var max_dist = 0.0
		
		for point in spawn_points:
			var dist = point.distance_to(avoid_position)
			if dist > max_dist:
				max_dist = dist
				farthest_point = point
		
		return farthest_point
	
	return valid_points[randi() % valid_points.size()]

## 获取地图边界
func get_map_bounds() -> Rect2:
	return map_bounds

## 检查位置是否在地图内
func is_position_in_bounds(pos: Vector2) -> bool:
	return map_bounds.has_point(pos)

## 将位置限制在地图边界内
func clamp_position_to_bounds(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x),
		clamp(pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
	)

## 获取地图信息
func get_map_info() -> Dictionary:
	if map_config:
		var info = map_config.get_info()
		info["spawn_points_generated"] = spawn_points.size()
		info["bounds"] = map_bounds
		return info
	return {}

## 打印地图信息
func print_map_info() -> void:
	var info = get_map_info()
	print("[BaseMapController] 地图信息:")
	print("  - ID: %s" % info.get("id", "unknown"))
	print("  - 名称: %s" % info.get("name", "unknown"))
	print("  - 大小: %s" % info.get("size", Vector2.ZERO))
	print("  - 生成点: %d" % info.get("spawn_points_generated", 0))
	print("  - 边界: %s" % info.get("bounds", Rect2()))

