extends Control
class_name UpgradeShop

## 升级商店
## 每波结束后弹出，允许玩家购买升级

@onready var upgrade_container: HBoxContainer = %UpgradeContainer
@onready var refresh_button: TextureButton = %RefreshButton
@onready var close_button: TextureButton = %CloseButton
@onready var refresh_cost_label: Label = %RefreshCostLabel

## 新版 UI 节点引用
@onready var player_portrait: TextureRect = %PlayerPortrait
@onready var player_name_label: Label = %PlayerName
@onready var weapon_container: GridContainer = %WeaponContainer

## WeaponCompact 场景预加载
var weapon_compact_scene: PackedScene = preload("res://scenes/UI/components/weapon_compact.tscn")

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
	
	# 初始化玩家信息显示
	_initialize_player_info()
	
	hide()  # 初始隐藏
	print("升级商店 _ready() 完成，节点路径: ", get_path(), " 组: ", get_groups())
	print("upgrade_container: ", upgrade_container, " refresh_button: ", refresh_button, " close_button: ", close_button)
	print("weapon_container: ", weapon_container)

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
	# get_tree().paused = true # 由 GameState 管理
	
	# 显示商店（必须在暂停后）
	show()
	visible = true
	
	# 确保节点可见
	set_process(true)
	set_process_input(true)
	
	# 重置刷新费用
	refresh_cost = base_refresh_cost
	_update_refresh_cost_display()
	
	# 更新玩家信息
	_initialize_player_info()
	
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
	# GameState 管理暂停状态，这里不需要手动处理
	# get_tree().paused = false
	shop_closed.emit()

## 生成升级选项（3个）
## 优化版：复用现有节点，消除闪烁
func generate_upgrades() -> void:
	# 1. 播放翻出动画（只对非锁定的选项）
	# 锁定的选项保持原样，非锁定的翻出并隐藏（scale.x -> 0）
	await _play_flip_out_animations()
	
	# 2. 准备新的数据列表
	var new_upgrades_list: Array[UpgradeData] = []
	new_upgrades_list.resize(3)
	
	# 恢复锁定的升级到对应位置
	for position_index in range(3):
		if locked_upgrades.has(position_index):
			var locked_upgrade = locked_upgrades[position_index]
			# 创建升级数据的副本（保留锁定价格）
			var upgrade_copy = _duplicate_upgrade_data(locked_upgrade)
			new_upgrades_list[position_index] = upgrade_copy
			# 同步更新字典中的引用为新副本
			locked_upgrades[position_index] = upgrade_copy
			print("[UpgradeShop] 恢复锁定升级到位置 %d: %s" % [position_index, upgrade_copy.name])
	
	# 生成新升级填补空位
	for position_index in range(3):
		if new_upgrades_list[position_index] != null:
			continue # 已被锁定占位
			
		var new_upgrade = _generate_single_upgrade(new_upgrades_list)
		if new_upgrade:
			new_upgrades_list[position_index] = new_upgrade
		else:
			print("[UpgradeShop] 警告: 无法生成位置 %d 的升级选项" % position_index)
	
	# 更新当前数据
	current_upgrades = new_upgrades_list
	
	# 3. 同步UI节点（对象池模式）
	# 确保容器中至少有3个节点
	if not upgrade_option_scene:
		push_error("升级选项场景未加载！")
		return
		
	while upgrade_container.get_child_count() < 3:
		var option_ui = upgrade_option_scene.instantiate() as UpgradeOption
		upgrade_container.add_child(option_ui)
		# 初始连接信号
		if option_ui.has_signal("purchased"):
			option_ui.purchased.connect(_on_upgrade_purchased)
		if option_ui.has_signal("lock_state_changed"):
			option_ui.lock_state_changed.connect(_on_upgrade_lock_state_changed)
	
	# 清理多余节点（理论上不应该发生）
	while upgrade_container.get_child_count() > 3:
		var child = upgrade_container.get_child(upgrade_container.get_child_count() - 1)
		child.queue_free()
	
	# 确保所有新添加的节点已进入树
	if not is_inside_tree():
		await get_tree().process_frame
	
	# 4. 更新每个节点的数据和状态
	for i in range(3):
		var option_ui = upgrade_container.get_child(i) as UpgradeOption
		var upgrade_data = new_upgrades_list[i]
		var is_locked = locked_upgrades.has(i)
		
		option_ui.position_index = i
		
		# 更新数据
		# 注意：对于非锁定节点，此时 scale.x 应为 0（由 _play_flip_out_animations 设置）
		# 所以即使数据变了，玩家也暂时看不到，直到翻入动画播放
		if upgrade_data:
			option_ui.set_upgrade_data(upgrade_data)
		
		option_ui.set_lock_state(is_locked)
		
		if is_locked:
			# 锁定的节点：确保完全显示
			option_ui.scale.x = 1.0
			option_ui.modulate = Color.WHITE
		else:
			# 非锁定的节点：确保初始隐藏，然后播放翻入动画
			option_ui.scale.x = 0.0
			option_ui.modulate = Color(0.5, 0.5, 0.5) # 初始暗色
			
			var delay = i * 0.08
			if option_ui.has_method("play_flip_in_animation"):
				option_ui.play_flip_in_animation(delay)
	
	print("[UpgradeShop] 升级选项生成完成 (优化模式), 数量: 3")

