extends Control
class_name UpgradeShop

## 升级商店
## 每波结束后弹出，允许玩家购买升级

@onready var upgrade_container: VBoxContainer = %UpgradeContainer
@onready var refresh_button: Button = %RefreshButton
@onready var close_button: Button = %CloseButton
@onready var refresh_cost_label: Label = %RefreshCostLabel

## 当前显示的升级选项（最多3个）
var current_upgrades: Array[UpgradeData] = []
var refresh_cost: int = 2  # 刷新费用，每次x2
var base_refresh_cost: int = 2  # 基础刷新费用

## 武器相关参数
var new_weapon_cost: int = 5 # 新武器基础价格
#var green_weapon_multi: int = 2 #绿色武器价格倍率

## 信号
signal upgrade_purchased(upgrade: UpgradeData)
signal shop_closed()

## 升级选项预制（用于UI显示）
var upgrade_option_scene = preload("res://scenes/UI/upgrade_option.tscn")

func _ready() -> void:
	# 确保在组中
	if not is_in_group("upgrade_shop"):
		add_to_group("upgrade_shop")
		print("升级商店手动添加到组: upgrade_shop")
	
	# 等待一帧确保所有@onready变量都已初始化
	await get_tree().process_frame
	
	# 验证@onready变量是否初始化
	if not upgrade_container:
		push_error("upgrade_container 未初始化！")
		# 尝试手动查找
		upgrade_container = get_node_or_null("%UpgradeContainer")
		if upgrade_container:
			print("手动找到 upgrade_container: ", upgrade_container.get_path())
		else:
			push_error("无法找到 UpgradeContainer 节点！")
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	else:
		refresh_button = get_node_or_null("%RefreshButton")
		if refresh_button:
			refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	else:
		close_button = get_node_or_null("%CloseButton")
		if close_button:
			close_button.pressed.connect(_on_close_button_pressed)
	
	_update_refresh_cost_display()
	hide()  # 初始隐藏
	print("升级商店 _ready() 完成，节点路径: ", get_path(), " 组: ", get_groups())
	print("upgrade_container: ", upgrade_container, " refresh_button: ", refresh_button, " close_button: ", close_button)

## 打开商店
func open_shop() -> void:
	print("升级商店 open_shop() 被调用")
	print("当前可见性: ", visible, " 是否在树中: ", is_inside_tree())
	
	# 确保所有@onready变量都已初始化
	if not is_inside_tree():
		await get_tree().process_frame
	
	# 设置进程模式为始终处理（即使在暂停时）
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 暂停游戏
	get_tree().paused = true
	
	# 显示商店（必须在暂停后）
	show()
	visible = true
	
	# 确保节点可见
	set_process(true)
	set_process_input(true)
	
	# 重置刷新费用
	refresh_cost = base_refresh_cost
	_update_refresh_cost_display()
	
	# 确保容器可用
	if not upgrade_container:
		upgrade_container = get_node_or_null("%UpgradeContainer")
		if upgrade_container:
			print("在open_shop中找到upgrade_container: ", upgrade_container.get_path())
		else:
			push_error("无法找到 UpgradeContainer 节点！")
			return
	
	print("容器子节点数（生成前）: ", upgrade_container.get_child_count())
	
	# 生成初始升级选项（异步，需要等待）
	await generate_upgrades()
	
	print("升级商店已打开，选项数量: ", current_upgrades.size())
	print("容器子节点数（生成后）: ", upgrade_container.get_child_count())
	print("打开后可见性: ", visible, " process_mode: ", process_mode)

## 关闭商店
func close_shop() -> void:
	hide()
	# 恢复游戏
	get_tree().paused = false
	shop_closed.emit()

