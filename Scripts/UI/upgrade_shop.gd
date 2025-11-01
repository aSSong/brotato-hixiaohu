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
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	_update_refresh_cost_display()
	hide()  # 初始隐藏
	print("升级商店 _ready() 完成，节点路径: ", get_path(), " 组: ", get_groups())

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
	refresh_cost = 2
	_update_refresh_cost_display()
	# 生成初始升级选项
	generate_upgrades()
	print("升级商店已打开，选项数量: ", current_upgrades.size())
	print("打开后可见性: ", visible, " process_mode: ", process_mode)

## 关闭商店
func close_shop() -> void:
	hide()
	# 恢复游戏
	get_tree().paused = false
	shop_closed.emit()

## 生成升级选项（3个）
func generate_upgrades() -> void:
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
	
	# 创建UI选项
	for upgrade in selected:
		_create_upgrade_option_ui(upgrade)
	
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
	
	# 1. HP上限+50
	upgrades.append(UpgradeData.new(
		UpgradeData.UpgradeType.HP_MAX,
		"HP上限+50",
		5,
		"res://assets/items/6.png"
	))
	
	# 2. 移动速度+10
	upgrades.append(UpgradeData.new(
		UpgradeData.UpgradeType.MOVE_SPEED,
		"移动速度+10",
		5,
		"res://assets/items/11.png"
	))
	
	# 3. 恢复HP100点
	upgrades.append(UpgradeData.new(
		UpgradeData.UpgradeType.HEAL_HP,
		"恢复HP100点",
		3,
		"res://assets/items/5.png"
	))
	
	# 4. New Weapon（根据规则）
	if weapons_manager and (weapon_count + new_weapon_count_in_shop) < 6:
		# 获取所有可用武器
		var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
		for weapon_id in all_weapon_ids:
			var weapon_data = WeaponDatabase.get_weapon(weapon_id)
			var upgrade = UpgradeData.new(
				UpgradeData.UpgradeType.NEW_WEAPON,
				"新武器: " + weapon_data.weapon_name,
				10,
				weapon_data.texture_path,
				weapon_id
			)
			upgrade.description = weapon_data.description
			upgrades.append(upgrade)
	
	# 5. 武器等级+1（基于已有武器）
	if weapons_manager:
		var upgradeable_weapons = weapons_manager.get_upgradeable_weapon_types() if weapons_manager.has_method("get_upgradeable_weapon_types") else []
		
		# 如果所有武器都已满级，不添加
		if not (weapons_manager.has_all_weapons_max_level() if weapons_manager.has_method("has_all_weapons_max_level") else true):
			for weapon_id in upgradeable_weapons:
				var weapon_data = WeaponDatabase.get_weapon(weapon_id)
				var upgrade = UpgradeData.new(
					UpgradeData.UpgradeType.WEAPON_LEVEL_UP,
					weapon_data.weapon_name + " 等级+1",
					20,
					weapon_data.texture_path,
					weapon_id
				)
				upgrade.description = "提升武器等级"
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
	
	if option_ui.has_method("set_upgrade_data"):
		option_ui.set_upgrade_data(upgrade)
	
	if option_ui.has_signal("purchased"):
		option_ui.purchased.connect(_on_upgrade_purchased)
	
	if upgrade_container:
		upgrade_container.add_child(option_ui)
	else:
		push_error("升级容器未找到！")

## 清除所有升级选项UI
func _clear_upgrades() -> void:
	for child in upgrade_container.get_children():
		child.queue_free()
	current_upgrades.clear()

## 购买升级
func _on_upgrade_purchased(upgrade: UpgradeData) -> void:
	if GameMain.gold < upgrade.cost:
		print("金币不足！")
		return
	
	# 扣除金币
	GameMain.remove_gold(upgrade.cost)
	
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
			_create_upgrade_option_ui(new_upgrade)

## 应用升级效果
func _apply_upgrade(upgrade: UpgradeData) -> void:
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.HP_MAX:
			_apply_hp_max_upgrade()
		UpgradeData.UpgradeType.MOVE_SPEED:
			_apply_move_speed_upgrade()
		UpgradeData.UpgradeType.HEAL_HP:
			_apply_heal_upgrade()
		UpgradeData.UpgradeType.NEW_WEAPON:
			_apply_new_weapon_upgrade(upgrade.weapon_id)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_apply_weapon_level_upgrade(upgrade.weapon_id)

func _apply_hp_max_upgrade() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.max_hp += 50
		player.now_hp += 50  # 同时恢复HP
		player.hp_changed.emit(player.now_hp, player.max_hp)

func _apply_move_speed_upgrade() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.base_speed += 10
		player.speed += 10

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
		weapons_manager.add_weapon(weapon_id, 1)  # 新武器固定1级
		# 等待武器添加完成
		await get_tree().process_frame

func _apply_weapon_level_upgrade(weapon_id: String) -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("get_lowest_level_weapon_of_type"):
		var weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
		if weapon and weapon.has_method("upgrade_level"):
			weapon.upgrade_level()

## 刷新按钮
func _on_refresh_button_pressed() -> void:
	if GameMain.gold < refresh_cost:
		print("金币不足！")
		return
	
	GameMain.remove_gold(refresh_cost)
	refresh_cost *= 2  # 下次刷新费用x2
	_update_refresh_cost_display()
	generate_upgrades()

## 关闭按钮
func _on_close_button_pressed() -> void:
	close_shop()

## 更新刷新费用显示
func _update_refresh_cost_display() -> void:
	if refresh_cost_label:
		refresh_cost_label.text = "刷新: %d 金币" % refresh_cost