## 创建升级选项UI实例（辅助函数，仅用于补充节点）
func _create_upgrade_option_instance(upgrade: UpgradeData, position_index: int, skip_animation: bool = false) -> UpgradeOption:
	if not upgrade_option_scene:
		return null
	
	var option_ui = upgrade_option_scene.instantiate() as UpgradeOption
	option_ui.position_index = position_index
	if not skip_animation:
		option_ui.scale.x = 0.0
	
	if option_ui.has_signal("purchased"):
		option_ui.purchased.connect(_on_upgrade_purchased)
	if option_ui.has_signal("lock_state_changed"):
		option_ui.lock_state_changed.connect(_on_upgrade_lock_state_changed)
	
	option_ui.upgrade_data = upgrade
	return option_ui

## 播放所有非锁定选项的翻出动画
func _play_flip_out_animations() -> void:
	if not upgrade_container:
		return
	
	var tweens: Array[Tween] = []
	
	# 遍历所有现有选项
	for child in upgrade_container.get_children():
		if child is UpgradeOption:
			var option = child as UpgradeOption
			# 只有非锁定的才播放翻出动画
			if not option.is_locked:
				if option.has_method("play_flip_out_animation"):
					var tween = option.play_flip_out_animation()
					if tween:
						tweens.append(tween)
	
	# 等待动画完成
	if tweens.size() > 0:
		await tweens[0].finished

## 清除所有升级选项
# 优化版不再频繁调用此函数，保留以备不时之需
func _clear_upgrades() -> void:
	if upgrade_container:
		for child in upgrade_container.get_children():
			child.queue_free()
	current_upgrades.clear()

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
	copy.weight = source.weight  # 复制权重
	copy.attribute_changes = source.attribute_changes.duplicate(true)
	
	# ⭐ 关键：复制stats_modifier（新属性系统）
	if source.stats_modifier:
		copy.stats_modifier = source.stats_modifier.clone()
	
	# 复制自定义值
	copy.custom_value = source.custom_value
	
	return copy

## 判断两个升级是否相同
func _is_same_upgrade(upgrade1: UpgradeData, upgrade2: UpgradeData) -> bool:
	if upgrade1.upgrade_type != upgrade2.upgrade_type:
		return false
	
	# 武器类型：比较weapon_id
	if upgrade1.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or upgrade1.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
		return upgrade1.weapon_id == upgrade2.weapon_id
	
	# 属性类型：需要类型、品质、价格都相同才算重复
	if upgrade1.quality != upgrade2.quality:
		return false
	
	# 进一步检查价格，确保完全相同
	if upgrade1.actual_cost != upgrade2.actual_cost:
		return false
	
	return true

