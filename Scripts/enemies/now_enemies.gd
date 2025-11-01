extends Node2D

## 敌人生成器
## 管理波次敌人的生成
## V3: 使用新的波次系统

@export var enemy_scene: PackedScene
@export var floor_layer_path: NodePath
@export var min_distance_from_player: float = 300.0  # 玩家周围的安全距离
@export var max_spawn_attempts: int = 20  # 最多尝试找位置的次数
@export var spawn_delay: float = 0.5  # 每个敌人之间的生成间隔

@onready var floor_layer: TileMapLayer = get_node(floor_layer_path)
@onready var player: Node2D = get_tree().get_first_node_in_group("player")

## 新的波次系统 V3
var wave_system: WaveSystemV3 = null
var enemy_spawner: EnemySpawnerV3 = null

func _ready() -> void:
	add_to_group("enemy_spawner")
	
	assert(floor_layer != null, "刷怪器没拿到 TileMapLayer!")
	assert(player != null, "刷怪器没找到玩家!")
	
	# 创建新的波次系统
	wave_system = WaveSystemV3.new()
	add_child(wave_system)
	wave_system.name = "WaveSystemV3"
	wave_system.add_to_group("wave_manager")
	
	# 创建新的敌人生成器
	enemy_spawner = EnemySpawnerV3.new()
	add_child(enemy_spawner)
	enemy_spawner.name = "EnemySpawnerV3"
	
	# 配置生成器
	enemy_spawner.enemy_scene = enemy_scene
	enemy_spawner.floor_layer = floor_layer
	enemy_spawner.player = player
	enemy_spawner.min_distance_from_player = min_distance_from_player
	enemy_spawner.max_spawn_attempts = max_spawn_attempts
	enemy_spawner.spawn_delay = spawn_delay
	
	# 连接系统
	wave_system.set_enemy_spawner(enemy_spawner)
	enemy_spawner.set_wave_system(wave_system)
	
	print("[now_enemies] 使用新的波次系统 V3")
	
	# 等待一下再开始第一波
	await get_tree().create_timer(1.0).timeout
	wave_system.start_game()

## 获取波次管理器（供外部访问，保持兼容性）
func get_wave_manager():
	return wave_system
