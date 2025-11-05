class_name GhostFactory extends Node

## Ghost工厂
## 简化Ghost创建流程，消除复杂的异步逻辑

## Ghost场景预加载
static var ghost_scene = preload("res://scenes/players/ghost.tscn")

## 创建Ghost实例
## @param follow_target: 跟随目标（玩家或前一个Ghost）
## @param index: Ghost在队列中的索引
## @param player_speed: 玩家当前速度
## @param ghost_data: Ghost数据（可选，为null则生成随机数据）
static func create_ghost(follow_target: Node2D, index: int, player_speed: float, ghost_data: GhostData = null) -> Ghost:
	print("[GhostFactory] 创建Ghost | 索引: %d, 速度: %.1f" % [index, player_speed])
	
	# 实例化Ghost场景
	var ghost = ghost_scene.instantiate()
	if not ghost:
		push_error("[GhostFactory] 无法实例化Ghost场景")
		return null
	
	# 如果没有提供数据，生成随机数据
	if not ghost_data:
		ghost_data = GhostData.generate_random()
		print("[GhostFactory] 生成随机Ghost数据 | 职业: %s, 武器数: %d" % [ghost_data.class_id, ghost_data.weapons.size()])
	
	# 设置基本属性（在添加到场景树之前）
	ghost.follow_target = follow_target
	ghost.queue_index = index
	ghost.follow_speed = player_speed
	ghost.class_id = ghost_data.class_id
	ghost.ghost_weapons = ghost_data.weapons.duplicate(true)  # 深拷贝
	
	print("[GhostFactory] Ghost创建完成 | 职业: %s" % ghost_data.class_id)
	return ghost

## 从现有玩家数据创建Ghost
## @param follow_target: 跟随目标
## @param index: Ghost索引
## @param player: 玩家引用
## @param death_count: 死亡次数（用于标识）
static func create_ghost_from_player(follow_target: Node2D, index: int, player: CharacterBody2D, death_count: int) -> Ghost:
	# 从玩家生成Ghost数据
	var ghost_data = GhostData.from_player(player, death_count)
	var player_speed = player.speed if "speed" in player else GameConfig.base_speed
	
	return create_ghost(follow_target, index, player_speed, ghost_data)

## 批量创建Ghost
## @param base_target: 第一个Ghost的跟随目标（通常是玩家）
## @param count: 要创建的Ghost数量
## @param player_speed: 玩家速度
## @return: Ghost数组
static func create_ghost_chain(base_target: Node2D, count: int, player_speed: float) -> Array[Ghost]:
	var ghosts: Array[Ghost] = []
	
	var current_target = base_target
	for i in range(count):
		var ghost = create_ghost(current_target, i, player_speed)
		if ghost:
			ghosts.append(ghost)
			current_target = ghost  # 下一个Ghost跟随这个Ghost
		else:
			push_error("[GhostFactory] 创建第 %d 个Ghost失败" % (i + 1))
			break
	
	print("[GhostFactory] 批量创建完成 | 数量: %d/%d" % [ghosts.size(), count])
	return ghosts

