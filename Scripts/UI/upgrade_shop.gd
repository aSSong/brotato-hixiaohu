extends Control
class_name UpgradeShop

## 升级商店
## 每波结束后弹出，允许玩家购买升级

@onready var upgrade_container: VBoxContainer = %UpgradeContainer
@onready var refresh_button: Button = %RefreshButton
@onready var close_button: Button = %CloseButton
@onready var refresh_cost_label: Label = %RefreshCostLabel

## 武器列表UI引用
@onready var weapon1_icon: TextureRect = $WeaponList/VBoxContainer/weapon1/ColorRect/Weapon1Icon
@onready var weapon1_label: Label = $WeaponList/VBoxContainer/weapon1/Weapon1Label
@onready var weapon2_icon: TextureRect = $WeaponList/VBoxContainer/weapon2/ColorRect/Weapon2Icon
@onready var weapon2_label: Label = $WeaponList/VBoxContainer/weapon2/Weapon2Label
@onready var weapon3_icon: TextureRect = $WeaponList/VBoxContainer/weapon3/ColorRect/Weapon3Icon
@onready var weapon3_label: Label = $WeaponList/VBoxContainer/weapon3/Weapon3Label
@onready var weapon4_icon: TextureRect = $WeaponList/VBoxContainer/weapon4/ColorRect/Weapon4Icon
@onready var weapon4_label: Label = $WeaponList/VBoxContainer/weapon4/Weapon4Label
@onready var weapon5_icon: TextureRect = $WeaponList/VBoxContainer/weapon5/ColorRect/Weapon5Icon
@onready var weapon5_label: Label = $WeaponList/VBoxContainer/weapon5/Weapon5Label
@onready var weapon6_icon: TextureRect = $WeaponList/VBoxContainer/weapon6/ColorRect/Weapon6Icon
@onready var weapon6_label: Label = $WeaponList/VBoxContainer/weapon6/Weapon6Label

## 当前显示的升级选项（最多3个）
var current_upgrades: Array[UpgradeData] = []
var refresh_cost: int = 2  # 刷新费用，每次x2
var base_refresh_cost: int = 2  # 基础刷新费用

## 锁定的升级选项（key: 位置索引 0-2, value: UpgradeData）
var locked_upgrades: Dictionary = {}

## 武器相关参数
var new_weapon_cost: int = 5 # 新武器基础价格
#var green_weapon_multi: int = 2 #绿色武器价格倍率

## 信号
signal upgrade_purchased(upgrade: UpgradeData)
signal shop_closed()

## 升级选项预制（用于UI显示）
var upgrade_option_scene = preload("res://scenes/UI/upgrade_option.tscn")

