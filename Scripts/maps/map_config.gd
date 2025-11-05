extends Resource
class_name MapConfig

## 地图配置资源
## 定义地图的基本信息和参数

## 地图ID
@export var map_id: String = "default"

## 地图名称
@export var map_name: String = "默认地图"

## 地图描述
@export_multiline var map_description: String = ""

## 地图场景路径
@export_file("*.tscn") var map_scene_path: String = ""

## 地图大小
@export var map_size: Vector2 = Vector2(2000, 2000)

## 生成点数量
@export var spawn_point_count: int = 10

## 背景音乐
@export var background_music: String = "fight"

## 地图难度（1-5）
@export_range(1, 5) var difficulty: int = 1

## 是否启用边界限制
@export var has_boundaries: bool = true

## 边界矩形（如果has_boundaries为true）
@export var boundaries: Rect2 = Rect2(0, 0, 2000, 2000)

## 获取地图信息
func get_info() -> Dictionary:
	return {
		"id": map_id,
		"name": map_name,
		"description": map_description,
		"scene": map_scene_path,
		"size": map_size,
		"spawn_points": spawn_point_count,
		"bgm": background_music,
		"difficulty": difficulty
	}

