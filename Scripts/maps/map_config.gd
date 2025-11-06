extends Resource
class_name MapConfig

## 地图配置 - 定义单个地图的所有配置

@export var map_id: String = ""
@export var map_name: String = "未命名地图"
@export var map_description: String = ""
@export var scene_path: String = ""
@export var thumbnail_path: String = ""

## 地图尺寸
@export var map_width: int = 1920
@export var map_height: int = 1080

## 玩家出生点
@export var spawn_position: Vector2 = Vector2(960, 540)

## 敌人生成配置
@export var enemy_spawn_radius: float = 800.0
@export var max_enemy_distance: float = 1500.0

## 地图特性
@export var has_obstacles: bool = false
@export var is_enclosed: bool = true  # 是否有边界墙

## 支持的游戏模式
@export var supported_modes: Array = ["survival"]

func _init(_id: String = "", _name: String = "", _scene: String = "") -> void:
	map_id = _id
	map_name = _name
	scene_path = _scene

func is_mode_supported(mode_id: String) -> bool:
	return mode_id in supported_modes
