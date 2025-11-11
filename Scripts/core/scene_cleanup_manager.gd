extends Node
class_name SceneCleanupManager

## 场景清理管理器
## 在场景切换前清理所有运行时数据和对象

## 清理场景中的所有运行时对象
static func cleanup_game_scene() -> void:
	print("[SceneCleanup] ========== 开始清理游戏场景 ==========")
	
	# 1. 清理所有Ghost
	_cleanup_ghosts()
	
	# 2. 清理所有掉落物
	_cleanup_drop_items()
	
	# 3. 清理所有敌人
	_cleanup_enemies()
	
	# 4. 清理所有子弹
	_cleanup_bullets()
	
	# 5. 重置GameMain数据
	_reset_game_data()
	
	print("[SceneCleanup] ========== 场景清理完成 ==========")

## 清理所有Ghost
static func _cleanup_ghosts() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var ghosts = tree.get_nodes_in_group("ghost")
	print("[SceneCleanup] 清理 %d 个Ghost" % ghosts.size())
	
	for ghost in ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()

## 清理所有掉落物
static func _cleanup_drop_items() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var items = tree.get_nodes_in_group("drop_item")
	print("[SceneCleanup] 清理 %d 个掉落物" % items.size())
	
	for item in items:
		if is_instance_valid(item):
			item.queue_free()

## 清理所有敌人
static func _cleanup_enemies() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var enemies = tree.get_nodes_in_group("enemy")
	print("[SceneCleanup] 清理 %d 个敌人" % enemies.size())
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

## 清理所有子弹
static func _cleanup_bullets() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var bullets = tree.get_nodes_in_group("bullet")
	print("[SceneCleanup] 清理 %d 个子弹" % bullets.size())
	
	for bullet in bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()

## 重置游戏数据
static func _reset_game_data() -> void:
	print("[SceneCleanup] 重置游戏数据")
	
	# 重置GameMain
	if GameMain:
		GameMain.reset_game()
	
	# 如果有会话系统，也重置会话
	if GameMain and "current_session" in GameMain and GameMain.current_session:
		GameMain.current_session.reset()

## 安全的场景切换（带清理）
static func change_scene_safely(scene_path: String) -> void:
	print("[SceneCleanup] 安全切换场景到: %s" % scene_path)
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("[SceneCleanup] 无法获取场景树")
		return
	
	# 先清理
	cleanup_game_scene()
	
	# 等待一帧确保清理完成
	await tree.process_frame
	
	# 切换场景
	var error = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneCleanup] 场景切换失败: %d" % error)

## 安全的场景切换（使用PackedScene）
static func change_scene_to_packed_safely(packed_scene: PackedScene) -> void:
	print("[SceneCleanup] 安全切换到打包场景")
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("[SceneCleanup] 无法获取场景树")
		return
	
	# 先清理
	cleanup_game_scene()
	
	# 等待一帧确保清理完成
	await tree.process_frame
	
	# 切换场景
	var error = tree.change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("[SceneCleanup] 场景切换失败: %d" % error)

## 安全的场景切换（保留模式信息）
static func change_scene_safely_keep_mode(scene_path: String) -> void:
	print("[SceneCleanup] 安全切换场景（保留模式）到: %s" % scene_path)
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("[SceneCleanup] 无法获取场景树")
		return
	
	# 保存模式和地图信息
	var saved_mode = ""
	var saved_map = ""
	if GameMain and GameMain.current_session:
		saved_mode = GameMain.current_session.current_mode_id
		saved_map = GameMain.current_session.current_map_id
		print("[SceneCleanup] 保存模式: %s, 地图: %s" % [saved_mode, saved_map])
	
	# 先清理
	cleanup_game_scene()
	
	# 等待一帧确保清理完成
	await tree.process_frame
	
	# 恢复模式信息（在reset之后立即恢复）
	if GameMain and GameMain.current_session and saved_mode != "":
		GameMain.current_session.current_mode_id = saved_mode
		GameMain.current_session.current_map_id = saved_map
		print("[SceneCleanup] 已恢复模式: %s, 地图: %s" % [saved_mode, saved_map])
	
	# 切换场景
	var error = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneCleanup] 场景切换失败: %d" % error)