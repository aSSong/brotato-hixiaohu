extends Control
class_name UpgradeShop

## 升级商店
## 每波结束后弹出，允许玩家购买升级
## 负责管理升级选项的生成、刷新、购买逻辑

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

## 常量
const WEAPON_SPAWN_CHANCE := 0.25
const FLIP_ANIMATION_DELAY := 0.08
const SHOP_SLOTS := 4 # 商店槽位数量
const costbywave_multiA := 0.5 # 波次价格修正系数a
const costbywave_multiB := 0.05 # 波次价格修正系数b

## 当前显示的升级选项（最多4个）
var current_upgrades: Array[UpgradeData] = []
var refresh_cost: int = 2  # 刷新费用，每次x2
var base_refresh_cost: int = 2  # 基础刷新费用

## 锁定的升级选项（key: 位置索引 0-3, value: UpgradeData）
var locked_upgrades: Dictionary = {}

## 武器相关参数
var new_weapon_cost: int = 5 # 新武器基础价格
#var green_weapon_multi: int = 2 #绿色武器价格倍率

## 缓存的管理器引用
var _cached_weapons_manager: Node = null
var _cached_wave_manager: Node = null
var _cached_player: Node = null

## 信号
signal upgrade_purchased(upgrade: UpgradeData)
signal shop_closed()

## 升级选项预制（用于UI显示）
var upgrade_option_scene = preload("res://scenes/UI/upgrade_option.tscn")

## 计算带波次修正的价格
## 公式：最终价格 = floor(基础价格 + 波数 + (基础价格 × 0.1 × 波数))
## 静态版本，供 UpgradeOption 等外部调用
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
	var adjusted_cost = float(base_cost) + float(wave_number)*costbywave_multiA + (float(base_cost) * costbywave_multiB * float(wave_number))
	return int(floor(adjusted_cost))

## 实例方法版本的价格计算（可利用缓存）
func _calculate_cost_instance(base_cost: int) -> int:
	var wave_number: int = _get_current_wave()
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
	
	# 缓存管理器引用
	_cache_managers()
	
	# 监听钥匙变化信号
	if GameMain.has_signal("gold_changed"):
		if not GameMain.gold_changed.is_connected(_on_gold_changed):
			GameMain.gold_changed.connect(_on_gold_changed)
	
	_update_refresh_cost_display()
	
	# 初始化玩家信息显示
	_initialize_player_info()
	
	hide()  # 初始隐藏
	print("升级商店 _ready() 完成，节点路径: ", get_path(), " 组: ", get_groups())
	print("upgrade_container: ", upgrade_container, " refresh_button: ", refresh_button, " close_button: ", close_button)
	print("weapon_container: ", weapon_container)

## 缓存常用的管理器引用
func _cache_managers() -> void:
	var tree = get_tree()
	
	# 缓存 WeaponsManager
	if not _cached_weapons_manager:
		_cached_weapons_manager = tree.get_first_node_in_group("weapons_manager")
		if not _cached_weapons_manager:
			_cached_weapons_manager = tree.get_first_node_in_group("weapons")
	
	# 缓存 WaveManager
	if not _cached_wave_manager:
		_cached_wave_manager = tree.get_first_node_in_group("wave_system")
		if not _cached_wave_manager:
			_cached_wave_manager = tree.get_first_node_in_group("wave_manager")
	
	# 缓存 Player
	if not _cached_player:
		_cached_player = tree.get_first_node_in_group("player")

## 打开商店
func open_shop() -> void:
	print("升级商店 open_shop() 被调用")
	
	# 确保所有@onready变量都已初始化
	if not is_inside_tree():
		await get_tree().process_frame
	
	# 刷新缓存（以防场景重载）
	_cache_managers()
	
	# 设置进程模式为始终处理（即使在暂停时）
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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

## 关闭商店
func close_shop() -> void:
	hide()
	shop_closed.emit()

