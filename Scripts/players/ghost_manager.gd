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

func _process(delta: float) -> void:
	# 同步所有Ghost的速度与玩家速度
	if player and is_instance_valid(player):
		var player_speed = _get_player_speed()
		
		# 获取玩家路径历史
		var player_path = []
		if "get_path_history" in player:
			player_path = player.get_path_history()
		
		for i in range(ghosts.size()):
			var ghost = ghosts[i]
			if is_instance_valid(ghost):
				ghost.update_speed(player_speed)
				
				# 方案3：让Ghost从最新的路径点开始跟随
				# 每个Ghost使用前方目标的最后N个路径点，而不是前面的旧路径点
				var path_offset = (i + 1) * ghost_Interval  # 每个Ghost延迟的路径点数
				
				if i == 0:
					# 第一个Ghost直接使用玩家的最新路径
					if player_path.size() > path_offset:
						# 使用路径末尾的最新路径点
						var start_index = max(0, player_path.size() - ghost_path_length - path_offset)
						var end_index = player_path.size() - path_offset
						var ghost_path = player_path.slice(start_index, end_index)
						ghost.update_path_points(ghost_path)
				else:
					# 后续Ghost使用前一个Ghost的路径
					var prev_ghost = ghosts[i - 1]
					if is_instance_valid(prev_ghost) and "path_history" in prev_ghost:
						var prev_path = prev_ghost.path_history
						if prev_path.size() > path_offset:
							# 使用前一个Ghost路径的最新部分
							var start_index = max(0, prev_path.size() - ghost_path_length - path_offset)
							var end_index = prev_path.size() - path_offset
							var ghost_path = prev_path.slice(start_index, end_index)
							ghost.update_path_points(ghost_path)

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
