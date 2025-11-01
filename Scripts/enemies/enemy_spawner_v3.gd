extends Node2D
class_name EnemySpawnerV3

## 新的敌人生成器 V3
## 职责：只负责生成敌人，不管理波次逻辑

## ========== 配置 ==========
@export var enemy_scene: PackedScene
@export var spawn_delay: float = 0.5  # 生成间隔

var floor_layer: TileMapLayer = null
var player: Node = null
var wave_system: WaveSystemV3 = null

## ========== 生成参数 ==========
var min_distance_from_player: float = 500.0
var max_spawn_attempts: int = 30

## ========== 状态 ==========
var is_spawning: bool = false

func _ready() -> void:
	# 查找地图
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_error("[EnemySpawner V3] 找不到floor_layer")
	
	# 查找玩家
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[EnemySpawner V3] 找不到player")
	
	print("[EnemySpawner V3] 初始化完成")

## 设置波次系统
func set_wave_system(system: WaveSystemV3) -> void:
	wave_system = system
	print("[EnemySpawner V3] 连接到波次系统")

## 生成一波敌人
func spawn_wave(wave_config: Dictionary) -> void:
	if is_spawning:
		push_warning("[EnemySpawner V3] 已在生成中，忽略")
		return
	
	if not wave_system:
		push_error("[EnemySpawner V3] 波次系统未设置")
		return
	
	print("[EnemySpawner V3] 开始生成第 ", wave_config.wave_number, " 波")
	
	# 构建生成列表
	var spawn_list = _build_spawn_list(wave_config)
	
	# 开始异步生成
	_spawn_enemies_async(spawn_list)

## 构建生成列表
func _build_spawn_list(config: Dictionary) -> Array:
	var list = []
	
	# 添加普通敌人
	if config.has("enemies"):
		for enemy_group in config.enemies:
			for i in range(enemy_group.count):
				list.append(enemy_group.id)
	
	# 添加最后的敌人
	if config.has("last_enemy"):
		for i in range(config.last_enemy.count):
			list.append(config.last_enemy.id)
	
	print("[EnemySpawner V3] 生成列表：", list.size(), " 个敌人")
	return list

## 异步生成敌人列表
func _spawn_enemies_async(spawn_list: Array) -> void:
	is_spawning = true
	
	var index = 0
	for enemy_id in spawn_list:
		var is_last = (index == spawn_list.size() - 1)
		
		# 生成敌人
		var enemy = _spawn_single_enemy(enemy_id, is_last)
		
		# 通知波次系统
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		else:
			push_warning("[EnemySpawner V3] 敌人生成失败：", enemy_id)
		
		# 等待间隔
		await get_tree().create_timer(spawn_delay).timeout
		index += 1
	
	is_spawning = false
	print("[EnemySpawner V3] 生成完成")

## 生成单个敌人
func _spawn_single_enemy(enemy_id: String, is_last_in_wave: bool = false) -> Node:
	if not floor_layer:
		push_error("[EnemySpawner V3] floor_layer未设置")
		return null
	
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		push_error("[EnemySpawner V3] 地图没有可用格子")
		return null
	
	# 获取敌人数据
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("[EnemySpawner V3] 敌人数据不存在：", enemy_id)
		return null
	
	# 尝试多次找合适的位置
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		# 检查距离玩家是否足够远
		if _is_far_enough_from_player(world_pos):
			var enemy := enemy_scene.instantiate()
			
			# 设置位置
			enemy.global_position = world_pos
			
			# 初始化敌人数据
			if enemy.has_method("initialize"):
				enemy.initialize(enemy_data)
			else:
				enemy.enemy_data = enemy_data
				if enemy.has_method("_apply_enemy_data"):
					enemy._apply_enemy_data()
			
			# 标记是否为最后一个敌人（掉落钥匙）
			enemy.is_last_enemy_in_wave = is_last_in_wave
			
			# 添加到场景树
			add_child(enemy)
			
			print("[EnemySpawner V3] 生成敌人：", enemy_id, " 位置：", world_pos)
			return enemy
	
	# 尝试多次后仍失败
	push_warning("[EnemySpawner V3] 无法找到合适位置（尝试", max_spawn_attempts, "次）：", enemy_id)
	return null

## 检查位置是否足够远
func _is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return true
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= min_distance_from_player

## 清理所有敌人（调试用）
func clear_all_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()
	print("[EnemySpawner V3] 清理所有敌人")