## 生成升级选项（4个）
## 优化版：复用现有节点，消除闪烁
## 原理：
## 1. 先播放现有非锁定选项的翻出动画（Flip Out）
## 2. 更新数据，将锁定选项恢复，并生成新选项填补空位
## 3. 复用UI节点，只更新数据，避免 queue_free 造成的空帧闪烁
## 4. 对非锁定选项，设置 scale.x=0 后更新数据，再播放翻入动画（Flip In）
func generate_upgrades() -> void:
	# 1. 播放翻出动画（只对非锁定的选项）
	# 锁定的选项保持原样，非锁定的翻出并隐藏（scale.x -> 0）
	await _play_flip_out_animations()
	
	# 2. 准备新的数据列表
	var new_upgrades_list: Array[UpgradeData] = []
	new_upgrades_list.resize(SHOP_SLOTS)
	
	# 恢复锁定的升级到对应位置
	for position_index in range(SHOP_SLOTS):
		if locked_upgrades.has(position_index):
			var locked_upgrade = locked_upgrades[position_index]
			# 创建升级数据的副本（保留锁定价格）
			var upgrade_copy = locked_upgrade.clone()
			new_upgrades_list[position_index] = upgrade_copy
			# 同步更新字典中的引用为新副本
			locked_upgrades[position_index] = upgrade_copy
			# print("[UpgradeShop] 恢复锁定升级到位置 %d: %s" % [position_index, upgrade_copy.name])
	
	# 生成新升级填补空位
	for position_index in range(SHOP_SLOTS):
		if new_upgrades_list[position_index] != null:
			continue # 已被锁定占位
			
		var new_upgrade = _generate_single_upgrade(new_upgrades_list)
		if new_upgrade:
			new_upgrades_list[position_index] = new_upgrade
		else:
			print("[UpgradeShop] 警告: 无法生成位置 %d 的升级选项" % position_index)

	# --- 保底逻辑检查：确保至少有1个属性和1个武器（如果可能） ---
	# 仅在全刷新时执行，局部补货不执行
	# 统计现有数量（包括锁定和新生成的）
	var weapon_count = 0
	var attribute_count = 0
	var non_locked_indices: Array[int] = []
	
	for i in range(SHOP_SLOTS):
		if new_upgrades_list[i]:
			if new_upgrades_list[i].upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON or new_upgrades_list[i].upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
				weapon_count += 1
			else:
				attribute_count += 1
		
		if not locked_upgrades.has(i):
			non_locked_indices.append(i)
	
	# 如果全是武器（且有非锁定槽位），强制将一个非锁定槽位改为属性
	if weapon_count == SHOP_SLOTS and non_locked_indices.size() > 0:
		var target_index = non_locked_indices.pick_random()
		var new_attribute = _generate_attribute_upgrade_force(new_upgrades_list)
		if new_attribute:
			new_upgrades_list[target_index] = new_attribute
			# 重新固定价格
			new_attribute.current_price = _calculate_cost_instance(new_attribute.actual_cost)
			print("[UpgradeShop] 保底触发：位置 %d 强制从武器改为属性" % target_index)
	
	# 如果全是属性（且有非锁定槽位，且允许生成武器），强制将一个非锁定槽位改为武器
	# 注意：如果已满6武器且满级，可能无法生成武器，此时跳过
	elif attribute_count == SHOP_SLOTS and non_locked_indices.size() > 0:
		# 尝试生成一个武器
		var dummy_salt = randi()
		var new_weapon = _generate_weapon_upgrade(new_upgrades_list, dummy_salt)
		if new_weapon:
			var target_index = non_locked_indices.pick_random()
			new_upgrades_list[target_index] = new_weapon
			# 重新固定价格
			new_weapon.current_price = _calculate_cost_instance(new_weapon.actual_cost)
			print("[UpgradeShop] 保底触发：位置 %d 强制从属性改为武器" % target_index)
	
	# 更新当前数据
	current_upgrades = new_upgrades_list
	
	# 3. 同步UI节点（对象池模式）
	# 确保容器中至少有4个节点
	if not upgrade_option_scene:
		push_error("升级选项场景未加载！")
		return
		
	while upgrade_container.get_child_count() < SHOP_SLOTS:
		var option_ui = upgrade_option_scene.instantiate() as UpgradeOption
		upgrade_container.add_child(option_ui)
		# 初始连接信号
		if option_ui.has_signal("purchased"):
			option_ui.purchased.connect(_on_upgrade_purchased)
		if option_ui.has_signal("lock_state_changed"):
			option_ui.lock_state_changed.connect(_on_upgrade_lock_state_changed)
	
	# 清理多余节点
	while upgrade_container.get_child_count() > SHOP_SLOTS:
		var child = upgrade_container.get_child(upgrade_container.get_child_count() - 1)
		child.queue_free()
	
	# 确保所有新添加的节点已进入树
	if not is_inside_tree():
		await get_tree().process_frame
	
	# 4. 更新每个节点的数据和状态
	for i in range(SHOP_SLOTS):
		var option_ui = upgrade_container.get_child(i) as UpgradeOption
		var upgrade_data = new_upgrades_list[i]
		var is_locked = locked_upgrades.has(i)
		
		option_ui.position_index = i
		
		# 显式确保节点可见
		option_ui.visible = true
		
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
			
			var delay = i * FLIP_ANIMATION_DELAY
			if option_ui.has_method("play_flip_in_animation"):
				option_ui.play_flip_in_animation(delay)
	
	print("[UpgradeShop] 升级选项生成完成 (优化模式), 数量: %d" % SHOP_SLOTS)