## 购买升级
## 优化版：只刷新被购买的那一个格子
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
	
	# 扣除钥匙
	GameMain.remove_gold(adjusted_cost)
	
	# 更新刷新按钮状态
	_update_refresh_cost_display()
	
	print("[UpgradeShop] 购买升级: %s，消耗 %d 钥匙" % [upgrade.name, adjusted_cost])
	
	# 移除锁定状态
	for position_index in locked_upgrades.keys():
		var locked_upgrade = locked_upgrades[position_index]
		if _is_same_upgrade(locked_upgrade, upgrade):
			locked_upgrades.erase(position_index)
			break
	
	# 应用升级效果
	if upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or upgrade.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
		await _apply_upgrade(upgrade)
		await get_tree().process_frame
		_update_weapon_list()
	else:
		_apply_upgrade(upgrade)
	
	upgrade_purchased.emit(upgrade)
	
	# 找到被购买选项的UI节点
	var purchased_option: UpgradeOption = null
	var purchased_index: int = -1
	
	for child in upgrade_container.get_children():
		if child is UpgradeOption:
			var option = child as UpgradeOption
			if option.upgrade_data == upgrade:
				purchased_option = option
				purchased_index = option.position_index
				break
	
	# 局部刷新逻辑
	if purchased_option:
		# 1. 翻出动画（只针对这一个）
		if purchased_option.has_method("play_flip_out_animation"):
			await purchased_option.play_flip_out_animation().finished
		
		# 2. 从 current_upgrades 移除旧数据
		if purchased_index >= 0 and purchased_index < current_upgrades.size():
			# 3. 生成新数据
			# 临时将旧数据置空，防止 _generate_single_upgrade 认为它还在
			current_upgrades[purchased_index] = null
			
			var new_upgrade = _generate_single_upgrade(current_upgrades)
			
			# 4. 更新数据到现有节点
			if new_upgrade:
				current_upgrades[purchased_index] = new_upgrade
				purchased_option.set_upgrade_data(new_upgrade)
				purchased_option.position_index = purchased_index # 保持索引
				purchased_option.set_lock_state(false) # 新生成的默认不锁定
				
				# 5. 翻入动画
				purchased_option.play_flip_in_animation(0.0)
			else:
				print("警告：购买后无法生成新升级")
				# 隐藏节点
				purchased_option.visible = false

## 应用升级效果
func _apply_upgrade(upgrade: UpgradeData) -> void:
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.HEAL_HP:
			_apply_heal_upgrade(upgrade)
		UpgradeData.UpgradeType.NEW_WEAPON:
			await _apply_new_weapon_upgrade(upgrade.weapon_id)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_apply_weapon_level_upgrade(upgrade.weapon_id)
		_:
			_apply_attribute_upgrade(upgrade)

func _apply_heal_upgrade(upgrade: UpgradeData) -> void:
	var heal_amount = 10
	if upgrade.custom_value > 0:
		heal_amount = int(upgrade.custom_value)
	elif upgrade.stats_modifier and upgrade.stats_modifier.max_hp > 0:
		heal_amount = upgrade.stats_modifier.max_hp
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var old_hp = player.now_hp
		player.now_hp = min(player.now_hp + heal_amount, player.max_hp)
		var actual_heal = player.now_hp - old_hp
		
		if actual_heal > 0:
			SpecialEffects.show_heal_floating_text(player, actual_heal)
		
		player.hp_changed.emit(player.now_hp, player.max_hp)

func _apply_new_weapon_upgrade(weapon_id: String) -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("add_weapon"):
		await weapons_manager.add_weapon(weapon_id, 1)

func _apply_weapon_level_upgrade(weapon_id: String) -> void:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if weapons_manager and weapons_manager.has_method("get_lowest_level_weapon_of_type"):
		var weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
		if weapon and weapon.has_method("upgrade_level"):
			weapon.upgrade_level()

func _apply_attribute_upgrade(upgrade: UpgradeData) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[UpgradeShop] 无法找到玩家节点")
		return
	
	if player.has_node("AttributeManager"):
		if upgrade.stats_modifier:
			var modifier = upgrade.create_modifier()
			player.attribute_manager.add_permanent_modifier(modifier)
		else:
			push_warning("[UpgradeShop] 升级 %s 没有stats_modifier，降级到旧系统" % upgrade.name)
			_apply_attribute_changes_old(upgrade)
	else:
		_apply_attribute_changes_old(upgrade)

