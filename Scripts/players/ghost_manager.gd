extends Node
class_name GhostManager

## Ghost管理器
## 管理所有Ghost的创建、队列和速度同步

## Ghost场景
var ghost_scene = preload("res://scenes/players/ghost.tscn")

## Ghost列表
var ghosts: Array = []

## 玩家引用
var player: Node2D = null

## ghost之间间隔的路径点数目
var ghost_Interval = 8

## 每个Ghost保留的路径点数量（用于跟随）
var ghost_path_length = 30  # 每个Ghost使用最近的30个路径点

func _ready() -> void:
	# 添加到组中以便查找
	add_to_group("ghost_manager")

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	var player_speed = _get_player_speed()
	var player_path: Array = []
	if "get_path_history" in player:
		player_path = player.get_path_history()
	
	var max_required_player_points: int = ghost_path_length + ghost_Interval
	var offset_points: int = max(1, ghost_Interval)
	
	for i in range(ghosts.size()):
		var ghost = ghosts[i]
		if ghost == null or not is_instance_valid(ghost):
			continue
		
		ghost.update_speed(player_speed)
		
		var desired_length: int = ghost_path_length + i * ghost_Interval
		if "ensure_path_history_capacity" in ghost:
			ghost.ensure_path_history_capacity(desired_length + offset_points)
		
		if i == 0:
			max_required_player_points = max(max_required_player_points, desired_length + offset_points)
			_assign_chain_path(ghost, player_path, offset_points, desired_length)
		else:
			var prev_ghost = ghosts[i - 1]
			if prev_ghost == null or not is_instance_valid(prev_ghost):
				continue
			if not ("path_history" in prev_ghost):
				continue
			_assign_chain_path(ghost, prev_ghost.path_history, offset_points, desired_length)
	
	if "ensure_path_history_capacity" in player:
		player.ensure_path_history_capacity(max_required_player_points)
	elif "max_path_points" in player:
		player.max_path_points = max(player.max_path_points, max_required_player_points)

func _assign_chain_path(ghost: Node, source_path: Array, offset_points: int, desired_length: int) -> void:
	if source_path.is_empty():
		return
	var end_index: int = source_path.size() - offset_points
	if end_index <= 0:
		return
	var length: int = min(desired_length, end_index)
	var start_index: int = max(0, end_index - length)
	if end_index - start_index < 2:
		return
	var ghost_path: Array = source_path.slice(start_index, end_index)
	if ghost_path.is_empty():
		return
	if "update_path_points" in ghost:
		ghost.update_path_points(ghost_path)
	if "ensure_chain_alignment" in ghost:
		ghost.ensure_chain_alignment(ghost_path)

## 设置玩家引用
func set_player(p: Node2D) -> void:
	player = p

## 创建新的Ghost（使用GhostFactory）
func spawn_ghost() -> void:
	if player == null or not is_instance_valid(player):
		push_error("玩家引用无效，无法创建Ghost")
		return
	
	# 确定跟随目标（最后一个Ghost或玩家）
	var follow_target = player
	var queue_index = 0
	
	if ghosts.size() > 0:
		# 如果已有Ghost，跟随最后一个Ghost
		var last_ghost = ghosts[ghosts.size() - 1]
		if is_instance_valid(last_ghost):
			follow_target = last_ghost
		queue_index = ghosts.size()
	
	# 获取玩家速度
	var player_speed = _get_player_speed()
	
	# 使用GhostFactory创建Ghost
	var new_ghost = GhostFactory.create_ghost(follow_target, queue_index, player_speed, null)
	if not new_ghost:
		push_error("[GhostManager] Ghost创建失败")
		return
	
	# 添加到场景树
	get_tree().root.add_child(new_ghost)
	
	# 添加到列表
	ghosts.append(new_ghost)
	
	print("Ghost创建成功！当前Ghost数量: %d" % ghosts.size())

## 获取玩家速度
func _get_player_speed() -> float:
	if player == null or not is_instance_valid(player):
		return 400.0  # 默认速度
	
	# 尝试获取玩家的speed属性
	if "speed" in player:
		return player.speed
	
	return 400.0  # 默认速度

## 清除所有Ghost
func clear_all_ghosts() -> void:
	for ghost in ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	ghosts.clear()
	print("所有Ghost已清除")

## 获取Ghost数量
func get_ghost_count() -> int:
	# 清理无效的Ghost引用
	ghosts = ghosts.filter(func(g): return is_instance_valid(g))
	return ghosts.size()