## 创建升级选项UI实例（辅助函数，仅用于补充节点）
## skip_animation: 如果为true，不设置初始 scale.x = 0（锁定的选项直接显示）
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
		# 锁定：保存当前价格
		# 优先使用 current_price，如果没有则实时计算
		var adjusted_cost = upgrade.current_price if upgrade.current_price > 0 else _calculate_cost_instance(upgrade.actual_cost)
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
	return source.clone()

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
## 优化版：只刷新被购买的那一个格子
## 流程：
## 1. 扣除钥匙
## 2. 移除锁定状态（如果已锁定）
## 3. 应用升级效果（武器升级需等待异步加载）
## 4. 局部刷新 UI（Flip Out -> 生成新数据 -> Flip In）
func _on_upgrade_purchased(upgrade: UpgradeData) -> void:
	# 如果有锁定价格，使用锁定价格；否则使用固定的 current_price
	var adjusted_cost: int
	if upgrade.locked_cost >= 0:
		adjusted_cost = upgrade.locked_cost
	elif upgrade.current_price > 0:
		adjusted_cost = upgrade.current_price
	else:
		# 兼容性保底：如果 current_price 未设置，才实时计算
		adjusted_cost = _calculate_cost_instance(upgrade.actual_cost)
	
	if GameMain.gold < adjusted_cost:
		print("钥匙不足！需要 %d，当前 %d" % [adjusted_cost, GameMain.gold])
		return
	
	# 扣除钥匙（使用修正后的价格）
	GameMain.remove_gold(adjusted_cost)
	
	# 更新刷新按钮状态（钥匙变化后，通过信号自动处理，这里只需更新显示）
	_update_refresh_cost_display()
	
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
		await UpgradeManager.apply_upgrade(upgrade, get_tree())
		# 等待一帧确保武器已完全添加到场景树
		await get_tree().process_frame
		_update_weapon_list()
	else:
		UpgradeManager.apply_upgrade(upgrade, get_tree())
	
	upgrade_purchased.emit(upgrade)
	
	# 找到被购买选项的UI节点和位置
	var purchased_option: UpgradeOption = null
	var purchased_index: int = -1
	
	for child in upgrade_container.get_children():
		if child is UpgradeOption:
			var option = child as UpgradeOption
			if option.upgrade_data == upgrade:
				purchased_option = option
				purchased_index = option.position_index
				break
	
	# 局部刷新逻辑：只针对被购买的那个格子
	if purchased_option:
		# 1. 翻出动画（只针对这一个，其他不动）
		if purchased_option.has_method("play_flip_out_animation"):
			await purchased_option.play_flip_out_animation().finished
		
		# 2. 从 current_upgrades 移除旧数据
		if purchased_index >= 0 and purchased_index < current_upgrades.size():
			# 3. 生成新数据
			# 临时将旧数据置空，防止 _generate_single_upgrade 认为它还在
			current_upgrades[purchased_index] = null
			
			var new_upgrade = _generate_single_upgrade(current_upgrades)
			
			# 4. 更新数据到现有节点（复用节点）
			if new_upgrade:
				current_upgrades[purchased_index] = new_upgrade
				purchased_option.set_upgrade_data(new_upgrade)
				purchased_option.position_index = purchased_index # 保持索引
				purchased_option.set_lock_state(false) # 新生成的默认不锁定
				
				# 显式恢复可见
				purchased_option.visible = true
				
				# 5. 翻入动画
				if purchased_option.has_method("play_flip_in_animation"):
					purchased_option.play_flip_in_animation(0.0)
			else:
				print("警告：购买后无法生成新升级")
				# 隐藏节点，避免显示旧数据
				purchased_option.visible = false

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