## 生成升级选项（3个）
func generate_upgrades() -> void:
	# 注意：这是一个异步函数，会等待所有选项创建完成
	# 清除现有选项
	_clear_upgrades()
	
	# 获取当前武器管理器
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		# 尝试查找now_weapons节点
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	var available_upgrades = _get_available_upgrades(weapons_manager)
	
	# 随机选择3个（避免重复）
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var selected: Array[UpgradeData] = []
	var used_indices = {}
	var attempts = 0
	while selected.size() < 3 and attempts < 100 and available_upgrades.size() > 0:
		var random_index = rng.randi_range(0, available_upgrades.size() - 1)
		
		if used_indices.has(random_index):
			attempts += 1
			continue
		
		var random_upgrade = available_upgrades[random_index]
		
		# 检查是否重复（考虑类型和武器ID）
		var is_duplicate = false
		for existing in selected:
			if existing.upgrade_type == random_upgrade.upgrade_type:
				if random_upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or random_upgrade.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
					if existing.weapon_id == random_upgrade.weapon_id:
						is_duplicate = true
						break
				else:
					is_duplicate = true
					break
		
		if not is_duplicate:
			selected.append(random_upgrade)
			used_indices[random_index] = true
		
		attempts += 1
	
	# 创建UI选项（需要等待每个选项完全创建）
	for upgrade in selected:
		await _create_upgrade_option_ui(upgrade)
	
	current_upgrades = selected

## 获取所有可用的升级选项
func _get_available_upgrades(weapons_manager) -> Array[UpgradeData]:
	var upgrades: Array[UpgradeData] = []
	var weapon_count = 0
	var new_weapon_count_in_shop = 0
	
	if weapons_manager:
		weapon_count = weapons_manager.get_weapon_count() if weapons_manager.has_method("get_weapon_count") else 0
	
	# 统计当前商店中的new weapon数量
	for upgrade in current_upgrades:
		if upgrade != null and upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			new_weapon_count_in_shop += 1
	
	# 从数据库获取所有基础升级选项
	var base_upgrades = UpgradeDatabase.get_all_upgrade_ids()
	for upgrade_id in base_upgrades:
		var upgrade_data = UpgradeDatabase.get_upgrade_data(upgrade_id)
		if upgrade_data:
			# 创建副本以避免修改原始数据
			var upgrade_copy = UpgradeData.new(
				upgrade_data.upgrade_type,
				upgrade_data.name,
				upgrade_data.cost,
				upgrade_data.icon_path,
				upgrade_data.weapon_id
			)
			upgrade_copy.description = upgrade_data.description
			# 复制品质和实际价格
			upgrade_copy.quality = upgrade_data.quality
			upgrade_copy.actual_cost = upgrade_data.actual_cost
			# 复制属性变化配置
			upgrade_copy.attribute_changes = upgrade_data.attribute_changes.duplicate(true)
			upgrades.append(upgrade_copy)
	
	# 4. New Weapon（根据规则）
	if weapons_manager and (weapon_count + new_weapon_count_in_shop) < 6:
		# 获取所有可用武器
		var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
		for weapon_id in all_weapon_ids:
			var weapon_data = WeaponDatabase.get_weapon(weapon_id)
			var upgrade = UpgradeData.new(
				UpgradeData.UpgradeType.NEW_WEAPON,
				"新武器: " + weapon_data.weapon_name,
				new_weapon_cost,
				weapon_data.texture_path,
				weapon_id
			)
			upgrade.description = weapon_data.description
			# 新武器固定白色品质，价格为 cost
			upgrade.quality = UpgradeData.Quality.WHITE
			upgrade.actual_cost = upgrade.cost
			upgrades.append(upgrade)
	
	# 5. 武器等级+1（基于已有武器）
	if weapons_manager:
		var upgradeable_weapons = weapons_manager.get_upgradeable_weapon_types() if weapons_manager.has_method("get_upgradeable_weapon_types") else []
		
		# 如果所有武器都已满级，不添加
		if not (weapons_manager.has_all_weapons_max_level() if weapons_manager.has_method("has_all_weapons_max_level") else true):
			for weapon_id in upgradeable_weapons:
				var weapon_data = WeaponDatabase.get_weapon(weapon_id)
				
				# 获取当前最低等级的武器
				var lowest_weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
				if not lowest_weapon:
					continue
				
				var current_level = lowest_weapon.weapon_level
				var target_level = current_level + 1  # 目标等级
				var upgrade = UpgradeData.new(
					UpgradeData.UpgradeType.WEAPON_LEVEL_UP,
					weapon_data.weapon_name + " 等级+1",
					new_weapon_cost,  # 这个 cost 会被 base_cost 覆盖
					weapon_data.texture_path,
					weapon_id
				)
				upgrade.description = "提升武器等级 (当前等级: %d)" % current_level
				
				# 动态设置品质和价格（品质 = 目标等级）
				upgrade.quality = target_level
				upgrade.base_cost = new_weapon_cost  # 武器升级基础价格
				upgrade.calculate_weapon_upgrade_cost()
				
				print("[UpgradeShop] 武器升级: %s, 等级%d→%d, 品质=%s, 价格=%d" % [
					weapon_data.weapon_name, 
					current_level, 
					target_level,
					UpgradeData.get_quality_name(upgrade.quality),
					upgrade.actual_cost
				])
				
				upgrades.append(upgrade)
	
	return upgrades

