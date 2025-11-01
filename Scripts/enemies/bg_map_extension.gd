extends Node2D
## bg_map场景扩展脚本
## 在场景加载时动态添加升级商店

func _ready() -> void:
	# 等待一帧确保场景树完全初始化
	await get_tree().process_frame
	
	# 动态加载并添加升级商店
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
			print("升级商店已添加到CanvasLayer (game_ui)")
		else:
			# 如果找不到game_ui，创建新的CanvasLayer
			var canvas_layer = CanvasLayer.new()
			canvas_layer.name = "UpgradeShopLayer"
			get_tree().root.add_child(canvas_layer)
			canvas_layer.add_child(upgrade_shop)
			print("升级商店已添加到新CanvasLayer")
		
		upgrade_shop.name = "upgrade_shop"
		
		# 确保添加到组中（场景文件中应该已经有，但确保一下）
		if not upgrade_shop.is_in_group("upgrade_shop"):
			upgrade_shop.add_to_group("upgrade_shop")
		
		print("升级商店已添加，节点路径: ", upgrade_shop.get_path())
		print("升级商店是否在组中: ", upgrade_shop.is_in_group("upgrade_shop"))
	else:
		push_error("无法加载升级商店场景！")