## 计算带波次修正的价格
## 公式：最终价格 = floor(基础价格 + 波数 + (基础价格 × 0.1 × 波数))
static func calculate_wave_adjusted_cost(base_cost: int) -> int:
	var wave_number: int = 0
	
	# 尝试获取场景树
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var scene_tree = main_loop as SceneTree
		
		# 尝试获取波次管理器
		var wave_system = scene_tree.get_first_node_in_group("wave_system")
		if not wave_system:
			wave_system = scene_tree.get_first_node_in_group("wave_manager")
		
		if wave_system and "current_wave" in wave_system:
			wave_number = wave_system.current_wave
	
	# 应用公式：最终价格 = floor(基础价格 + 波数 + (基础价格 × 0.1 × 波数))
	var adjusted_cost = float(base_cost) + float(wave_number) + (float(base_cost) * 0.1 * float(wave_number))
	return int(floor(adjusted_cost))

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
	
	# 验证武器列表节点是否找到
	if not weapon1_icon:
		push_warning("weapon1_icon 未找到，尝试手动查找")
		weapon1_icon = get_node_or_null("WeaponList/VBoxContainer/weapon1/ColorRect/Weapon1Icon")
	if not weapon1_label:
		push_warning("weapon1_label 未找到，尝试手动查找")
		weapon1_label = get_node_or_null("WeaponList/VBoxContainer/weapon1/Weapon1Label")
	
	hide()  # 初始隐藏
	print("升级商店 _ready() 完成，节点路径: ", get_path(), " 组: ", get_groups())
	print("upgrade_container: ", upgrade_container, " refresh_button: ", refresh_button, " close_button: ", close_button)
	print("weapon1_icon: ", weapon1_icon, " weapon1_label: ", weapon1_label)

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
	
	# 更新武器列表显示
	_update_weapon_list()
	
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
	# 清除现有选项
	_clear_upgrades()
	
	# 先处理锁定的升级，确保它们保持在相同位置
	var selected: Array[UpgradeData] = []
	selected.resize(3)  # 预分配3个位置
	var locked_positions = {}  # 记录哪些位置已被锁定升级占用
	
	# 恢复锁定的升级到对应位置
	for position_index in range(3):
		if locked_upgrades.has(position_index):
			var locked_upgrade = locked_upgrades[position_index]
			# 创建升级数据的副本（保留锁定价格）
			var upgrade_copy = _duplicate_upgrade_data(locked_upgrade)
			selected[position_index] = upgrade_copy
			locked_positions[position_index] = true
			# 同步更新字典中的引用为新副本，保持对象一致性
			locked_upgrades[position_index] = upgrade_copy
			print("[UpgradeShop] 恢复锁定升级到位置 %d: %s, 锁定价格: %d" % [
				position_index, 
				upgrade_copy.name, 
				upgrade_copy.locked_cost if upgrade_copy.locked_cost >= 0 else upgrade_copy.actual_cost
			])
	
	# 逐个生成剩余的空位
	for position_index in range(3):
		if selected[position_index] != null:
			continue  # 该位置已被锁定升级占用
		
		# 生成单个upgrade（独立判定）
		var new_upgrade = _generate_single_upgrade(selected)
		if new_upgrade:
			selected[position_index] = new_upgrade
		else:
			print("[UpgradeShop] 警告: 无法生成位置 %d 的升级选项" % position_index)
	
	# 按照位置索引顺序创建UI选项（确保UI顺序正确）
	var final_selected: Array[UpgradeData] = []
	for position_index in range(selected.size()):
		if selected[position_index] != null:
			var upgrade = selected[position_index]
			var option_ui = await _create_upgrade_option_ui(upgrade)
			# 设置位置索引
			if option_ui:
				option_ui.position_index = position_index
				# 如果这个位置是锁定的，设置锁定状态
				if locked_positions.has(position_index):
					option_ui.set_lock_state(true)
			final_selected.append(upgrade)
	
	current_upgrades = final_selected

## 创建升级选项UI
func _create_upgrade_option_ui(upgrade: UpgradeData) -> UpgradeOption:
	if not upgrade_option_scene:
		push_error("升级选项场景未加载！")
		return null
	
	var option_ui = upgrade_option_scene.instantiate()
	if not option_ui:
		push_error("无法实例化升级选项！")
		return null
	
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
			return null
	
	# 等待一帧确保@onready变量已初始化
	await get_tree().process_frame
	
	# 现在设置数据（此时@onready变量已经初始化）
	if option_ui.has_method("set_upgrade_data"):
		option_ui.set_upgrade_data(upgrade)
	
	# 连接信号
	if option_ui.has_signal("purchased"):
		option_ui.purchased.connect(_on_upgrade_purchased)
	if option_ui.has_signal("lock_state_changed"):
		option_ui.lock_state_changed.connect(_on_upgrade_lock_state_changed)
	
	# 确保选项可见
	option_ui.visible = true
	option_ui.show()
	
	print("升级选项已添加到容器: ", upgrade.name, " 容器子节点数: ", upgrade_container.get_child_count())
	return option_ui

