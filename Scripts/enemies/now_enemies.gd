extends Node2D

@export var enemy_scene: PackedScene        # 在 Inspector 里把 enemy.tscn 拖进来
@export var floor_layer_path: NodePath      # 把 TileMapLayer 拖进来，或者填路径

@onready var floor_layer: TileMapLayer = get_node(floor_layer_path)

func _ready() -> void:
	# 保险起见，刷怪之前先确认拿到了层
	assert(floor_layer != null, "刷怪器没拿到 TileMapLayer！")

func _process(delta: float) -> void:
	# 每隔一段时间刷一只，别每帧都刷
	if randf() < 0.02:          # 2% 概率，想快就调大
		spawn_once()

func spawn_once() -> void:
	var used := floor_layer.get_used_cells()  # 4.x 不用填来源层 id
	if used.is_empty():
		return

	var cell := used[randi() % used.size()]  # 随机挑一个格子
	var world_pos := floor_layer.map_to_local(cell)

	var enemy := enemy_scene.instantiate()
	enemy.global_position = world_pos  * 6       # 直接给全局坐标，省去手动乘 6
	add_child(enemy)
