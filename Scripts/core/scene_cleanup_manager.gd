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
	
	# 5. 清理所有墓碑
	_cleanup_graves()
	
	# 6. 清理所有特效/动画（duplicate_node的子节点）
	_cleanup_effects()
	
	# 7. 清理root上添加的UI（死亡UI、ESC菜单、救援UI等）
	_cleanup_root_ui()
	
	# 8. 重置GameMain数据
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

## 清理所有墓碑
static func _cleanup_graves() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	# 清理普通墓碑
	var graves = tree.get_nodes_in_group("grave")
	print("[SceneCleanup] 清理 %d 个墓碑" % graves.size())
	
	for grave in graves:
		if is_instance_valid(grave):
			# 调用cleanup方法（如果有）来清理关联的UI等
			if grave.has_method("cleanup"):
				grave.cleanup()
			else:
				grave.queue_free()
	
	# 清理Multi模式墓碑
	var multi_graves = tree.get_nodes_in_group("multi_grave")
	print("[SceneCleanup] 清理 %d 个Multi墓碑" % multi_graves.size())
	
	for grave in multi_graves:
		if is_instance_valid(grave):
			if grave.has_method("cleanup"):
				grave.cleanup()
			else:
				grave.queue_free()

## 清理所有特效/动画（duplicate_node的子节点）
static func _cleanup_effects() -> void:
	# 清理 GameMain.duplicate_node 的所有子节点（特效、动画、粒子等）
	if GameMain and GameMain.duplicate_node and is_instance_valid(GameMain.duplicate_node):
		var child_count = GameMain.duplicate_node.get_child_count()
		print("[SceneCleanup] 清理 %d 个特效/动画" % child_count)
		
		for child in GameMain.duplicate_node.get_children():
			if is_instance_valid(child):
				child.queue_free()

	# 清空特效对象池（池内实例通常不在树上，不清会跨场景残留）
	CombatEffectManager.clear_all_pools()
	print("[SceneCleanup] 已清空 CombatEffectManager 对象池")
	
	# 清空浮动文字对象池（池内实例不在树上，不清会跨场景残留）
	FloatingText.clear_pool()
	print("[SceneCleanup] 已清空 FloatingText 对象池")
	
	# 清理可能残留的粒子特效（通过组）
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var particles = tree.get_nodes_in_group("effect")
		for particle in particles:
			if is_instance_valid(particle):
				particle.queue_free()

## 清理添加到root的UI节点（死亡UI、ESC菜单、救援UI等）
static func _cleanup_root_ui() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var cleaned_count = 0
	
	# 通过组清理死亡UI
	var death_uis = tree.get_nodes_in_group("death_ui")
	for ui in death_uis:
		if is_instance_valid(ui):
			ui.queue_free()
			cleaned_count += 1
	
	# 通过组清理ESC菜单
	var esc_menus = tree.get_nodes_in_group("esc_menu")
	for menu in esc_menus:
		if is_instance_valid(menu):
			menu.queue_free()
			cleaned_count += 1
	
	# 通过组清理救援UI
	var rescue_uis = tree.get_nodes_in_group("rescue_ui")
	for ui in rescue_uis:
		if is_instance_valid(ui):
			ui.queue_free()
			cleaned_count += 1
	
	# 通过类名检查root直接子节点（备用方案）
	var root = tree.root
	if root:
		for child in root.get_children():
			if not is_instance_valid(child):
				continue
			# 检查是否是需要清理的UI类型
			if child is DeathUI or child is ESCMenu:
				child.queue_free()
				cleaned_count += 1
	
	if cleaned_count > 0:
		print("[SceneCleanup] 清理 %d 个root UI节点" % cleaned_count)

## 重置游戏数据
static func _reset_game_data() -> void:
	print("[SceneCleanup] 重置游戏数据")
	
	# 重置GameState状态机（重要！防止状态残留）
	if GameState:
		GameState.reset()
		print("[SceneCleanup] GameState已重置")
	
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

## 安全的场景切换（保留玩家信息，用于胜利/结算场景）
static func change_scene_to_packed_safely_keep_player_info(packed_scene: PackedScene) -> void:
	print("[SceneCleanup] 安全切换到打包场景（保留玩家信息）")
	
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_error("[SceneCleanup] 无法获取场景树")
		return
	
	# 保存玩家信息
	var saved_class_id = ""
	var saved_weapon_ids: Array = []
	var saved_mode = ""
	if GameMain and GameMain.current_session:
		saved_class_id = GameMain.current_session.selected_class_id
		saved_weapon_ids = GameMain.current_session.selected_weapon_ids.duplicate()
		saved_mode = GameMain.current_session.current_mode_id
		print("[SceneCleanup] 保存玩家信息: 职业=%s, 武器数=%d, 模式=%s" % [saved_class_id, saved_weapon_ids.size(), saved_mode])
	
	# 先清理（只清理场景对象，不重置游戏数据）
	_cleanup_ghosts()
	_cleanup_drop_items()
	_cleanup_enemies()
	_cleanup_bullets()
	_cleanup_graves()
	_cleanup_effects()
	_cleanup_root_ui()  # 清理root上的UI
	
	# 等待一帧确保清理完成
	await tree.process_frame
	
	# 恢复玩家信息
	if GameMain and GameMain.current_session and saved_class_id != "":
		GameMain.current_session.selected_class_id = saved_class_id
		GameMain.current_session.selected_weapon_ids = saved_weapon_ids
		GameMain.current_session.current_mode_id = saved_mode
		print("[SceneCleanup] 已恢复玩家信息: 职业=%s" % saved_class_id)
	
	# 切换场景
	var error = tree.change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("[SceneCleanup] 场景切换失败: %d" % error)