## 清除所有升级选项UI
func _clear_upgrades() -> void:
	if upgrade_container:
		for child in upgrade_container.get_children():
			child.queue_free()
		print("清除升级选项，容器子节点数: ", upgrade_container.get_child_count())
	current_upgrades.clear()
	# 注意：不清除 locked_upgrades，因为需要在下次生成时保留

## 处理锁定状态变化
func _on_upgrade_lock_state_changed(upgrade: UpgradeData, is_locked: bool, position_index: int) -> void:
	if is_locked:
		# 锁定：计算并保存当前波次的价格
		var adjusted_cost = calculate_wave_adjusted_cost(upgrade.actual_cost)
		upgrade.locked_cost = adjusted_cost
		locked_upgrades[position_index] = upgrade
		print("[UpgradeShop] 锁定升级: %s 在位置 %d, 锁定价格: %d" % [upgrade.name, position_index, adjusted_cost])
	else:
		# 解锁：清除锁定价格
		upgrade.locked_cost = -1
		if locked_upgrades.has(position_index):
			locked_upgrades.erase(position_index)
			print("[UpgradeShop] 解锁升级: %s 在位置 %d" % [upgrade.name, position_index])

## 复制升级数据（用于锁定升级的恢复）
func _duplicate_upgrade_data(source: UpgradeData) -> UpgradeData:
	var copy = UpgradeData.new(
		source.upgrade_type,
		source.name,
		source.cost,
		source.icon_path,
		source.weapon_id
	)
	copy.description = source.description
	copy.quality = source.quality
	copy.base_cost = source.base_cost
	copy.actual_cost = source.actual_cost
	copy.locked_cost = source.locked_cost  # 保留锁定时的价格
	copy.attribute_changes = source.attribute_changes.duplicate(true)
	return copy

## 判断两个升级是否相同
func _is_same_upgrade(upgrade1: UpgradeData, upgrade2: UpgradeData) -> bool:
	if upgrade1.upgrade_type != upgrade2.upgrade_type:
		return false
	
	# 武器类型：比较weapon_id
	if upgrade1.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or upgrade1.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
		return upgrade1.weapon_id == upgrade2.weapon_id
	
	# 属性类型：需要类型、品质、价格都相同才算重复
	# 这样允许不同品质的相同属性类型共存（例如：攻击速度+3%白色 和 攻击速度+5%绿色）
	if upgrade1.quality != upgrade2.quality:
		return false
	
	# 进一步检查价格，确保完全相同
	if upgrade1.actual_cost != upgrade2.actual_cost:
		return false
	
	return true

## 购买升级
func _on_upgrade_purchased(upgrade: UpgradeData) -> void:
	# 如果有锁定价格，使用锁定价格；否则计算波次修正后的价格
	var adjusted_cost: int
	if upgrade.locked_cost >= 0:
		adjusted_cost = upgrade.locked_cost
	else:
		adjusted_cost = calculate_wave_adjusted_cost(upgrade.actual_cost)
	
	if GameMain.gold < adjusted_cost:
		print("钥匙不足！需要 %d，当前 %d" % [adjusted_cost, GameMain.gold])
		return
	
	# 扣除钥匙（使用修正后的价格）
	GameMain.remove_gold(adjusted_cost)
	print("[UpgradeShop] 购买升级: %s，消耗 %d 钥匙（基础价格 %d）" % [upgrade.name, adjusted_cost, upgrade.actual_cost])
	
	# 移除锁定状态（如果该升级被锁定）
	for position_index in locked_upgrades.keys():
		var locked_upgrade = locked_upgrades[position_index]
		if _is_same_upgrade(locked_upgrade, upgrade):
			locked_upgrades.erase(position_index)
			print("[UpgradeShop] 已购买的升级从锁定列表中移除: %s" % upgrade.name)
			break
	
	# 应用升级效果（武器相关的是异步的，需要等待）
	if upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or upgrade.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
		await _apply_upgrade(upgrade)
		# 等待一帧确保武器已完全添加到场景树
		await get_tree().process_frame
		_update_weapon_list()
	else:
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
		# 生成新的upgrade选项
		var new_upgrade = _generate_single_upgrade(current_upgrades)
		if new_upgrade:
			current_upgrades.append(new_upgrade)
			var option_ui = await _create_upgrade_option_ui(new_upgrade)
			if option_ui:
				option_ui.position_index = current_upgrades.size() - 1

