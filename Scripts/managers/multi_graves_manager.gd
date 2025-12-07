extends Node
class_name MultiGravesManager

## Multi模式墓碑管理器
## 负责在每波开始时刷新对应wave的ghost墓碑
## 注意：作为场景节点使用，不使用autoload

## 预加载墓碑场景
var grave_scene: PackedScene = preload("res://scenes/players/grave.tscn")

## 当前生成的墓碑列表
var current_graves: Array[Grave] = []

## 父节点引用（用于添加墓碑）
var parent_node: Node2D = null

## 玩家引用
var player: CharacterBody2D = null

func _ready() -> void:
	# 添加到组中方便查找
	add_to_group("multi_graves_manager")
	print("[MultiGravesManager] 初始化")

## 设置父节点（用于添加墓碑）
func set_parent_node(node: Node2D) -> void:
	parent_node = node
	if node:
		print("[MultiGravesManager] 设置父节点:", node.name)
	else:
		print("[MultiGravesManager] 设置父节点: null")

## 设置玩家引用
func set_player(p: CharacterBody2D) -> void:
	player = p
	if p:
		print("[MultiGravesManager] 设置玩家引用")

## 为指定wave刷新墓碑
func spawn_graves_for_wave(wave: int) -> void:
	if not parent_node:
		push_error("[MultiGravesManager] 父节点未设置，无法刷新墓碑")
		return
	
	# 清除旧墓碑
	clear_all_graves()
	
	# 从数据库查询该wave的ghost
	var mode_id = GameMain.current_mode_id
	var map_id = GameMain.current_map_id
	var ghosts = GhostDatabase.get_ghosts_for_wave(mode_id, map_id, wave)
	
	if ghosts.is_empty():
		print("[MultiGravesManager] Wave%d 没有Ghost数据" % wave)
		return
	
	print("[MultiGravesManager] 开始刷新 Wave%d 的墓碑，共 %d 个" % [wave, ghosts.size()])
	
	# 为每个ghost创建墓碑
	for ghost_data in ghosts:
		_create_grave_for_ghost(ghost_data)
	
	print("[MultiGravesManager] 墓碑刷新完成，共创建 %d 个墓碑" % current_graves.size())

## 为单个ghost创建墓碑
func _create_grave_for_ghost(ghost_data: GhostData) -> void:
	if not ghost_data or not player:
		return
	
	# 实例化墓碑场景
	var grave_instance: Grave = grave_scene.instantiate()
	grave_instance.global_position = ghost_data.death_position
	
	# 添加到场景
	parent_node.add_child(grave_instance)
	
	# 设置墓碑数据
	grave_instance.setup(ghost_data, player)
	
	# 连接信号
	grave_instance.rescue_requested.connect(_on_grave_rescue_requested)
	grave_instance.transcend_requested.connect(_on_grave_transcend_requested)
	grave_instance.rescue_cancelled.connect(_on_grave_rescue_cancelled)
	
	# 记录到列表
	current_graves.append(grave_instance)
	
	print("[MultiGravesManager] 创建墓碑: %s (第%d世) 于 %s" % [ghost_data.player_name, ghost_data.total_death_count, ghost_data.death_position])

## 墓碑救援请求回调
func _on_grave_rescue_requested(ghost_data: GhostData) -> void:
	print("[MultiGravesManager] 收到墓碑救援请求")
	
	# 检查masterkey
	if GameMain.master_key < 2:
		print("[MultiGravesManager] Master Key不足")
		_restore_game_state()
		return
	
	# 消耗masterkey
	GameMain.master_key -= 2
	print("[MultiGravesManager] 消耗2个Master Key，剩余:", GameMain.master_key)
	
	# 创建Ghost
	_create_ghost_from_data(ghost_data)
	
	# 从列表中移除并清理对应的墓碑
	_remove_grave_by_ghost_data(ghost_data)
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[MultiGravesManager] 救援完成")

## 墓碑超度请求回调
func _on_grave_transcend_requested(ghost_data: GhostData) -> void:
	print("[MultiGravesManager] 收到墓碑超度请求")
	
	# 从列表中移除并清理对应的墓碑
	_remove_grave_by_ghost_data(ghost_data)
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[MultiGravesManager] 超度完成")

## 墓碑救援取消回调
func _on_grave_rescue_cancelled() -> void:
	print("[MultiGravesManager] 墓碑救援取消")

## 根据ghost_data移除对应的墓碑
func _remove_grave_by_ghost_data(ghost_data: GhostData) -> void:
	for i in range(current_graves.size() - 1, -1, -1):
		var grave = current_graves[i]
		if grave and is_instance_valid(grave) and grave.ghost_data == ghost_data:
			grave.cleanup()
			current_graves.remove_at(i)
			break

## 恢复游戏状态
func _restore_game_state() -> void:
	if GameState.previous_state == GameState.State.WAVE_FIGHTING or GameState.previous_state == GameState.State.WAVE_CLEARING:
		GameState.change_state(GameState.previous_state)
	else:
		GameState.change_state(GameState.State.WAVE_FIGHTING)

## 从数据创建Ghost
func _create_ghost_from_data(ghost_data: GhostData) -> void:
	if not ghost_data:
		push_error("[MultiGravesManager] Ghost数据为空")
		return
	
	print("[MultiGravesManager] 开始创建Ghost，职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())
	
	# 获取GhostManager
	var ghost_manager = get_tree().get_first_node_in_group("ghost_manager")
	if not ghost_manager:
		push_error("[MultiGravesManager] 找不到GhostManager")
		return
	
	# 创建Ghost
	var ghost_scene_res = load("res://scenes/players/ghost.tscn")
	var new_ghost = ghost_scene_res.instantiate()
	
	# 设置Ghost数据（在add_child之前）
	new_ghost.class_id = ghost_data.class_id
	new_ghost.ghost_weapons = ghost_data.weapons.duplicate()
	
	# 设置Ghost的名字和死亡次数
	new_ghost.set_name_from_ghost_data(ghost_data.player_name, ghost_data.total_death_count)
	
	# 设置初始位置
	new_ghost.global_position = ghost_data.death_position
	
	# 添加到场景
	get_tree().root.add_child(new_ghost)
	
	# 准备目标
	var follow_target = player
	var queue_index = 0
	
	if ghost_manager.ghosts.size() > 0:
		follow_target = ghost_manager.ghosts[ghost_manager.ghosts.size() - 1]
		queue_index = ghost_manager.ghosts.size()
	
	# 添加到GhostManager
	ghost_manager.ghosts.append(new_ghost)
	
	# 初始化Ghost
	if follow_target:
		var player_speed = ghost_manager._get_player_speed() if ghost_manager.has_method("_get_player_speed") else 400.0
		new_ghost.call_deferred("initialize", follow_target, queue_index, player_speed, true)
	
	print("[MultiGravesManager] Ghost创建成功！职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())

## 清除所有墓碑
func clear_all_graves() -> void:
	print("[MultiGravesManager] 清除所有墓碑，共 %d 个" % current_graves.size())
	
	for grave in current_graves:
		if grave and is_instance_valid(grave):
			grave.cleanup()
	
	current_graves.clear()

## 节点移除时清理
func _exit_tree() -> void:
	clear_all_graves()
	print("[MultiGravesManager] 已清理")

## 获取当前墓碑数量
func get_graves_count() -> int:
	return current_graves.size()
