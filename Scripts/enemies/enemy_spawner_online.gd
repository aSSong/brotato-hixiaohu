extends Node2D
class_name EnemySpawnerOnline

## 敌人生成器 Online（使用 MultiplayerSpawner）
## 职责：只负责生成敌人，不管理波次逻辑

## ========== 配置 ==========
@export var enemy_scene: PackedScene
@export var spawn_delay: float = 0.4  # 生成间隔

var floor_layer: TileMapLayer = null
var wave_system: WaveSystemOnline = null
var enemies_container: Node = null  # Enemies 节点（MultiplayerSpawner 的 spawn_path）

## ========== 生成参数 ==========
var min_distance_from_player: float = 300.0
var max_spawn_attempts: int = 30

var enemystrong_per_wave: float = 2.0 # 每多少波敌人变强一次
var enemystrong_multi :float = 1.5 # 每次变强多少

## ========== 状态 ==========
var is_spawning: bool = false


func _is_network_server() -> bool:
	return NetworkManager.is_server()


func _ready() -> void:
	add_to_group("enemy_spawner")
	
	# 查找地图
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_error("[EnemySpawner Online] 找不到floor_layer")
	
	print("[EnemySpawner Online] 初始化完成 (MultiplayerSpawner 模式)")


## 设置 Enemies 容器节点
func set_enemies_container(container: Node) -> void:
	enemies_container = container
	print("[EnemySpawner Online] Enemies 容器已设置")


## 设置波次系统
func set_wave_system(system: WaveSystemOnline) -> void:
	wave_system = system
	print("[EnemySpawner Online] 连接到波次系统")


## 生成一波敌人（只有服务器调用）
func spawn_wave(wave_config: Dictionary) -> void:
	if is_spawning:
		push_warning("[EnemySpawner Online] 已在生成中，忽略")
		return
	
	# 只有服务器负责生成敌人
	if not _is_network_server():
		print("[EnemySpawner Online] 非服务器节点，等待 MultiplayerSpawner 同步")
		return
	
	if not wave_system:
		push_error("[EnemySpawner Online] 波次系统未设置")
		return
	
	if not enemies_container:
		push_error("[EnemySpawner Online] Enemies 容器未设置")
		return
	
	var wave_number = wave_config.wave_number
	print("[EnemySpawner Online] 开始生成第 ", wave_number, " 波")
	
	# 构建生成列表
	var spawn_list = _build_spawn_list(wave_config)
	
	# 开始异步生成
	_spawn_enemies_async(spawn_list, wave_number)


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
	
	print("[EnemySpawner Online] 生成列表：", list.size(), " 个敌人")
	return list


## 异步生成敌人列表（服务器端）
func _spawn_enemies_async(spawn_list: Array, wave_number: int) -> void:
	is_spawning = true
	
	var index = 0
	for enemy_id in spawn_list:
		var is_last = (index == spawn_list.size() - 1)
		
		var enemy = _spawn_single_enemy(enemy_id, is_last, wave_number)
		if enemy:
			# 通知波次系统
			if wave_system:
				if wave_system.has_method("register_enemy_instance"):
					wave_system.register_enemy_instance(enemy)
				elif wave_system.has_method("on_enemy_spawned"):
					wave_system.on_enemy_spawned(enemy)
		
		# 等待间隔
		await get_tree().create_timer(spawn_delay, false).timeout
		index += 1
	
	is_spawning = false
	print("[EnemySpawner Online] 生成完成")