## 应用升级效果
func _apply_upgrade(upgrade: UpgradeData) -> void:
	# 特殊处理：武器相关和恢复HP
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.HEAL_HP:
			_apply_heal_upgrade()
		UpgradeData.UpgradeType.NEW_WEAPON:
			await _apply_new_weapon_upgrade(upgrade.weapon_id)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_apply_weapon_level_upgrade(upgrade.weapon_id)
		_:
			# 使用配置的属性变化
			_apply_attribute_changes(upgrade)

func _apply_heal_upgrade() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.now_hp = min(player.now_hp + 10, player.max_hp)
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
				# player.now_hp += int(value)  # 同时恢复HP
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

## 更新武器列表显示
func _update_weapon_list() -> void:
	# 确保节点引用存在，如果不存在则尝试手动查找
	if not weapon1_icon:
		weapon1_icon = get_node_or_null("WeaponList/VBoxContainer/weapon1/ColorRect/Weapon1Icon")
	if not weapon1_label:
		weapon1_label = get_node_or_null("WeaponList/VBoxContainer/weapon1/Weapon1Label")
	if not weapon2_icon:
		weapon2_icon = get_node_or_null("WeaponList/VBoxContainer/weapon2/ColorRect/Weapon2Icon")
	if not weapon2_label:
		weapon2_label = get_node_or_null("WeaponList/VBoxContainer/weapon2/Weapon2Label")
	if not weapon3_icon:
		weapon3_icon = get_node_or_null("WeaponList/VBoxContainer/weapon3/ColorRect/Weapon3Icon")
	if not weapon3_label:
		weapon3_label = get_node_or_null("WeaponList/VBoxContainer/weapon3/Weapon3Label")
	if not weapon4_icon:
		weapon4_icon = get_node_or_null("WeaponList/VBoxContainer/weapon4/ColorRect/Weapon4Icon")
	if not weapon4_label:
		weapon4_label = get_node_or_null("WeaponList/VBoxContainer/weapon4/Weapon4Label")
	if not weapon5_icon:
		weapon5_icon = get_node_or_null("WeaponList/VBoxContainer/weapon5/ColorRect/Weapon5Icon")
	if not weapon5_label:
		weapon5_label = get_node_or_null("WeaponList/VBoxContainer/weapon5/Weapon5Label")
	if not weapon6_icon:
		weapon6_icon = get_node_or_null("WeaponList/VBoxContainer/weapon6/ColorRect/Weapon6Icon")
	if not weapon6_label:
		weapon6_label = get_node_or_null("WeaponList/VBoxContainer/weapon6/Weapon6Label")
	
	# 获取武器管理器
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if not weapons_manager:
		print("[UpgradeShop] 无法找到武器管理器")
		return
	
	# 获取所有武器（按获得顺序）
	var weapons = weapons_manager.get_all_weapons()
	print("[UpgradeShop] 找到武器管理器，武器数量: ", weapons.size())
	
	# 武器图标和标签数组
	var weapon_icons = [weapon1_icon, weapon2_icon, weapon3_icon, weapon4_icon, weapon5_icon, weapon6_icon]
	var weapon_labels = [weapon1_label, weapon2_label, weapon3_label, weapon4_label, weapon5_label, weapon6_label]
	
	# 更新每个武器槽位（1-6）
	for i in range(6):
		var slot_index = i  # 槽位索引（0-5对应武器1-6）
		var icon = weapon_icons[slot_index]
		var label = weapon_labels[slot_index]
		
		if not icon or not label:
			continue
		
		# 检查是否有对应位置的武器
		if slot_index < weapons.size() and weapons[slot_index] is BaseWeapon:
			var weapon = weapons[slot_index] as BaseWeapon
			var weapon_data = weapon.weapon_data
			var weapon_level = weapon.weapon_level
			
			if weapon_data:
				# 设置图标（80x80尺寸已在场景中设置）
				if weapon_data.texture_path != "":
					var texture = load(weapon_data.texture_path)
					if texture:
						icon.texture = texture
						icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						icon.scale = Vector2(0.8,0.8)
					else:
						icon.texture = null
				else:
					icon.texture = null
				
				# 将武器等级映射到品质等级（1-5级对应WHITE-ORANGE）
				var quality_level = weapon_level
				var quality_name = UpgradeData.get_quality_name(quality_level)
				var quality_color = UpgradeData.get_quality_color(quality_level)
				
				# 设置标签文本和颜色
				label.text = "武器%d：%s\n品质：%s" % [slot_index + 1, weapon_data.weapon_name, quality_name]
				label.add_theme_color_override("font_color", quality_color)
			else:
				# 武器数据为空，显示空缺
				icon.texture = null
				label.text = "武器%d：空缺\n品质：无" % [slot_index + 1]
				label.add_theme_color_override("font_color", Color.WHITE)
		else:
			# 该槽位没有武器，保持默认状态
			icon.texture = null
			label.text = "武器%d：空缺\n品质：无" % [slot_index + 1]
			label.add_theme_color_override("font_color", Color.WHITE)
	
	print("[UpgradeShop] 武器列表已更新，当前武器数量: ", weapons.size())