## 监听钥匙变化
func _on_gold_changed(_new_amount: int, _change: int) -> void:
	_update_refresh_cost_display()
	# 也可以在这里触发子项的购买按钮状态更新，如果需要的话
	# for child in upgrade_container.get_children():
	# 	if child is UpgradeOption:
	# 		child._update_buy_button() 

## 更新刷新费用显示
func _update_refresh_cost_display() -> void:
	if refresh_cost_label:
		refresh_cost_label.text = " 🔑 %d" % refresh_cost
	
	# 检查钥匙是否足够刷新，不足时按钮变灰
	if refresh_button:
		var can_afford = GameMain.gold >= refresh_cost
		if can_afford:
			refresh_button.modulate = Color.WHITE
		else:
			refresh_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色

## 初始化玩家信息显示
func _initialize_player_info() -> void:
	# 显示已选择的职业头像
	var class_id = GameMain.selected_class_id
	if class_id != "" and player_portrait:
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.portrait:
			player_portrait.texture = class_data.portrait
	
	# 显示玩家名字（从存档读取）
	if player_name_label:
		var saved_name = SaveManager.get_player_name()
		if saved_name != "":
			player_name_label.text = saved_name
		else:
			player_name_label.text = "玩家"

## 更新武器列表显示（使用 WeaponCompact 组件）
func _update_weapon_list() -> void:
	# 确保武器容器存在
	if not weapon_container:
		weapon_container = get_node_or_null("%WeaponContainer")
		if not weapon_container:
			print("[UpgradeShop] 无法找到武器容器")
			return
	
	# 清空现有武器显示
	for child in weapon_container.get_children():
		child.queue_free()
	
	# 使用缓存的 WeaponsManager
	if not _cached_weapons_manager:
		# 尝试重新查找
		_cached_weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
		if not _cached_weapons_manager:
			_cached_weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if not _cached_weapons_manager:
		print("[UpgradeShop] 无法找到武器管理器")
		return
	
	# 获取所有武器（按获得顺序）
	var weapons = _cached_weapons_manager.get_all_weapons()
	# print("[UpgradeShop] 找到武器管理器，武器数量: ", weapons.size())
	
	# 显示6个武器槽位
	for i in range(6):
		if not weapon_compact_scene:
			continue
			
		var compact = weapon_compact_scene.instantiate()
		weapon_container.add_child(compact)
		
		if i < weapons.size() and weapons[i] is BaseWeapon:
			# 有武器 - 显示武器信息
			var weapon = weapons[i] as BaseWeapon
			var weapon_data = weapon.weapon_data
			var weapon_level = weapon.weapon_level
			
			if weapon_data:
				if compact.has_method("setup_weapon_from_data"):
					compact.setup_weapon_from_data(weapon_data, weapon_level)
				elif compact.has_method("setup_weapon"):
					compact.setup_weapon(weapon_data.weapon_id, weapon_level)
		else:
			# 空槽位 - 显示"空缺"，不显示图片
			if compact.has_method("set_weapon_name"):
				compact.set_weapon_name("空缺")
			if compact.has_method("set_weapon_texture"):
				compact.set_weapon_texture(null)  # 不显示图片
			if compact.has_method("set_quality_level"):
				compact.set_quality_level(1)  # 灰色背景
	
	print("[UpgradeShop] 武器列表已更新，当前武器数量: ", weapons.size())

## ========== 新的商店刷新系统 ==========

## 获取当前波数
func _get_current_wave() -> int:
	if _cached_wave_manager and "current_wave" in _cached_wave_manager:
		return _cached_wave_manager.current_wave
	
	# Fallback attempt
	var wave_manager = get_tree().get_first_node_in_group("wave_system")
	if wave_manager and "current_wave" in wave_manager:
		_cached_wave_manager = wave_manager
		return wave_manager.current_wave
		
	return 1

