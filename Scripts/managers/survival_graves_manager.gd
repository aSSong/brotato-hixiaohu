extends Node
class_name SurvivalGravesManager

## Survival模式墓碑管理器
## 负责在游戏开始时创建初始墓碑（Betty职业 + 冲锋枪 + 魔力飞弹）
## 注意：作为场景节点使用，不使用autoload

## 初始墓碑位置（固定）
const INITIAL_GRAVE_POSITION: Vector2 = Vector2(800, 950)

## 初始墓碑配置
const INITIAL_CLASS_ID: String = "betty"
const INITIAL_WEAPONS: Array = [
	{"id": "machine_gun", "level": 1},
	{"id": "arcane_missile", "level": 1}
]

## 预加载墓碑场景
var grave_scene: PackedScene = preload("res://scenes/players/grave.tscn")

## 初始墓碑实例
var initial_grave: Grave = null

## 父节点引用（用于添加墓碑）
var parent_node: Node2D = null

## 玩家引用
var player: CharacterBody2D = null

func _ready() -> void:
	# 添加到组中方便查找
	add_to_group("survival_graves_manager")
	print("[SurvivalGravesManager] 初始化")

## 设置父节点（用于添加墓碑）
func set_parent_node(node: Node2D) -> void:
	parent_node = node
	if node:
		print("[SurvivalGravesManager] 设置父节点:", node.name)
	else:
		print("[SurvivalGravesManager] 设置父节点: null")

## 设置玩家引用
func set_player(p: CharacterBody2D) -> void:
	player = p
	if p:
		print("[SurvivalGravesManager] 设置玩家引用")

## 创建初始墓碑（Betty职业 + 冲锋枪 + 魔力飞弹）
func spawn_initial_grave() -> void:
	if not parent_node:
		push_error("[SurvivalGravesManager] 父节点未设置，无法创建墓碑")
		return
	
	if not player:
		push_error("[SurvivalGravesManager] 玩家未设置，无法创建墓碑")
		return
	
	# 如果已有初始墓碑，先清除
	if initial_grave and is_instance_valid(initial_grave):
		initial_grave.cleanup()
		initial_grave = null
	
	# 创建GhostData
	var ghost_data = GhostData.new()
	ghost_data.class_id = INITIAL_CLASS_ID
	ghost_data.weapons = INITIAL_WEAPONS.duplicate(true)
	ghost_data.player_name = SaveManager.get_player_name()
	ghost_data.total_death_count = 0  # 显示"第0世"
	ghost_data.death_position = INITIAL_GRAVE_POSITION
	
	# 实例化墓碑场景
	initial_grave = grave_scene.instantiate()
	initial_grave.global_position = INITIAL_GRAVE_POSITION
	
	# 添加到场景
	parent_node.add_child(initial_grave)
	
	# 设置墓碑数据
	initial_grave.setup(ghost_data, player)
	
	# 连接信号
	initial_grave.rescue_requested.connect(_on_grave_rescue_requested)
	initial_grave.transcend_requested.connect(_on_grave_transcend_requested)
	initial_grave.rescue_cancelled.connect(_on_grave_rescue_cancelled)
	
	print("[SurvivalGravesManager] 初始墓碑已创建: %s 第%d世 于 %s" % [ghost_data.player_name, ghost_data.total_death_count, INITIAL_GRAVE_POSITION])

## 墓碑救援请求回调
func _on_grave_rescue_requested(ghost_data: GhostData) -> void:
	print("[SurvivalGravesManager] 收到墓碑救援请求")
	
	# 检查masterkey
	if GameMain.master_key < 2:
		print("[SurvivalGravesManager] Master Key不足")
		_restore_game_state()
		return
	
	# 消耗masterkey
	GameMain.master_key -= 2
	print("[SurvivalGravesManager] 消耗2个Master Key，剩余:", GameMain.master_key)
	
	# 创建Ghost
	_create_ghost_from_data(ghost_data)
	
	# 清理墓碑
	_clear_initial_grave()
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[SurvivalGravesManager] 救援完成")

## 墓碑超度请求回调
func _on_grave_transcend_requested(_ghost_data: GhostData) -> void:
	print("[SurvivalGravesManager] 收到墓碑超度请求")
	
	# 清理墓碑
	_clear_initial_grave()
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[SurvivalGravesManager] 超度完成")

## 墓碑救援取消回调
func _on_grave_rescue_cancelled() -> void:
	print("[SurvivalGravesManager] 墓碑救援取消")

## 恢复游戏状态
func _restore_game_state() -> void:
	if GameState.previous_state == GameState.State.WAVE_FIGHTING or GameState.previous_state == GameState.State.WAVE_CLEARING:
		GameState.change_state(GameState.previous_state)
	else:
		GameState.change_state(GameState.State.WAVE_FIGHTING)

## 从数据创建Ghost
func _create_ghost_from_data(ghost_data: GhostData) -> void:
	if not ghost_data:
		push_error("[SurvivalGravesManager] Ghost数据为空")
		return
	
	print("[SurvivalGravesManager] 开始创建Ghost，职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())
	
	# 获取GhostManager
	var ghost_manager = get_tree().get_first_node_in_group("ghost_manager")
	if not ghost_manager:
		push_error("[SurvivalGravesManager] 找不到GhostManager")
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
	
	print("[SurvivalGravesManager] Ghost创建成功！职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())

## 清理初始墓碑
func _clear_initial_grave() -> void:
	if initial_grave and is_instance_valid(initial_grave):
		initial_grave.cleanup()
		initial_grave = null
		print("[SurvivalGravesManager] 初始墓碑已清理")

## 节点移除时清理
func _exit_tree() -> void:
	_clear_initial_grave()
	print("[SurvivalGravesManager] 已清理")