## ========== 新的商店刷新系统 ==========

## 获取当前波数
func _get_current_wave() -> int:
	# 尝试多种方式获取波次管理器
	var wave_manager = get_tree().get_first_node_in_group("wave_system")
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager")
	
	var current_wave = 1
	if wave_manager and "current_wave" in wave_manager:
		current_wave = wave_manager.current_wave
	
	return current_wave

## 获取玩家幸运值
func _get_player_luck() -> float:
	var player = get_tree().get_first_node_in_group("player")
	var luck_value = 0.0
	if player and player.current_class:
		luck_value = player.current_class.luck
	return luck_value

## 统计商店中的new weapon数量（包括锁定的）
func _count_new_weapons_in_shop() -> int:
	var count = 0
	
	# 统计当前显示的
	for upgrade in current_upgrades:
		if upgrade != null and upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			count += 1
	
	# 统计锁定的
	for position_index in locked_upgrades.keys():
		var locked_upgrade = locked_upgrades[position_index]
		if locked_upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			count += 1
	
	return count

## 根据幸运值和波数计算品质
## 返回品质等级（1-5对应WHITE-ORANGE）
func _get_quality_by_luck(luck_value: float, current_wave: int) -> int:
	# 品质配置表
	var quality_configs = [
		# [品质, 最低波数, 基础概率, 每波增加, 最高概率]
		[UpgradeData.Quality.ORANGE, 10, 0.0, 0.23, 8.0],    # Tier 5
		[UpgradeData.Quality.PURPLE, 8, 0.0, 2.0, 25.0],     # Tier 4
		[UpgradeData.Quality.BLUE, 4, 0.0, 6.0, 60.0],       # Tier 3
		[UpgradeData.Quality.GREEN, 2, 0.0, 8.0, 80.0],      # Tier 2
		[UpgradeData.Quality.WHITE, 1, 100.0, 0.0, 100.0],   # Tier 1
	]
	
	# 幸运值转换为百分比倍率（luck值 / 100）
	var luck_multiplier = 1.0 + (luck_value / 100.0)
	
	# 计算每个品质的概率
	var quality_probabilities = []
	for config in quality_configs:
		var quality = config[0]
		var min_wave = config[1]
		var base_prob = config[2]
		var wave_increase = config[3]
		var max_prob = config[4]
		
		# 如果当前波数低于最低出现波数，概率为0
		if current_wave < min_wave:
			quality_probabilities.append([quality, 0.0])
			continue
		
		# 计算概率：((每波增加 × (当前波数 - 最低波数 - 1)) + 基础概率) × 幸运倍率
		var wave_bonus = wave_increase * float(current_wave - min_wave - 1)
		var probability = (base_prob + wave_bonus) * luck_multiplier
		
		# 限制在最高概率
		probability = min(probability, max_prob)
		
		quality_probabilities.append([quality, probability])
	
	# 从高到低检查品质，使用递减概率
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var roll = rng.randf_range(0.0, 100.0)
	
	var accumulated_prob = 0.0
	for i in range(quality_probabilities.size()):
		var quality = quality_probabilities[i][0]
		var prob = quality_probabilities[i][1]
		
		# 计算实际可用概率（从剩余概率中分配）
		var available_prob = 100.0 - accumulated_prob
		var actual_prob = min(prob, available_prob)
		
		if roll < accumulated_prob + actual_prob:
			print("[UpgradeShop] 品质抽取: 波数=%d, 幸运=%d, Roll=%.1f%%, 品质=%s (概率=%.1f%%)" % [
				current_wave, int(luck_value), roll, 
				UpgradeData.get_quality_name(quality), actual_prob
			])
			return quality
		
		accumulated_prob += actual_prob
	
	# 保底返回白色
	return UpgradeData.Quality.WHITE