## 获取玩家幸运值
func _get_player_luck() -> float:
	if _cached_player and _cached_player.current_class:
		return _cached_player.current_class.luck
	return 0.0

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
	rng.seed = hash(Time.get_ticks_msec() + current_wave + int(luck_value))
	var roll = rng.randf_range(0.0, 100.0)
	
	var accumulated_prob = 0.0
	for i in range(quality_probabilities.size()):
		var quality = quality_probabilities[i][0]
		var prob = quality_probabilities[i][1]
		
		# 计算实际可用概率（从剩余概率中分配）
		var available_prob = 100.0 - accumulated_prob
		var actual_prob = min(prob, available_prob)
		
		if roll < accumulated_prob + actual_prob:
			return quality
		
		accumulated_prob += actual_prob
	
	# 保底返回白色
	return UpgradeData.Quality.WHITE

## 生成单个upgrade选项（独立判定）
func _generate_single_upgrade(existing_upgrades: Array[UpgradeData]) -> UpgradeData:
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + existing_upgrades.size())
	
	# 决定生成类型
	var is_weapon = false
	
	# 移除旧的强制保底逻辑，回归纯随机（受基础概率限制）
	# 只有在全刷新 generate_upgrades 中才进行整体平衡检查
	is_weapon = rng.randf() < WEAPON_SPAWN_CHANCE
	
	var attempts = 0
	var max_attempts = 50
	
	while attempts < max_attempts:
		attempts += 1
		
		# Generate a unique salt for this attempt to prevent same-seed RNG in fast loops
		var salt = randi()
		
		var upgrade: UpgradeData = null
		
		if is_weapon:
			upgrade = _generate_weapon_upgrade(existing_upgrades, salt)
		else:
			# 获取当前波数和幸运值
			var luck_value = _get_player_luck()
			
			# 根据幸运值决定品质
			var quality = _get_quality_by_luck(luck_value, current_wave)
			
			upgrade = _generate_attribute_upgrade(quality, salt)
			# 如果指定品质生成失败（可能该品质没有对应升级），尝试保底使用白色品质
			if upgrade == null:
				upgrade = _generate_attribute_upgrade(UpgradeData.Quality.WHITE, salt)
		
		if upgrade == null:
			# 如果生成失败，尝试切换类型
			if is_weapon:
				# 武器生成失败，尝试生成属性
				var luck_value = _get_player_luck()
				var quality = _get_quality_by_luck(luck_value, current_wave)
				upgrade = _generate_attribute_upgrade(quality, salt)
				# 保底策略
				if upgrade == null:
					upgrade = _generate_attribute_upgrade(UpgradeData.Quality.WHITE, salt)
			else:
				# 属性生成失败，尝试生成武器
				upgrade = _generate_weapon_upgrade(existing_upgrades, salt)
			
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
			# 计算并固定当前波次的最终售价
			# 这样即使后续 current_wave 发生变化（如进入下一关），该商品价格也保持不变
			upgrade.current_price = _calculate_cost_instance(upgrade.actual_cost)
			return upgrade
	
	# print("[UpgradeShop] 警告: 尝试 %d 次后仍无法生成不重复的升级" % max_attempts)
	return null

## 辅助函数：强制生成属性（用于保底）
func _generate_attribute_upgrade_force(existing_upgrades: Array[UpgradeData]) -> UpgradeData:
	var current_wave = _get_current_wave()
	var luck_value = _get_player_luck()
	var quality = _get_quality_by_luck(luck_value, current_wave)
	
	var attempts = 0
	while attempts < 10:
		attempts += 1
		var salt = randi()
		var upgrade = _generate_attribute_upgrade(quality, salt)
		if not upgrade:
			upgrade = _generate_attribute_upgrade(UpgradeData.Quality.WHITE, salt)
			
		if upgrade:
			var is_duplicate = false
			for existing in existing_upgrades:
				if existing == null: continue
				if _is_same_upgrade(existing, upgrade):
					is_duplicate = true
					break
			if not is_duplicate:
				return upgrade
	return null

