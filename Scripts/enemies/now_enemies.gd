extends Node2D

## 敌人生成器
## 管理波次敌人的生成
## V3: 使用新的波次系统

@export var enemy_scene: PackedScene
@export var floor_layer_path: NodePath
@export var max_spawn_attempts: int = 20  # 最多尝试找位置的次数
# 刷怪距离范围现在在 EnemySpawnerV3 中以常量定义（SPAWN_MIN_DISTANCE / SPAWN_MAX_DISTANCE）
# spawn_delay 已移除，现在从波次配置JSON中读取

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
	
	# 配置生成器（fallback_enemy_scene 作为兜底，当敌人没有 scene_path 时使用）
	enemy_spawner.fallback_enemy_scene = enemy_scene
	enemy_spawner.floor_layer = floor_layer
	enemy_spawner.player = player
	enemy_spawner.max_spawn_attempts = max_spawn_attempts
	# 刷怪距离范围在 EnemySpawnerV3 中以常量定义，不再需要手动设置
	
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