func _apply_attribute_changes_old(upgrade: UpgradeData) -> void:
	if upgrade.attribute_changes.is_empty():
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var class_data = player.current_class
	var need_reapply_weapons = false
	
	for attr_name in upgrade.attribute_changes.keys():
		var change_config = upgrade.attribute_changes[attr_name]
		var op = change_config["op"]
		var value = change_config["value"]
		
		if attr_name == "max_hp":
			if op == "add":
				player.max_hp += int(value)
				player.hp_changed.emit(player.now_hp, player.max_hp)
			continue
		
		if attr_name == "speed":
			if op == "add":
				player.base_speed += value
				player.speed += value
			continue
		
		# 其他属性在 class_data 上
		if class_data:
			var current_value = class_data.get(attr_name)
			var new_value
			
			match op:
				"add":
					new_value = current_value + value
				"multiply":
					new_value = current_value * value
			
			class_data.set(attr_name, new_value)
			
			if attr_name.contains("multiplier") or attr_name == "luck":
				need_reapply_weapons = true
	
	if need_reapply_weapons:
		_reapply_weapon_bonuses()

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
		refresh_cost_label.text = " 🔑 %d" % refresh_cost
	
	if refresh_button:
		var can_afford = GameMain.gold >= refresh_cost
		if can_afford:
			refresh_button.modulate = Color.WHITE
		else:
			refresh_button.modulate = Color(0.5, 0.5, 0.5)

## 初始化玩家信息显示
func _initialize_player_info() -> void:
	var class_id = GameMain.selected_class_id
	if class_id != "" and player_portrait:
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.portrait:
			player_portrait.texture = class_data.portrait
	
	if player_name_label:
		var saved_name = SaveManager.get_player_name()
		if saved_name != "":
			player_name_label.text = saved_name
		else:
			player_name_label.text = "玩家"

## 更新武器列表显示
func _update_weapon_list() -> void:
	if not weapon_container:
		weapon_container = get_node_or_null("%WeaponContainer")
		if not weapon_container:
			return
	
	for child in weapon_container.get_children():
		child.queue_free()
	
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if not weapons_manager:
		return
	
	var weapons = weapons_manager.get_all_weapons()
	
	for i in range(6):
		if not weapon_compact_scene:
			continue
			
		var compact = weapon_compact_scene.instantiate()
		weapon_container.add_child(compact)
		
		if i < weapons.size() and weapons[i] is BaseWeapon:
			var weapon = weapons[i] as BaseWeapon
			var weapon_data = weapon.weapon_data
			var weapon_level = weapon.weapon_level
			
			if weapon_data:
				if compact.has_method("setup_weapon_from_data"):
					compact.setup_weapon_from_data(weapon_data, weapon_level)
				elif compact.has_method("setup_weapon"):
					compact.setup_weapon(weapon_data.weapon_id, weapon_level)
		else:
			if compact.has_method("set_weapon_name"):
				compact.set_weapon_name("空缺")
			if compact.has_method("set_weapon_texture"):
				compact.set_weapon_texture(null)
			if compact.has_method("set_quality_level"):
				compact.set_quality_level(1)

## ========== 新的商店刷新系统 ==========

func _get_current_wave() -> int:
	var wave_manager = get_tree().get_first_node_in_group("wave_system")
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager")
	
	var current_wave = 1
	if wave_manager and "current_wave" in wave_manager:
		current_wave = wave_manager.current_wave
	
	return current_wave

func _get_player_luck() -> float:
	var player = get_tree().get_first_node_in_group("player")
	var luck_value = 0.0
	if player and player.current_class:
		luck_value = player.current_class.luck
	return luck_value

func _count_new_weapons_in_shop() -> int:
	var count = 0
	for upgrade in current_upgrades:
		if upgrade != null and upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			count += 1
	for position_index in locked_upgrades.keys():
		var locked_upgrade = locked_upgrades[position_index]
		if locked_upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			count += 1
	return count