## 生成武器相关upgrade
func _generate_weapon_upgrade(existing_upgrades: Array[UpgradeData], salt: int = 0) -> UpgradeData:
	# 使用缓存的 WeaponsManager
	if not _cached_weapons_manager:
		_cached_weapons_manager = get_tree().get_first_node_in_group("weapons_manager")
		if not _cached_weapons_manager:
			_cached_weapons_manager = get_tree().get_first_node_in_group("weapons")
	
	if not _cached_weapons_manager:
		return null
	
	var weapon_count = 0
	if _cached_weapons_manager.has_method("get_weapon_count"):
		weapon_count = _cached_weapons_manager.get_weapon_count()
	
	# 统计商店中的new weapon数量（包括锁定的和当前生成的）
	var new_weapon_count_in_shop = 0
	for up in existing_upgrades:
		if up and up.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
			new_weapon_count_in_shop += 1
	
	# 检查是否可以生成新武器
	var can_generate_new_weapon = (weapon_count + new_weapon_count_in_shop) < 6
	
	# 检查是否所有武器都满级
	var all_weapons_max_level = false
	if _cached_weapons_manager.has_method("has_all_weapons_max_level"):
		all_weapons_max_level = _cached_weapons_manager.has_all_weapons_max_level()
	
	var rng = RandomNumberGenerator.new()
	var current_wave = _get_current_wave()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + weapon_count + salt)
	
	# 决定生成NEW_WEAPON还是WEAPON_LEVEL_UP
	var can_level_up = weapon_count > 0 and not all_weapons_max_level
	
	if not can_generate_new_weapon and not can_level_up:
		# 既不能生成新武器，也不能升级武器
		return null
	
	if can_generate_new_weapon and not can_level_up:
		# 只能生成新武器
		return _generate_new_weapon_upgrade(salt)
	
	if not can_generate_new_weapon and can_level_up:
		# 只能升级武器
		return _generate_weapon_level_up_upgrade(_cached_weapons_manager, salt)
	
	# 两者都可以，随机选择
	if rng.randf() < 0.5:
		return _generate_new_weapon_upgrade(salt)
	else:
		return _generate_weapon_level_up_upgrade(_cached_weapons_manager, salt)

## 生成新武器upgrade
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

## 生成武器升级upgrade
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
	
	# 获取当前最低等级的武器
	var lowest_weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
	if not lowest_weapon:
		return null
	
	var current_level = lowest_weapon.weapon_level
	var target_level = current_level + 1  # 目标等级
	
	var upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP,
		"升级: " + weapon_data.weapon_name,
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
func _generate_attribute_upgrade(quality: int, salt: int = 0) -> UpgradeData:
	# 获取所有upgrade ID
	var all_upgrade_ids = UpgradeDatabase.get_all_upgrade_ids()
	
	# 筛选出指定品质的upgrade，同时收集权重信息（跳过权重<=0的升级）
	var quality_upgrades: Array[Dictionary] = []  # [{id: String, weight: int}]
	var total_weight: int = 0
	
	for upgrade_id in all_upgrade_ids:
		var upgrade_data = UpgradeDatabase.get_upgrade_data(upgrade_id)
		if not upgrade_data or upgrade_data.quality != quality:
			continue
		
		# 检查权重：权重必须>0才会出现在商店中（0、负数都会被跳过）
		# 注意：int类型不能为null，未设置时默认值为0，也会被跳过
		var weight = upgrade_data.weight
		if weight <= 0:
			continue
		
		quality_upgrades.append({"id": upgrade_id, "weight": weight})
		total_weight += weight
	
	if quality_upgrades.is_empty():
		# print("[UpgradeShop] 警告: 没有品质为 %s 的升级选项" % UpgradeData.get_quality_name(quality))
		return null
	
	# 使用加权随机选择
	var current_wave = _get_current_wave()
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Time.get_ticks_msec() + current_wave + quality_upgrades.size() + salt)
	
	# 生成0到总权重之间的随机数
	var random_value = rng.randi_range(0, total_weight - 1)

	
	# 累加权重，找到对应的升级
	var accumulated_weight = 0
	var selected_upgrade_id: String = ""
	for upgrade_info in quality_upgrades:
		accumulated_weight += upgrade_info["weight"]
		if random_value < accumulated_weight:
			selected_upgrade_id = upgrade_info["id"]
			break
	
	# 如果由于浮点误差没有选中，选择最后一个
	if selected_upgrade_id == "":
		selected_upgrade_id = quality_upgrades[-1]["id"]
	
	var upgrade_data = UpgradeDatabase.get_upgrade_data(selected_upgrade_id)
	
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
	upgrade_copy.weight = upgrade_data.weight
	upgrade_copy.attribute_changes = upgrade_data.attribute_changes.duplicate(true)
	
	# ⭐ 关键：复制stats_modifier（新属性系统）
	if upgrade_data.stats_modifier:
		upgrade_copy.stats_modifier = upgrade_data.stats_modifier.clone()
	
	# 复制自定义值
	upgrade_copy.custom_value = upgrade_data.custom_value
	
	return upgrade_copy