## 生成单个upgrade选项（独立判定）
func _generate_single_upgrade(existing_upgrades: Array[UpgradeData]) -> UpgradeData:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 35% 概率生成武器，65% 概率生成属性
	var is_weapon = rng.randf() < 0.35
	
	var attempts = 0
	var max_attempts = 50
	
	while attempts < max_attempts:
		attempts += 1
		
		var upgrade: UpgradeData = null
		
		if is_weapon:
			upgrade = _generate_weapon_upgrade()
		else:
			# 获取当前波数和幸运值
			var current_wave = _get_current_wave()
			var luck_value = _get_player_luck()
			
			# 根据幸运值决定品质
			var quality = _get_quality_by_luck(luck_value, current_wave)
			
			upgrade = _generate_attribute_upgrade(quality)
		
		if upgrade == null:
			# 如果生成失败，尝试切换类型
			if is_weapon:
				# 武器生成失败，尝试生成属性
				var current_wave = _get_current_wave()
				var luck_value = _get_player_luck()
				var quality = _get_quality_by_luck(luck_value, current_wave)
				upgrade = _generate_attribute_upgrade(quality)
			else:
				# 属性生成失败，尝试生成武器
				upgrade = _generate_weapon_upgrade()
			
			if upgrade == null:
				continue
		
		# 检查是否与已有选项重复
		var is_duplicate = false
		for existing in existing_upgrades:
			if existing == null:
				continue
			if _is_same_upgrade(existing, upgrade):
				is_duplicate = true
				break
		
		if not is_duplicate:
			return upgrade
	
	print("[UpgradeShop] 警告: 尝试 %d 次后仍无法生成不重复的升级" % max_attempts)
	return null

## 生成武器相关upgrade
func _generate_weapon_upgrade() -> UpgradeData:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if not weapons_manager:
		return null
	
	var weapon_count = 0
	if weapons_manager.has_method("get_weapon_count"):
		weapon_count = weapons_manager.get_weapon_count()
	
	# 统计商店中的new weapon数量（包括锁定的）
	var new_weapon_count_in_shop = _count_new_weapons_in_shop()
	
	# 检查是否可以生成新武器
	var can_generate_new_weapon = (weapon_count + new_weapon_count_in_shop) < 6
	
	# 检查是否所有武器都满级
	var all_weapons_max_level = false
	if weapons_manager.has_method("has_all_weapons_max_level"):
		all_weapons_max_level = weapons_manager.has_all_weapons_max_level()
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 决定生成NEW_WEAPON还是WEAPON_LEVEL_UP
	var can_level_up = weapon_count > 0 and not all_weapons_max_level
	
	if not can_generate_new_weapon and not can_level_up:
		# 既不能生成新武器，也不能升级武器
		return null
	
	if can_generate_new_weapon and not can_level_up:
		# 只能生成新武器
		return _generate_new_weapon_upgrade()
	
	if not can_generate_new_weapon and can_level_up:
		# 只能升级武器
		return _generate_weapon_level_up_upgrade(weapons_manager)
	
	# 两者都可以，随机选择
	if rng.randf() < 0.5:
		return _generate_new_weapon_upgrade()
	else:
		return _generate_weapon_level_up_upgrade(weapons_manager)

