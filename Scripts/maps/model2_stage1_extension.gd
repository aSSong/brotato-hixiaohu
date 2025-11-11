extends Node2D
## model_2_stage_1场景扩展脚本
## 在场景加载时动态添加升级商店和MultiGravesManager

func _ready() -> void:
	# 等待一帧确保场景树完全初始化
	await get_tree().process_frame
	
	# 初始化游戏系统（DeathManager等）
	_setup_game_initializer()
	
	# 动态加载并添加升级商店（与原模式一致）
	_setup_upgrade_shop()
	
	# Multi模式特有：初始化MultiGravesManager
	_setup_multi_graves_manager()

## 设置游戏初始化器（创建DeathManager等）
func _setup_game_initializer() -> void:
	var game_initializer = preload("res://Scripts/game_initializer.gd").new()
	game_initializer.name = "GameInitializer"
	add_child(game_initializer)
	print("[Model2Stage1] GameInitializer已创建")

## 设置升级商店（与bg_map_extension一致）
func _setup_upgrade_shop() -> void:
	var upgrade_shop_scene = load("res://scenes/UI/upgrade_shop.tscn")
	if upgrade_shop_scene:
		var upgrade_shop = upgrade_shop_scene.instantiate()
		
		# 尝试添加到CanvasLayer（game_ui）而不是bg_map
		var game_ui = get_tree().get_first_node_in_group("game_ui")
		if not game_ui:
			# 通过名称查找
			game_ui = get_tree().root.find_child("game_ui", true, false)
		
		if game_ui:
			# 添加到CanvasLayer（game_ui）
			game_ui.add_child(upgrade_shop)
			print("[Model2Stage1] 升级商店已添加到CanvasLayer (game_ui)")
		else:
			# 如果找不到game_ui，创建新的CanvasLayer
			var canvas_layer = CanvasLayer.new()
			canvas_layer.name = "UpgradeShopLayer"
			get_tree().root.add_child(canvas_layer)
			canvas_layer.add_child(upgrade_shop)
			print("[Model2Stage1] 升级商店已添加到新CanvasLayer")
		
		upgrade_shop.name = "upgrade_shop"
		
		# 确保添加到组中
		if not upgrade_shop.is_in_group("upgrade_shop"):
			upgrade_shop.add_to_group("upgrade_shop")
		
		print("[Model2Stage1] 升级商店已添加")
	else:
		push_error("[Model2Stage1] 无法加载升级商店场景！")

## 设置MultiGravesManager（Multi模式特有）
func _setup_multi_graves_manager() -> void:
	# 创建MultiGravesManager实例
	var graves_manager = MultiGravesManager.new()
	graves_manager.name = "MultiGravesManager"
	
	# 添加到当前场景
	add_child(graves_manager)
	
	# 设置父节点（墓碑将添加到这里）
	graves_manager.set_parent_node(self)
	
	# 查找并设置玩家引用
	await get_tree().process_frame  # 等待玩家初始化
	var player = get_tree().get_first_node_in_group("player")
	if player:
		graves_manager.set_player(player)
		print("[Model2Stage1] MultiGravesManager已初始化，玩家引用已设置")
	else:
		push_warning("[Model2Stage1] 未找到玩家节点")
	
	print("[Model2Stage1] MultiGravesManager已创建")

