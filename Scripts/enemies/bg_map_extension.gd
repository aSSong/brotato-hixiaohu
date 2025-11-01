extends Node2D
## bg_map场景扩展脚本
## 在场景加载时动态添加升级商店

func _ready() -> void:
	# 动态加载并添加升级商店
	var upgrade_shop_scene = load("res://scenes/UI/upgrade_shop.tscn")
	if upgrade_shop_scene:
		var upgrade_shop = upgrade_shop_scene.instantiate()
		add_child(upgrade_shop)
		upgrade_shop.name = "upgrade_shop"
		print("升级商店已添加")
	else:
		push_error("无法加载升级商店场景！")