## 生成新武器upgrade
func _generate_new_weapon_upgrade() -> UpgradeData:
	var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
	if all_weapon_ids.is_empty():
		return null
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var weapon_id = all_weapon_ids[rng.randi_range(0, all_weapon_ids.size() - 1)]
	
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	var upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.NEW_WEAPON,
		"新武器: " + weapon_data.weapon_name,
		new_weapon_cost,
		weapon_data.texture_path,
		weapon_id
	)
	upgrade.description = weapon_data.description
	upgrade.quality = UpgradeData.Quality.WHITE
	upgrade.actual_cost = upgrade.cost
	
	return upgrade

## 生成武器升级upgrade
func _generate_weapon_level_up_upgrade(weapons_manager) -> UpgradeData:
	if not weapons_manager.has_method("get_upgradeable_weapon_types"):
		return null
	
	var upgradeable_weapons = weapons_manager.get_upgradeable_weapon_types()
	if upgradeable_weapons.is_empty():
		return null
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var weapon_id = upgradeable_weapons[rng.randi_range(0, upgradeable_weapons.size() - 1)]
	
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	
	# 获取当前最低等级的武器
	var lowest_weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
	if not lowest_weapon:
		return null
	
	var current_level = lowest_weapon.weapon_level
	var target_level = current_level + 1  # 目标等级
	
	var upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP,
		weapon_data.weapon_name + " 等级+1",
		new_weapon_cost,
		weapon_data.texture_path,
		weapon_id
	)
	upgrade.description = "提升武器等级 (当前等级: %d)" % current_level
	
	# 动态设置品质和价格（品质 = 目标等级）
	upgrade.quality = target_level
	upgrade.base_cost = new_weapon_cost
	upgrade.calculate_weapon_upgrade_cost()
	
	return upgrade

## 生成指定品质的属性upgrade
func _generate_attribute_upgrade(quality: int) -> UpgradeData:
	# 获取所有upgrade ID
	var all_upgrade_ids = UpgradeDatabase.get_all_upgrade_ids()
	
	# 筛选出指定品质的upgrade
	var quality_upgrades = []
	for upgrade_id in all_upgrade_ids:
		var upgrade_data = UpgradeDatabase.get_upgrade_data(upgrade_id)
		if upgrade_data and upgrade_data.quality == quality:
			quality_upgrades.append(upgrade_id)
	
	if quality_upgrades.is_empty():
		print("[UpgradeShop] 警告: 没有品质为 %s 的升级选项" % UpgradeData.get_quality_name(quality))
		return null
	
	# 随机选择一个
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var upgrade_id = quality_upgrades[rng.randi_range(0, quality_upgrades.size() - 1)]
	
	var upgrade_data = UpgradeDatabase.get_upgrade_data(upgrade_id)
	
	# 创建副本
	var upgrade_copy = UpgradeData.new(
		upgrade_data.upgrade_type,
		upgrade_data.name,
		upgrade_data.cost,
		upgrade_data.icon_path,
		upgrade_data.weapon_id
	)
	upgrade_copy.description = upgrade_data.description
	upgrade_copy.quality = upgrade_data.quality
	upgrade_copy.actual_cost = upgrade_data.actual_cost
	upgrade_copy.attribute_changes = upgrade_data.attribute_changes.duplicate(true)
	
	return upgrade_copy