func _get_quality_by_luck(luck_value: float, current_wave: int) -> int:
	var quality_configs = [
		[UpgradeData.Quality.ORANGE, 10, 0.0, 0.23, 8.0],
		[UpgradeData.Quality.PURPLE, 8, 0.0, 2.0, 25.0],
		[UpgradeData.Quality.BLUE, 4, 0.0, 6.0, 60.0],
		[UpgradeData.Quality.GREEN, 2, 0.0, 8.0, 80.0],
		[UpgradeData.Quality.WHITE, 1, 100.0, 0.0, 100.0],
	]
	
	var luck_multiplier = 1.0 + (luck_value / 100.0)
	var quality_probabilities = []
	
	for config in quality_configs:
		var quality = config[0]
		var min_wave = config[1]
		var base_prob = config[2]
		var wave_increase = config[3]
		var max_prob = config[4]
		
		if current_wave < min_wave:
			quality_probabilities.append([quality, 0.0])
			continue
		
		var wave_bonus = wave_increase * float(current_wave - min_wave - 1)
		var probability = (base_prob + wave_bonus) * luck_multiplier
		probability = min(probability, max_prob)
		
		quality_probabilities.append([quality, probability])
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + int(luck_value))
	var roll = rng.randf_range(0.0, 100.0)
	
	var accumulated_prob = 0.0
	for i in range(quality_probabilities.size()):
		var quality = quality_probabilities[i][0]
		var prob = quality_probabilities[i][1]
		var available_prob = 100.0 - accumulated_prob
		var actual_prob = min(prob, available_prob)
		
		if roll < accumulated_prob + actual_prob:
			return quality
		
		accumulated_prob += actual_prob
	
	return UpgradeData.Quality.WHITE

func _generate_single_upgrade(existing_upgrades: Array[UpgradeData]) -> UpgradeData:
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + existing_upgrades.size())
	
	var current_weapon_count = 0
	var current_attribute_count = 0
	for up in existing_upgrades:
		if up != null:
			if up.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or up.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
				current_weapon_count += 1
			else:
				current_attribute_count += 1
	
	var is_weapon = false
	if current_weapon_count >= 2:
		is_weapon = false
	elif current_attribute_count >= 2:
		is_weapon = true
	else:
		is_weapon = rng.randf() < 0.35
	
	var attempts = 0
	var max_attempts = 50
	
	while attempts < max_attempts:
		attempts += 1
		var salt = randi()
		var upgrade: UpgradeData = null
		
		if is_weapon:
			upgrade = _generate_weapon_upgrade(existing_upgrades, salt)
		else:
			var luck_value = _get_player_luck()
			var quality = _get_quality_by_luck(luck_value, current_wave)
			upgrade = _generate_attribute_upgrade(quality, salt)
			if upgrade == null:
				upgrade = _generate_attribute_upgrade(UpgradeData.Quality.WHITE, salt)
		
		if upgrade == null:
			if is_weapon:
				var luck_value = _get_player_luck()
				var quality = _get_quality_by_luck(luck_value, current_wave)
				upgrade = _generate_attribute_upgrade(quality, salt)
				if upgrade == null:
					upgrade = _generate_attribute_upgrade(UpgradeData.Quality.WHITE, salt)
			else:
				upgrade = _generate_weapon_upgrade(existing_upgrades, salt)
			
			if upgrade == null:
				continue
		
		var is_duplicate = false
		for existing in existing_upgrades:
			if existing == null:
				continue
			if _is_same_upgrade(existing, upgrade):
				is_duplicate = true
				break
		
		if not is_duplicate:
			return upgrade
	
	return null

