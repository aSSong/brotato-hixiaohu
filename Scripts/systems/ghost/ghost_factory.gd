class_name GhostFactory

## Ghost工厂 - 统一Ghost创建流程

static var ghost_scene = preload("res://scenes/players/ghost.tscn")

## 创建Ghost实例
## @param follow_target 跟随的目标（玩家或前一个Ghost）
## @param queue_index Ghost在队列中的位置（用于计算位置和颜色）
## @param player_speed 玩家当前速度
## @param ghost_data 可选的Ghost数据（用于复活）
static func create_ghost(follow_target: Node2D, queue_index: int, player_speed: float, ghost_data = null) -> Node:
	var new_ghost = ghost_scene.instantiate()
	if not new_ghost:
		push_error("[GhostFactory] 无法实例化Ghost场景")
		return null
	
	# 如果有现有数据（复活场景）
	if ghost_data and ghost_data.has("class_id"):
		new_ghost.class_id = ghost_data.class_id
		if ghost_data.has("weapons"):
			new_ghost.ghost_weapons = ghost_data.weapons
		new_ghost.initialize(follow_target, queue_index, player_speed, true)
	else:
		# 新Ghost（普通创建）
		new_ghost.initialize(follow_target, queue_index, player_speed, false)
	
	return new_ghost

## 从GhostData创建Ghost（用于复活系统）
static func create_ghost_from_data(follow_target: Node2D, queue_index: int, player_speed: float, data) -> Node:
	var ghost_dict = {
		"class_id": data.class_id if data.has("class_id") else "",
		"weapons": data.weapons if data.has("weapons") else []
	}
	return create_ghost(follow_target, queue_index, player_speed, ghost_dict)
