extends Node2D
class_name BaseMapController

## 地图控制器基类 - 管理地图特定的逻辑

signal map_ready()
signal player_spawned(player: Node2D)

var map_config: MapConfig
var player: Node2D = null

## 初始化地图
func initialize(config: MapConfig) -> void:
	map_config = config
	print("[MapController] 地图初始化: %s" % map_config.map_name)

## 地图准备完成
func _ready() -> void:
	call_deferred("_on_map_ready")

func _on_map_ready() -> void:
	print("[MapController] 地图就绪")
	map_ready.emit()

## 获取玩家出生点
func get_spawn_position() -> Vector2:
	if map_config:
		return map_config.spawn_position
	return Vector2(960, 540)  # 默认中心位置

## 获取随机敌人生成位置
func get_random_enemy_spawn_position(player_pos: Vector2) -> Vector2:
	if not map_config:
		return player_pos + Vector2(800, 0).rotated(randf() * TAU)
	
	var radius = map_config.enemy_spawn_radius
	var angle = randf() * TAU
	var offset = Vector2(radius, 0).rotated(angle)
	return player_pos + offset

## 检查位置是否在地图内
func is_position_valid(pos: Vector2) -> bool:
	if not map_config:
		return true
	
	# 简单的边界检查
	return pos.x >= 0 and pos.x <= map_config.map_width and \
	       pos.y >= 0 and pos.y <= map_config.map_height

## 获取最近的有效位置
func get_nearest_valid_position(pos: Vector2) -> Vector2:
	if not map_config:
		return pos
	
	var clamped = pos
	clamped.x = clamp(pos.x, 0, map_config.map_width)
	clamped.y = clamp(pos.y, 0, map_config.map_height)
	return clamped