## 创建升级选项UI
func _create_upgrade_option_ui(upgrade: UpgradeData) -> void:
	if not upgrade_option_scene:
		push_error("升级选项场景未加载！")
		return
	
	var option_ui = upgrade_option_scene.instantiate()
	if not option_ui:
		push_error("无法实例化升级选项！")
		return
	
	# 先添加到场景树，确保@onready变量初始化
	if upgrade_container:
		upgrade_container.add_child(option_ui)
	else:
		# 尝试手动查找
		var container = get_node_or_null("%UpgradeContainer")
		if container:
			upgrade_container = container
			container.add_child(option_ui)
		else:
			push_error("无法找到升级容器节点！")
			return
	
	# 等待一帧确保@onready变量已初始化
	await get_tree().process_frame
	
	# 现在设置数据（此时@onready变量已经初始化）
	if option_ui.has_method("set_upgrade_data"):
		option_ui.set_upgrade_data(upgrade)
	
	# 连接信号
	if option_ui.has_signal("purchased"):
		option_ui.purchased.connect(_on_upgrade_purchased)
	
	# 确保选项可见
	option_ui.visible = true
	option_ui.show()
	
	print("升级选项已添加到容器: ", upgrade.name, " 容器子节点数: ", upgrade_container.get_child_count())

## 清除所有升级选项UI
func _clear_upgrades() -> void:
	if upgrade_container:
		for child in upgrade_container.get_children():
			child.queue_free()
		print("清除升级选项，容器子节点数: ", upgrade_container.get_child_count())
	current_upgrades.clear()

## 购买升级
func _on_upgrade_purchased(upgrade: UpgradeData) -> void:
	if GameMain.gold < upgrade.actual_cost:
		print("钥匙不足！需要 %d，当前 %d" % [upgrade.actual_cost, GameMain.gold])
		return
	
	# 扣除钥匙
	GameMain.remove_gold(upgrade.actual_cost)
	print("[UpgradeShop] 购买升级: %s，消耗 %d 钥匙" % [upgrade.name, upgrade.actual_cost])
	
	# 应用升级效果
	_apply_upgrade(upgrade)
	
	upgrade_purchased.emit(upgrade)
	
	# 移除已购买的选项
	for i in range(current_upgrades.size() - 1, -1, -1):
		if current_upgrades[i] == upgrade:
			current_upgrades.remove_at(i)
			break
	
	for child in upgrade_container.get_children():
		if child.has_method("get_upgrade_data"):
			var child_upgrade = child.get_upgrade_data()
			if child_upgrade == upgrade:
				child.queue_free()
				break
	
	# 补充新的选项（如果少于3个）
	if current_upgrades.size() < 3:
		var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
		if not weapons_manager:
			weapons_manager = get_tree().get_first_node_in_group("weapons")
		
		var available = _get_available_upgrades(weapons_manager)
		
		# 过滤掉已存在的选项
		var filtered_available: Array[UpgradeData] = []
		for candidate in available:
			var exists = false
			for existing in current_upgrades:
				if existing.upgrade_type == candidate.upgrade_type:
					if candidate.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or candidate.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
						if existing.weapon_id == candidate.weapon_id:
							exists = true
							break
					else:
						exists = true
						break
			if not exists:
				filtered_available.append(candidate)
		
		if filtered_available.size() > 0:
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var new_upgrade = filtered_available[rng.randi_range(0, filtered_available.size() - 1)]
			current_upgrades.append(new_upgrade)
			await _create_upgrade_option_ui(new_upgrade)

## 应用升级效果
func _apply_upgrade(upgrade: UpgradeData) -> void:
	# 特殊处理：武器相关和恢复HP
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.HEAL_HP:
			_apply_heal_upgrade()
		UpgradeData.UpgradeType.NEW_WEAPON:
			_apply_new_weapon_upgrade(upgrade.weapon_id)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_apply_weapon_level_upgrade(upgrade.weapon_id)
		_:
			# 使用配置的属性变化
			_apply_attribute_changes(upgrade)

