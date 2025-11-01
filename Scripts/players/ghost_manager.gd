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

func _ready() -> void:
	# 添加到组中以便查找
	add_to_group("ghost_manager")

func _process(delta: float) -> void:
	# 同步所有Ghost的速度与玩家速度
	if player and is_instance_valid(player):
		var player_speed = _get_player_speed()
		for ghost in ghosts:
			if is_instance_valid(ghost):
				ghost.update_speed(player_speed)

## 设置玩家引用
func set_player(p: Node2D) -> void:
	player = p

## 创建新的Ghost
func spawn_ghost() -> void:
	if player == null or not is_instance_valid(player):
		push_error("玩家引用无效，无法创建Ghost")
		return
	
	# 实例化Ghost
	var new_ghost = ghost_scene.instantiate()
	
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
	
	# 添加到场景树
	get_tree().root.add_child(new_ghost)
	
	# 初始化Ghost
	new_ghost.initialize(follow_target, queue_index, player_speed)
	
	# 添加到列表
	ghosts.append(new_ghost)
	
	print("Ghost创建成功！当前Ghost数量: %d" % ghosts.size())

## 获取玩家速度
func _get_player_speed() -> float:
	if player == null or not is_instance_valid(player):
		return 400.0  # 默认速度
	
	# 尝试获取玩家的speed属性
	#if player.has("speed"):
		#return player.speed
	
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
