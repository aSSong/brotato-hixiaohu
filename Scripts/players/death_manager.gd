extends Node
class_name DeathManager

## 死亡管理器
## 管理玩家死亡、复活逻辑和复活次数

## 信号
signal player_died  # 玩家死亡
signal player_revived  # 玩家复活
signal game_over  # 游戏结束（玩家放弃）

## 引用
var player: CharacterBody2D = null
var death_ui: DeathUI = null
var floor_layer: TileMapLayer = null
var grave_sprite: Sprite2D = null  # 墓碑精灵
var grave_ghost_data: GhostData = null  # 墓碑关联的Ghost数据
var grave_rescue_manager: GraveRescueManager = null  # 墓碑救援管理器

## 状态
var is_dead: bool = false
var revive_count: int = 0  # 本局累计复活次数
var death_count: int = 0  # 本局累计死亡次数（包括已复活的）
var death_timer: float = 0.0
var death_delay: float = 1.5  # 死亡延迟时间
var death_position: Vector2 = Vector2.ZERO  # 记录死亡位置

func _ready() -> void:
	# 添加到组中方便查找
	add_to_group("death_manager")
	
	print("[DeathManager] 初始化")

## 节点被移除时清理墓碑
func _exit_tree() -> void:
	_remove_grave()
	print("[DeathManager] 已清理")

## 设置玩家引用
func set_player(p: CharacterBody2D) -> void:
	player = p
	
	# 连接玩家HP信号
	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
	
	print("[DeathManager] 设置玩家引用")

## 设置死亡UI
func set_death_ui(ui: DeathUI) -> void:
	death_ui = ui
	
	# 连接UI信号
	if death_ui:
		death_ui.revive_requested.connect(_on_revive_requested)
		death_ui.give_up_requested.connect(_on_give_up_requested)
	
	print("[DeathManager] 设置死亡UI")

## 设置地图层（用于随机复活位置）
func set_floor_layer(layer: TileMapLayer) -> void:
	floor_layer = layer
	print("[DeathManager] 设置地图层")

func _process(delta: float) -> void:
	# 处理死亡延迟计时
	if is_dead and death_timer > 0:
		death_timer -= delta
		
		if death_timer <= 0:
			_show_death_ui()

## 玩家HP变化回调
func _on_player_hp_changed(current_hp: int, _max_hp: int) -> void:
	if current_hp <= 0 and not is_dead:
		_trigger_death()

## 触发死亡
func _trigger_death() -> void:
	if is_dead:
		return
	
	is_dead = true
	death_timer = death_delay
	death_count += 1  # 增加死亡次数
	
	# 记录死亡位置
	if player:
		death_position = player.global_position
	
	# 强制停止之前的救援读条（如果有）
	if grave_rescue_manager and is_instance_valid(grave_rescue_manager):
		grave_rescue_manager.force_stop_reading()
	
	# 创建Ghost数据（用于救援）
	if player:
		grave_ghost_data = GhostData.from_player(player, death_count)
		print("[DeathManager] 创建Ghost数据 | 职业:", grave_ghost_data.class_id, " 武器数:", grave_ghost_data.weapons.size())
	
	# 移除旧墓碑（如果有）
	_remove_old_grave()
	
	# 创建新墓碑
	_create_grave()
	
	# 禁止玩家移动
	if player:
		player.canMove = false
	
	player_died.emit()
	print("[DeathManager] 玩家死亡！", death_delay, "秒后显示死亡界面...")
	print("[DeathManager] 当前复活次数:", revive_count, " 死亡次数:", death_count)

## 创建墓碑
func _create_grave() -> void:
	# 加载墓碑纹理
	var grave_texture = load("res://assets/others/grave.png")
	if not grave_texture:
		push_error("[DeathManager] 无法加载墓碑纹理！")
		return
	
	# 创建墓碑精灵
	grave_sprite = Sprite2D.new()
	grave_sprite.texture = grave_texture
	grave_sprite.global_position = death_position
	
	# 设置层级（高于玩家和怪物）
	grave_sprite.z_index = 20
	
	# 添加到当前场景而不是root（避免场景切换后残留）
	if player and player.get_parent():
		player.get_parent().add_child(grave_sprite)
		print("[DeathManager] 墓碑已创建于:", death_position)
		
		# 创建救援管理器
		_create_rescue_manager()
	else:
		push_warning("[DeathManager] 无法找到合适的父节点放置墓碑")

## 创建救援管理器
func _create_rescue_manager() -> void:
	if not grave_sprite or not grave_ghost_data:
		return
	
	# 创建救援管理器
	grave_rescue_manager = GraveRescueManager.new()
	
	# 添加到场景
	if player and player.get_parent():
		player.get_parent().add_child(grave_rescue_manager)
	
	# 设置引用
	grave_rescue_manager.set_player(player)
	grave_rescue_manager.set_grave(grave_sprite)
	grave_rescue_manager.set_ghost_data(grave_ghost_data)
	grave_rescue_manager.set_death_manager(self)
	
	# 初始化位置
	grave_rescue_manager.update_position()
	
	print("[DeathManager] 救援管理器已创建")