func _apply_heal_upgrade() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.now_hp = min(player.now_hp + 100, player.max_hp)
		player.hp_changed.emit(player.now_hp, player.max_hp)

func _apply_new_weapon_upgrade(weapon_id: String) -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("add_weapon"):
		await weapons_manager.add_weapon(weapon_id, 1)  # 新武器固定1级，必须等待完成

func _apply_weapon_level_upgrade(weapon_id: String) -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("get_lowest_level_weapon_of_type"):
		var weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
		if weapon and weapon.has_method("upgrade_level"):
			weapon.upgrade_level()

## 通用属性变化应用函数
## 根据 upgrade.attribute_changes 配置应用属性变化
func _apply_attribute_changes(upgrade: UpgradeData) -> void:
	if upgrade.attribute_changes.is_empty():
		print("[UpgradeShop] 警告: 升级 %s 没有配置属性变化" % upgrade.name)
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[UpgradeShop] 无法找到玩家节点")
		return
	
	var class_data = player.current_class
	if not class_data:
		push_error("[UpgradeShop] 玩家没有职业数据")
		return
	
	var need_reapply_weapons = false
	
	# 遍历所有属性变化配置
	for attr_name in upgrade.attribute_changes.keys():
		var change_config = upgrade.attribute_changes[attr_name]
		if not change_config.has("op") or not change_config.has("value"):
			push_error("[UpgradeShop] 属性变化配置格式错误: %s" % attr_name)
			continue
		
		var op = change_config["op"]
		var value = change_config["value"]
		
		# 特殊处理：max_hp 和 speed（在 player 上）
		if attr_name == "max_hp":
			if op == "add":
				player.max_hp += int(value)
				player.now_hp += int(value)  # 同时恢复HP
				player.hp_changed.emit(player.now_hp, player.max_hp)
				print("[UpgradeShop] %s: max_hp += %d (当前: %d)" % [upgrade.name, int(value), player.max_hp])
			continue
		
		if attr_name == "speed":
			if op == "add":
				player.base_speed += value
				player.speed += value
				print("[UpgradeShop] %s: speed += %.1f (当前: %.1f)" % [upgrade.name, value, player.speed])
			continue
		
		# 其他属性在 class_data 上
		# 检查属性是否存在（Resource 没有 has() 方法，需要检查 property_list）
		var property_exists = false
		for prop in class_data.get_property_list():
			if prop.name == attr_name:
				property_exists = true
				break
		
		if not property_exists:
			push_error("[UpgradeShop] 属性不存在: %s" % attr_name)
			continue
		
		var current_value = class_data.get(attr_name)
		var new_value
		
		match op:
			"add":
				new_value = current_value + value
			"multiply":
				new_value = current_value * value
			_:
				push_error("[UpgradeShop] 不支持的操作类型: %s" % op)
				continue
		
		class_data.set(attr_name, new_value)
		
		# 检查是否需要重新应用武器加成
		if attr_name.contains("multiplier") or attr_name == "luck":
			need_reapply_weapons = true
		
		print("[UpgradeShop] %s: %s %s %.2f (%.2f -> %.2f)" % [
			upgrade.name,
			attr_name,
			op,
			value,
			current_value,
			new_value
		])
	
	# 如果修改了武器相关属性，重新应用武器加成
	if need_reapply_weapons:
		_reapply_weapon_bonuses()

## 重新应用武器加成（当属性改变时）
func _reapply_weapon_bonuses() -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("reapply_all_bonuses"):
		weapons_manager.reapply_all_bonuses()

## 刷新按钮
func _on_refresh_button_pressed() -> void:
	if GameMain.gold < refresh_cost:
		print("钥匙不足！")
		return
	
	GameMain.remove_gold(refresh_cost)
	refresh_cost *= 2  # 下次刷新费用x2
	_update_refresh_cost_display()
	await generate_upgrades()

## 关闭按钮
func _on_close_button_pressed() -> void:
	close_shop()

## 更新刷新费用显示
func _update_refresh_cost_display() -> void:
	if refresh_cost_label:
		refresh_cost_label.text = "刷新: %d 钥匙" % refresh_cost
