extends Node2D

@export var enemy_scene: PackedScene
@export var floor_layer_path: NodePath
@export var min_distance_from_player: float = 300.0  # 玩家周围的安全距离
@export var max_spawn_attempts: int = 20  # 最多尝试找位置的次数

@onready var floor_layer: TileMapLayer = get_node(floor_layer_path)

# 获取玩家引用的方式(选择其中一种):
@onready var player: Node2D = get_tree().get_first_node_in_group("player")  # 方式1: 用组
# 或者
# @export var player_path: NodePath
# @onready var player: Node2D = get_node(player_path)  # 方式2: 导出路径

func _ready() -> void:
	assert(floor_layer != null, "刷怪器没拿到 TileMapLayer!")
	assert(player != null, "刷怪器没找到玩家!")

func _process(delta: float) -> void:
	if randf() < 0.02:
		spawn_once()

func spawn_once() -> void:
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		return
	
	# 尝试多次找一个合适的位置
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		# 检查距离
		if is_far_enough_from_player(world_pos):
			var enemy := enemy_scene.instantiate()
			enemy.global_position = world_pos
			add_child(enemy)
			return  # 成功刷怪,退出
	
	# 如果尝试了max_spawn_attempts次都没找到合适位置,就放弃这次刷怪
	# print("警告: 无法找到合适的刷怪位置")

func is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	if player == null:
		return true  # 如果没有玩家,就随便刷
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= min_distance_from_player