## 移除墓碑
func _remove_grave() -> void:
	# 移除救援管理器
	if grave_rescue_manager and is_instance_valid(grave_rescue_manager):
		grave_rescue_manager.cleanup()
		grave_rescue_manager = null
	
	# 移除墓碑精灵
	if grave_sprite and is_instance_valid(grave_sprite):
		grave_sprite.queue_free()
		grave_sprite = null
		print("[DeathManager] 墓碑已移除")

## 移除旧墓碑（再次死亡时清除上一个墓碑）
func _remove_old_grave() -> void:
	# 移除救援管理器
	if grave_rescue_manager and is_instance_valid(grave_rescue_manager):
		grave_rescue_manager.cleanup()
		grave_rescue_manager = null
	
	# 移除墓碑精灵
	if grave_sprite and is_instance_valid(grave_sprite):
		grave_sprite.queue_free()
		grave_sprite = null
		# 注意：不清除grave_ghost_data，因为新的数据已经在_trigger_death()中创建
		print("[DeathManager] 旧墓碑已移除")

## 显示死亡UI
func _show_death_ui() -> void:
	if not death_ui:
		push_error("[DeathManager] 死亡UI未设置！")
		return
	
	# 暂停游戏
	get_tree().paused = true
	
	# 显示死亡界面
	var current_gold = GameMain.gold
	death_ui.show_death_screen(revive_count, current_gold)
	
	print("[DeathManager] 显示死亡UI | 钥匙:", current_gold, " 复活费用:", 5 * (revive_count + 1))

## 复活请求
func _on_revive_requested() -> void:
	var cost = 5 * (revive_count + 1)
	
	# 检查钥匙是否足够
	if GameMain.gold < cost:
		push_warning("[DeathManager] 钥匙不足，无法复活")
		return
	
	# 扣除钥匙
	GameMain.remove_gold(cost)
	
	# 增加复活次数
	revive_count += 1
	
	# 复活玩家
	_revive_player()
	
	print("[DeathManager] 玩家复活！花费:", cost, " 剩余钥匙:", GameMain.gold, " 累计复活次数:", revive_count)

## 放弃请求
func _on_give_up_requested() -> void:
	print("[DeathManager] 玩家放弃游戏")
	
	# 移除墓碑
	_remove_grave()
	
	# 恢复游戏（需要在切换场景前恢复）
	get_tree().paused = false
	
	# 发出游戏结束信号
	game_over.emit()
	
	# 等待一下再切换场景
	await get_tree().create_timer(0.1).timeout
	
	# 使用安全的场景切换（带清理）
	await SceneCleanupManager.change_scene_safely("res://scenes/UI/main_title.tscn")

## 复活玩家
func _revive_player() -> void:
	if not player:
		return
	
	# 注意：不移除墓碑！墓碑保留用于救援
	
	# 恢复HP
	player.now_hp = player.max_hp
	player.hp_changed.emit(player.now_hp, player.max_hp)
	
	# 随机复活位置
	_respawn_player_at_random_position()
	
	# 允许移动和行动
	player.canMove = true
	player.stop = false
	
	# 显示玩家
	player.visible = true
	
	# 启用武器
	if player.has_method("enable_weapons"):
		player.enable_weapons()
	
	# 重置死亡状态
	is_dead = false
	death_timer = 0.0
	
	# 恢复游戏
	get_tree().paused = false
	
	# 发出复活信号
	player_revived.emit()
	
	print("[DeathManager] 玩家已复活 | HP:", player.now_hp, "/", player.max_hp, " 位置:", player.global_position)
	print("[DeathManager] 墓碑保留用于救援")

## 在随机位置复活玩家
func _respawn_player_at_random_position() -> void:
	if not player or not floor_layer:
		push_warning("[DeathManager] 无法随机复活：player或floor_layer未设置")
		return
	
	var used_cells = floor_layer.get_used_cells()
	if used_cells.is_empty():
		push_warning("[DeathManager] 地图没有可用格子")
		return
	
	# 随机选择一个位置
	var max_attempts = 50
	for attempt in max_attempts:
		var random_cell = used_cells[randi() % used_cells.size()]
		var world_pos = floor_layer.map_to_local(random_cell) * 6  # 假设缩放为6
		
		# 简单检查：确保不在太边缘
		# 可以添加更复杂的检查，比如距离敌人的距离
		player.global_position = world_pos
		print("[DeathManager] 复活位置:", world_pos)
		return
	
	push_warning("[DeathManager] 未能找到合适的复活位置，使用原地复活")

## 重置游戏数据（仅在放弃时调用）
func _reset_game_data() -> void:
	revive_count = 0
	death_count = 0
	is_dead = false
	death_timer = 0.0
	
	# 清除墓碑和Ghost数据
	_remove_grave()
	grave_ghost_data = null
	
	print("[DeathManager] 死亡管理器数据已重置")

## 获取当前复活次数
func get_revive_count() -> int:
	return revive_count

## 获取下次复活费用
func get_next_revive_cost() -> int:
	return 5 * (revive_count + 1)
