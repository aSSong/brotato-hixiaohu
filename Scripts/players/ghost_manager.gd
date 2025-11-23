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
				# 基础速度
				var current_speed = player_speed
				
				# 速度补偿逻辑：如果距离目标过远，加速追赶
				var target_node = player
				if i > 0:
					target_node = ghosts[i-1]
					
				if is_instance_valid(target_node):
					var distance_to_target = ghost.global_position.distance_to(target_node.global_position)
					var follow_distance = ghost.follow_distance
					# 如果距离超过 1.3 倍跟随距离，开始加速
					if distance_to_target > follow_distance * 1.3:
						# 根据距离比例加速，最大 2 倍速
						var boost = clamp(distance_to_target / follow_distance, 1.0, 2.0)
						current_speed *= boost
				
				ghost.update_speed(current_speed)

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
