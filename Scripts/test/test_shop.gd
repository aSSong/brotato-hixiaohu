extends Control

## 商店测试场景
## 直接运行此场景即可测试商店 (F6)
##
## 快捷键：
## G - 加 50 金币
## R - 刷新商店选项
## W - 添加一把武器
## Space - 重新打开商店
## ESC - 关闭商店/退出

@onready var now_weapons: Node2D = $NowWeapons
@onready var upgrade_shop: UpgradeShop = $UpgradeShop

## 测试用武器列表
var test_weapons = ["pistol", "sword", "fireball", "rifle", "axe", "dagger"]
var current_weapon_index = 0

func _ready() -> void:
	# 模拟游戏数据
	GameMain.gold = 100
	GameMain.selected_class_id = "betty"  # 使用一个存在的职业ID
	GameMain.selected_weapon_ids = []  # 清空，避免 NowWeapons 自动初始化
	
	print("========== 商店测试场景 ==========")
	print("快捷键：")
	print("  G - 加 50 金币")
	print("  R - 刷新商店选项")
	print("  W - 添加一把武器")
	print("  Space - 重新打开商店")
	print("  ESC - 关闭商店/退出")
	print("===================================")
	
	# 等待武器管理器初始化
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 手动添加测试武器
	await _add_test_weapons()
	
	# 打开商店
	await get_tree().process_frame
	upgrade_shop.open_shop()

func _add_test_weapons() -> void:
	# 添加2把初始测试武器
	if now_weapons.has_method("add_weapon"):
		await now_weapons.add_weapon("pistol", 1)
		current_weapon_index = 1
		await now_weapons.add_weapon("sword", 2)
		current_weapon_index = 2
		print("[TestShop] 已添加初始武器: pistol(Lv1), sword(Lv2)")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				# R 键刷新商店
				print("[TestShop] 刷新商店选项...")
				await upgrade_shop.generate_upgrades()
			KEY_G:
				# G 键加金币
				GameMain.gold += 50
				print("[TestShop] 当前金币: ", GameMain.gold)
			KEY_W:
				# W 键添加武器
				await _add_next_weapon()
			KEY_ESCAPE:
				# ESC 关闭商店或退出
				if upgrade_shop.visible:
					upgrade_shop.close_shop()
					print("[TestShop] 商店已关闭")
				else:
					print("[TestShop] 退出测试")
					get_tree().quit()
			KEY_SPACE:
				# 空格 重新打开商店
				if not upgrade_shop.visible:
					print("[TestShop] 重新打开商店...")
					upgrade_shop.open_shop()

func _add_next_weapon() -> void:
	if current_weapon_index >= test_weapons.size():
		print("[TestShop] 已达到武器上限或测试武器用完")
		return
	
	if now_weapons.has_method("add_weapon"):
		var weapon_id = test_weapons[current_weapon_index]
		var level = (current_weapon_index % 5) + 1  # 等级 1-5 循环
		await now_weapons.add_weapon(weapon_id, level)
		current_weapon_index += 1
		print("[TestShop] 添加武器: %s (Lv%d), 当前武器数: %d" % [weapon_id, level, current_weapon_index])
		
		# 更新商店的武器列表显示
		upgrade_shop._update_weapon_list()