func _generate_weapon_upgrade(existing_upgrades: Array[UpgradeData], salt: int = 0) -> UpgradeData:
	var weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = get_tree().get_first_node_in_group("weapons")
	if not weapons_manager:
		return null
	
	var weapon_count = 0
	if weapons_manager.has_method("get_weapon_count"):
		weapon_count = weapons_manager.get_weapon_count()
	
	var new_weapon_count_in_shop = 0
	for up in existing_upgrades:
		if up and up.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			new_weapon_count_in_shop += 1
	
	var can_generate_new_weapon = (weapon_count + new_weapon_count_in_shop) < 6
	var all_weapons_max_level = false
	if weapons_manager.has_method("has_all_weapons_max_level"):
		all_weapons_max_level = weapons_manager.has_all_weapons_max_level()
	
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + weapon_count + salt)
	
	var can_level_up = weapon_count > 0 and not all_weapons_max_level
	
	if not can_generate_new_weapon and not can_level_up:
		return null
	if can_generate_new_weapon and not can_level_up:
		return _generate_new_weapon_upgrade(salt)
	if not can_generate_new_weapon and can_level_up:
		return _generate_weapon_level_up_upgrade(weapons_manager, salt)
	
	if rng.randf() < 0.5:
		return _generate_new_weapon_upgrade(salt)
	else:
		return _generate_weapon_level_up_upgrade(weapons_manager, salt)

func _generate_new_weapon_upgrade(salt: int = 0) -> UpgradeData:
	var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
	if all_weapon_ids.is_empty():
		return null
	
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + all_weapon_ids.size() + salt)
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

func _generate_weapon_level_up_upgrade(weapons_manager, salt: int = 0) -> UpgradeData:
	if not weapons_manager.has_method("get_upgradeable_weapon_types"):
		return null
	
	var upgradeable_weapons = weapons_manager.get_upgradeable_weapon_types()
	if upgradeable_weapons.is_empty():
		return null
	
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + upgradeable_weapons.size() + salt)
	var weapon_id = upgradeable_weapons[rng.randi_range(0, upgradeable_weapons.size() - 1)]
	
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	var lowest_weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
	if not lowest_weapon:
		return null
	
	var current_level = lowest_weapon.weapon_level
	var target_level = current_level + 1
	
	var upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP,
		weapon_data.weapon_name + " 等级+1",
		new_weapon_cost,
		weapon_data.texture_path,
		weapon_id
	)
	upgrade.description = "提升武器等级 (当前等级: %d)" % current_level
	upgrade.quality = target_level
	upgrade.base_cost = new_weapon_cost
	upgrade.calculate_weapon_upgrade_cost()
	
	return upgrade

func _generate_attribute_upgrade(quality: int, salt: int = 0) -> UpgradeData:
	var all_upgrade_ids = UpgradeDatabase.get_all_upgrade_ids()
	var quality_upgrades: Array[Dictionary] = []
	var total_weight: int = 0
	
	for upgrade_id in all_upgrade_ids:
		var upgrade_data = UpgradeDatabase.get_upgrade_data(upgrade_id)
		if not upgrade_data or upgrade_data.quality != quality:
			continue
		var weight = upgrade_data.weight
		if weight <= 0:
			continue
		quality_upgrades.append({"id": upgrade_id, "weight": weight})
		total_weight += weight
	
	if quality_upgrades.is_empty():
		return null
	
	var current_wave = _get_current_wave()
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + quality_upgrades.size() + salt)
	
	var random_value = rng.randi_range(0, total_weight - 1)
	var accumulated_weight = 0
	var selected_upgrade_id: String = ""
	
	for upgrade_info in quality_upgrades:
		accumulated_weight += upgrade_info["weight"]
		if random_value < accumulated_weight:
			selected_upgrade_id = upgrade_info["id"]
			break
	
	if selected_upgrade_id == "":
		selected_upgrade_id = quality_upgrades[-1]["id"]
	
	var upgrade_data = UpgradeDatabase.get_upgrade_data(selected_upgrade_id)
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
	upgrade_copy.weight = upgrade_data.weight
	upgrade_copy.attribute_changes = upgrade_data.attribute_changes.duplicate(true)
	
	if upgrade_data.stats_modifier:
		upgrade_copy.stats_modifier = upgrade_data.stats_modifier.clone()
	
	upgrade_copy.custom_value = upgrade_data.custom_value
	return upgrade_copy
