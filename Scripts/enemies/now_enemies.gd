extends Node2D

## 敌人生成器
## 管理波次敌人的生成

@export var enemy_scene: PackedScene
@export var floor_layer_path: NodePath
@export var min_distance_from_player: float = 300.0  # 玩家周围的安全距离
@export var max_spawn_attempts: int = 20  # 最多尝试找位置的次数

@onready var floor_layer: TileMapLayer = get_node(floor_layer_path)

# 获取玩家引用的方式(选择其中一种):
@onready var player: Node2D = get_tree().get_first_node_in_group("player")  # 方式1: 用组

## 波次管理器
var wave_manager: WaveManager = null

## 当前波的生成队列
var current_spawn_queue: Array = []
var is_spawning: bool = false
var spawn_delay: float = 0.5  # 每个敌人之间的生成间隔

func _ready() -> void:
	# 添加到组中以便查找
	add_to_group("enemy_spawner")
	
	assert(floor_layer != null, "刷怪器没拿到 TileMapLayer!")
	assert(player != null, "刷怪器没找到玩家!")
	
	# 创建波次管理器
	wave_manager = WaveManager.new()
	add_child(wave_manager)
	
	# 将wave_manager添加到组中
	wave_manager.add_to_group("wave_manager")
	
	# 连接信号
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.enemy_killed.connect(_on_enemy_killed_in_wave)
	
	# 等待一下再开始第一波
	await get_tree().create_timer(1.0).timeout
	wave_manager.start_next_wave()

func _process(_delta: float) -> void:
	# 不再使用随机生成，改为波次生成
	pass

## 波次开始
func _on_wave_started(wave_number: int) -> void:
	print("波次 ", wave_number, " 开始！")
	# 获取当前波的生成列表
	current_spawn_queue = wave_manager.get_current_wave_spawn_list()
	# 开始生成敌人
	_start_spawning_wave()

## 开始生成一波敌人
func _start_spawning_wave() -> void:
	if is_spawning:
		return
	
	is_spawning = true
	
	# 依次生成敌人
	for enemy_id in current_spawn_queue:
		spawn_enemy(enemy_id)
		await get_tree().create_timer(spawn_delay).timeout
	
	is_spawning = false
	current_spawn_queue.clear()

## 生成指定类型的敌人
func spawn_enemy(enemy_id: String) -> void:
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		return
	
	# 获取敌人数据
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("敌人数据不存在: " + enemy_id)
		return
	
	# 尝试多次找一个合适的位置
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		# 检查距离
		if is_far_enough_from_player(world_pos):
			var enemy := enemy_scene.instantiate()
			enemy.global_position = world_pos
			
			# 初始化敌人数据
			if enemy.has_method("initialize"):
				enemy.initialize(enemy_data)
			else:
				# 如果没有initialize方法，直接设置数据
				enemy.enemy_data = enemy_data
				if enemy.has_method("_apply_enemy_data"):
					enemy._apply_enemy_data()
			
			# 连接死亡信号
			if enemy.has_signal("enemy_killed"):
				if not enemy.enemy_killed.is_connected(_on_enemy_killed):
					enemy.enemy_killed.connect(_on_enemy_killed)
			
			add_child(enemy)
			wave_manager.enemies_spawned_this_wave += 1
			return
	
	# 如果尝试了max_spawn_attempts次都没找到合适位置,就放弃这次刷怪
	print("警告: 无法找到合适的刷怪位置")

## 敌人被击杀
func _on_enemy_killed(_enemy_ref: Enemy) -> void:
	wave_manager.on_enemy_killed()

## 波次中的敌人击杀更新
func _on_enemy_killed_in_wave(wave_number: int, killed: int, total: int) -> void:
	# 这个信号会被UI监听
	pass

func is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	if player == null:
		return true  # 如果没有玩家,就随便刷
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= min_distance_from_player

## 连接所有敌人的死亡信号（用于动态生成的敌人）
func connect_all_enemy_death_signals() -> void:
	# 当有新的敌人添加时，会自动连接信号
	pass

## 获取波次管理器（供外部访问）
func get_wave_manager():
	return wave_manager

## 当子节点添加时，如果是敌人，连接信号
func _on_child_entered_tree(node: Node) -> void:
	if node is Enemy:
		if not node.enemy_killed.is_connected(_on_enemy_killed):
			node.enemy_killed.connect(_on_enemy_killed)