## 生成单个敌人（服务器端）
func _spawn_single_enemy(enemy_id: String, is_last_in_wave: bool, wave_number: int) -> EnemyOnline:
	if not floor_layer:
		push_error("[EnemySpawner Online] floor_layer未设置")
		return null
	
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		push_error("[EnemySpawner Online] 地图没有可用格子")
		return null
	
	# 获取敌人数据
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("[EnemySpawner Online] 敌人数据不存在：", enemy_id)
		return null
	
	# 计算HP增长倍数
	var strength_level = floor(wave_number / enemystrong_per_wave)
	var hp_multiplier = pow(enemystrong_multi, strength_level)
	
	# 尝试多次找合适的位置
	var spawn_pos: Vector2 = Vector2.ZERO
	var found_position := false
	
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		if _is_far_enough_from_player(world_pos):
			spawn_pos = world_pos
			found_position = true
			break
	
	if not found_position:
		push_warning("[EnemySpawner Online] 无法找到合适位置（尝试", max_spawn_attempts, "次）：", enemy_id)
		return null
	
	# 创建敌人实例
	var enemy := enemy_scene.instantiate() as EnemyOnline
	if not enemy:
		push_error("[EnemySpawner Online] 无法实例化敌人场景")
		return null
	
	# 设置基本属性（这些属性会通过 MultiplayerSynchronizer 同步）
	enemy.enemy_id = enemy_id
	enemy.global_position = spawn_pos
	enemy.is_last_enemy_in_wave = is_last_in_wave
	enemy.current_wave_number = wave_number
	
	# 计算并设置HP
	var final_hp := int(enemy_data.max_hp * hp_multiplier)
	enemy.max_enemyHP = final_hp
	enemy.enemyHP = final_hp
	
	# 服务器端加载完整敌人数据
	enemy.enemy_data = enemy_data
	enemy.enemy_spawner = self
	
	# 添加到 Enemies 容器（MultiplayerSpawner 会自动同步到客户端）
	enemies_container.add_child(enemy, true)  # true = force_readable_name
	
	print("[EnemySpawner Online] 生成敌人：", enemy_id, " 波次:", wave_number, " HP:", enemy.enemyHP, " 位置:", spawn_pos)
	
	return enemy


## 检查位置是否距离所有玩家足够远
func _is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	var players = NetworkPlayerManager.players
	if players.is_empty():
		return true
	
	for peer_id in players.keys():
		var player = players[peer_id]
		if player and is_instance_valid(player):
			var distance := spawn_pos.distance_to(player.global_position)
			if distance < min_distance_from_player:
				return false
	
	return true


## 清理所有敌人（调试用）
func clear_all_enemies() -> void:
	if not enemies_container:
		return
	
	for child in enemies_container.get_children():
		if child is EnemyOnline:
			child.queue_free()
	print("[EnemySpawner Online] 清理所有敌人")


## 获取所有活着的敌人
func get_alive_enemies() -> Array[EnemyOnline]:
	var result: Array[EnemyOnline] = []
	
	if not enemies_container:
		return result
	
	for child in enemies_container.get_children():
		if child is EnemyOnline and is_instance_valid(child) and not child.is_dead:
			result.append(child)
	
	return result


## 通知敌人受伤（服务器端调用，广播伤害效果给客户端）
func notify_enemy_hurt(enemy: EnemyOnline, damage: int, is_critical: bool = false, attacker_peer_id: int = 0) -> void:
	if not _is_network_server():
		return
	if not enemy:
		return
	
	print("[EnemySpawner Online] notify_enemy_hurt name=%s hp=%d dmg=%d" % [enemy.name, enemy.enemyHP, damage])
	
	# 广播伤害效果给所有客户端
	rpc(&"rpc_show_enemy_hurt_effect", enemy.name, damage, is_critical, attacker_peer_id)


## 通知敌人死亡（服务器端调用）
func notify_enemy_dead(enemy: EnemyOnline) -> void:
	if not _is_network_server():
		return
	if not enemy:
		return
	
	print("[EnemySpawner Online] notify_enemy_dead name=%s" % enemy.name)
	
	# 广播死亡效果给所有客户端
	rpc(&"rpc_show_enemy_dead_effect", enemy.name)


## RPC：显示敌人受伤效果（客户端）
@rpc("authority", "call_remote", "reliable")
func rpc_show_enemy_hurt_effect(enemy_name: String, damage: int, is_critical: bool, attacker_peer_id: int) -> void:
	if _is_network_server():
		return
	
	if not enemies_container:
		return
	
	var enemy = enemies_container.get_node_or_null(enemy_name)
	if enemy and enemy is EnemyOnline and is_instance_valid(enemy):
		# 播放受伤效果
		enemy.show_hurt_effect(damage, is_critical)


## RPC：显示敌人死亡效果（客户端）
@rpc("authority", "call_remote", "reliable")
func rpc_show_enemy_dead_effect(enemy_name: String) -> void:
	if _is_network_server():
		return
	
	if not enemies_container:
		return
	
	var enemy = enemies_container.get_node_or_null(enemy_name)
	if enemy and enemy is EnemyOnline and is_instance_valid(enemy):
		# 播放死亡效果
		enemy.show_death_effect()
