extends CanvasLayer

## 联网模式游戏内HUD界面
## 负责显示所有玩家的状态信息

# UI组件引用
@onready var players_container: VBoxContainer = $PlayersPanel/MarginContainer/VBoxContainer/PlayersContainer
@onready var server_info_label: Label = $ServerInfoLabel

# 玩家信息项场景（动态创建）
var player_info_items: Dictionary = {}  # peer_id -> Control

# 调试用名字列表
var _debug_label: Label = null

# 角色提示面板
var _role_hint_panel: PanelContainer = null

# Impostor 叛变提示框（屏幕下方）
var _betrayal_hint_panel: PanelContainer = null

# 更新间隔
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # 每0.1秒更新一次

# 初始化完成标志
var _initialized: bool = false

func _ready() -> void:
	# 创建调试标签
	_create_debug_label()
	
	# 创建角色提示面板
	_create_role_hint_panel()
	
	# 创建叛变提示框
	_create_betrayal_hint_panel()
	
	# 连接叛变信号
	NetworkPlayerManager.impostor_betrayal_triggered.connect(_on_impostor_betrayed)
	
	# 延迟初始化，等待玩家加载
	await get_tree().create_timer(0.5).timeout
	_init_player_list()
	
	# 显示服务器信息
	_update_server_info()
	
	# 更新角色提示
	_update_role_hint()
	
	# 更新叛变提示
	_update_betrayal_hint()
	
	_initialized = true


func _process(delta: float) -> void:
	if not _initialized:
		return
	
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_all_players()
		_update_role_hint()  # 定期更新角色提示
		_update_betrayal_hint()  # 定期更新叛变提示


## 初始化玩家列表
func _init_player_list() -> void:
	# 清空现有列表
	_clear_player_list()
	
	var local_peer_id = NetworkManager.get_peer_id()
	print("[GameUIOnline] 初始化玩家列表, local_peer_id=%d, players=%s" % [local_peer_id, str(NetworkPlayerManager.players.keys())])
	
	# 为每个玩家创建信息项
	for peer_id in NetworkPlayerManager.players.keys():
		# 跳过服务器自身（peer_id=1）和无效的 peer_id
		if peer_id <= 1:
			print("[GameUIOnline] 跳过无效 peer_id: %d" % peer_id)
			continue
		var player = NetworkPlayerManager.players[peer_id]
		if player and is_instance_valid(player):
			_add_player_info(peer_id, player)


## 清空玩家列表
func _clear_player_list() -> void:
	# 清空字典中的引用
	for peer_id in player_info_items.keys():
		var item = player_info_items[peer_id]
		if item and is_instance_valid(item):
			item.queue_free()
	player_info_items.clear()
	
	# 同时清理容器中的所有子节点（防止残留）
	if players_container:
		for child in players_container.get_children():
			child.queue_free()


## 添加玩家信息项
func _add_player_info(peer_id: int, player: Node) -> void:
	if player_info_items.has(peer_id):
		return
	
	var item = _create_player_info_item(peer_id, player)
	players_container.add_child(item)
	player_info_items[peer_id] = item


## 创建玩家信息项
func _create_player_info_item(peer_id: int, player: Node) -> Control:
	var item = PanelContainer.new()
	item.name = "PlayerInfo_%d" % peer_id
	item.custom_minimum_size = Vector2(280, 90)  # 增加高度以容纳钥匙信息
	
	# 创建样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = player.get_class_color()
	item.add_theme_stylebox_override("panel", style)
	
	# 主容器
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	item.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	# 玩家图标（颜色方块代表 skin）
	var icon = ColorRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(50, 50)
	icon.color = player.get_class_color()
	hbox.add_child(icon)
	
	# 信息容器
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	
	# 玩家名称
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = player.display_name if "display_name" in player else "Player %d" % peer_id
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 标记本地玩家（使用 NetworkManager.get_peer_id() 确保准确）
	var local_peer_id = NetworkManager.get_peer_id()
	if peer_id == local_peer_id:
		name_label.text += " (你)"
		name_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	
	vbox.add_child(name_label)
	
	# HP 条
	var hp_container = HBoxContainer.new()
	hp_container.name = "HBoxContainer"
	hp_container.add_theme_constant_override("separation", 5)
	vbox.add_child(hp_container)
	
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP:"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_container.add_child(hp_label)
	
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(150, 20)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.max_value = player.max_hp if "max_hp" in player else 100
	hp_bar.value = player.now_hp if "now_hp" in player else 100
	hp_bar.show_percentage = false
	
	# HP条样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.2, 0.2, 1.0)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	hp_container.add_child(hp_bar)
	
	# HP 数值
	var hp_value = Label.new()
	hp_value.name = "HPValue"
	hp_value.text = "%d/%d" % [hp_bar.value, hp_bar.max_value]
	hp_value.add_theme_font_size_override("font_size", 12)
	hp_value.custom_minimum_size = Vector2(60, 0)
	hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_container.add_child(hp_value)
	
	# 钥匙信息容器
	var keys_container = HBoxContainer.new()
	keys_container.name = "KeysContainer"
	keys_container.add_theme_constant_override("separation", 15)
	vbox.add_child(keys_container)
	
	# 普通钥匙（Gold）
	var gold_container = HBoxContainer.new()
	gold_container.name = "GoldContainer"
	gold_container.add_theme_constant_override("separation", 3)
	keys_container.add_child(gold_container)
	
	var gold_icon = Label.new()
	gold_icon.text = "🔑"
	gold_icon.add_theme_font_size_override("font_size", 14)
	gold_container.add_child(gold_icon)
	
	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "%d" % (player.gold if "gold" in player else 0)
	gold_label.add_theme_font_size_override("font_size", 14)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # 金色
	gold_label.custom_minimum_size = Vector2(30, 0)
	gold_container.add_child(gold_label)
	
	# 大师钥匙（Master Key）
	var master_container = HBoxContainer.new()
	master_container.name = "MasterContainer"
	master_container.add_theme_constant_override("separation", 3)
	keys_container.add_child(master_container)
	
	var master_icon = Label.new()
	master_icon.text = "🗝️"
	master_icon.add_theme_font_size_override("font_size", 14)
	master_container.add_child(master_icon)
	
	var master_label = Label.new()
	master_label.name = "MasterKeyLabel"
	master_label.text = "%d" % (player.master_key if "master_key" in player else 0)
	master_label.add_theme_font_size_override("font_size", 14)
	master_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  # 蓝色
	master_label.custom_minimum_size = Vector2(30, 0)
	master_container.add_child(master_label)
	
	return item


## 更新所有玩家信息
func _update_all_players() -> void:
	# 更新调试标签
	_update_debug_label()
	
	# 检查是否有新玩家加入（跳过服务器 peer_id=1 和无效的 peer_id）
	for peer_id in NetworkPlayerManager.players.keys():
		if peer_id <= 1:
			continue
		if not player_info_items.has(peer_id):
			var player = NetworkPlayerManager.players[peer_id]
			if player and is_instance_valid(player):
				_add_player_info(peer_id, player)
	
	# 检查是否有玩家离开
	var to_remove: Array = []
	for peer_id in player_info_items.keys():
		if not NetworkPlayerManager.players.has(peer_id) or not is_instance_valid(NetworkPlayerManager.players[peer_id]):
			to_remove.append(peer_id)
	
	for peer_id in to_remove:
		_remove_player_info(peer_id)
	
	# 更新每个玩家的信息
	for peer_id in player_info_items.keys():
		_update_player_info(peer_id)


## 更新单个玩家信息
func _update_player_info(peer_id: int) -> void:
	if not NetworkPlayerManager.players.has(peer_id):
		return
	var player = NetworkPlayerManager.players[peer_id]
	if not player or not is_instance_valid(player):
		return
	
	var item = player_info_items.get(peer_id)
	if not item or not is_instance_valid(item):
		return
	
	var local_peer_id = NetworkManager.get_peer_id()
	var player_role = player.get("player_role_id")
	var is_betrayed_impostor = NetworkPlayerManager.impostor_betrayed and peer_id == NetworkPlayerManager.impostor_peer_id
	
	# 更新名字标签
	var name_label = item.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/NameLabel")
	if name_label and "display_name" in player:
		var new_name = player.display_name if player.display_name != "" else "Player %d" % peer_id
		
		# 添加角色标记
		if is_betrayed_impostor:
			new_name = "🔪 " + new_name + " [叛变者]"
		elif player_role == NetworkPlayerManager.ROLE_BOSS:
			new_name = "👹 " + new_name + " [BOSS]"
		
		if peer_id == local_peer_id:
			new_name += " (你)"
		
		if name_label.text != new_name:
			name_label.text = new_name
		
		# 更新颜色
		if is_betrayed_impostor:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # 橙色
		elif player_role == NetworkPlayerManager.ROLE_BOSS:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # 红色
		elif peer_id == local_peer_id:
			name_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))  # 绿色
		else:
			name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 更新图标颜色（skin 可能在游戏开始时更新）
	var icon = item.get_node_or_null("MarginContainer/HBoxContainer/Icon")
	if icon:
		icon.color = player.get_class_color()
	
	# 更新边框颜色
	var style = item.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if is_betrayed_impostor:
			style.border_color = Color(1.0, 0.5, 0.0)  # 橙色边框
		elif player_role == NetworkPlayerManager.ROLE_BOSS:
			style.border_color = Color(1.0, 0.3, 0.3)  # 红色边框
		else:
			style.border_color = icon.color if icon else player.get_class_color()
	
	# 更新 HP
	var hp_bar = item.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/HPBar")
	var hp_value = item.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/HPValue")
	
	if hp_bar and "now_hp" in player and "max_hp" in player:
		hp_bar.max_value = player.max_hp
		hp_bar.value = max(0, player.now_hp)
		
		# 根据血量百分比改变颜色
		var hp_percent = float(player.now_hp) / float(player.max_hp) if player.max_hp > 0 else 0
		var fill_style = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if hp_percent > 0.5:
				fill_style.bg_color = Color(0.3, 0.8, 0.3)  # 绿
			elif hp_percent > 0.25:
				fill_style.bg_color = Color(0.9, 0.7, 0.2)  # 黄
			else:
				fill_style.bg_color = Color(0.8, 0.2, 0.2)  # 红
	
	if hp_value and "now_hp" in player and "max_hp" in player:
		hp_value.text = "%d/%d" % [max(0, player.now_hp), player.max_hp]
	
	# 更新钥匙数量
	var gold_label = item.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/KeysContainer/GoldContainer/GoldLabel")
	if gold_label and "gold" in player:
		gold_label.text = "%d" % player.gold
	
	var master_key_label = item.get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/KeysContainer/MasterContainer/MasterKeyLabel")
	if master_key_label and "master_key" in player:
		master_key_label.text = "%d" % player.master_key


## 移除玩家信息项
func _remove_player_info(peer_id: int) -> void:
	if not player_info_items.has(peer_id):
		return
	
	var item = player_info_items[peer_id]
	if item and is_instance_valid(item):
		item.queue_free()
	player_info_items.erase(peer_id)


## 更新服务器信息
func _update_server_info() -> void:
	if not server_info_label:
		return
	
	if NetworkManager.is_server():
		server_info_label.text = "服务器 | 按 Tab 切换视角"
	else:
		server_info_label.text = "客户端 | Peer ID: %d" % NetworkManager.get_peer_id()


## ==================== 角色提示系统 ====================

## 创建角色提示面板
func _create_role_hint_panel() -> void:
	_role_hint_panel = PanelContainer.new()
	_role_hint_panel.name = "RoleHintPanel"
	
	# 位置：屏幕上方中央
	_role_hint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_role_hint_panel.position = Vector2(-150, 20)
	_role_hint_panel.custom_minimum_size = Vector2(300, 60)
	
	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.5, 0.5)
	_role_hint_panel.add_theme_stylebox_override("panel", style)
	
	# 内容容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_role_hint_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# 角色标签
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(role_label)
	
	# 提示标签
	var hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint_label)
	
	add_child(_role_hint_panel)
	_role_hint_panel.visible = false


## 更新角色提示
func _update_role_hint() -> void:
	if not _role_hint_panel:
		return
	
	var local_player = NetworkPlayerManager.local_player
	if not local_player or not is_instance_valid(local_player):
		_role_hint_panel.visible = false
		return
	
	var role_id = local_player.player_role_id
	var role_label = _role_hint_panel.get_node_or_null("MarginContainer/VBoxContainer/RoleLabel")
	var hint_label = _role_hint_panel.get_node_or_null("MarginContainer/VBoxContainer/HintLabel")
	var style = _role_hint_panel.get_theme_stylebox("panel") as StyleBoxFlat
	
	if not role_label or not hint_label:
		return
	
	match role_id:
		NetworkPlayerManager.ROLE_BOSS:
			role_label.text = "👹 你是 BOSS"
			role_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			hint_label.text = "消灭所有玩家！"
			if style:
				style.border_color = Color(1.0, 0.3, 0.3)
			_role_hint_panel.visible = true
		
		NetworkPlayerManager.ROLE_IMPOSTOR:
			if NetworkPlayerManager.impostor_betrayed:
				role_label.text = "🔪 你是叛变者"
				role_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
				hint_label.text = "消灭所有玩家！"
				if style:
					style.border_color = Color(1.0, 0.5, 0.0)
			else:
				role_label.text = "🎭 你是内鬼"
				role_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
				hint_label.text = "按 B 键叛变（不可撤销）"
				if style:
					style.border_color = Color(1.0, 0.5, 0.0)
			_role_hint_panel.visible = true
		
		NetworkPlayerManager.ROLE_PLAYER:
			role_label.text = "🛡️ 你是玩家"
			role_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			hint_label.text = "击败 BOSS，小心内鬼！"
			if style:
				style.border_color = Color(0.4, 0.8, 1.0)
			_role_hint_panel.visible = true
		
		_:
			_role_hint_panel.visible = false


## 叛变事件处理
func _on_impostor_betrayed(impostor_peer_id: int) -> void:
	print("[GameUIOnline] 收到叛变通知: peer_id=%d" % impostor_peer_id)
	
	# 更新角色提示
	_update_role_hint()
	
	# 更新叛变提示（隐藏）
	_update_betrayal_hint()
	
	# 更新玩家列表中的 Impostor 显示
	_update_player_info(impostor_peer_id)


## 创建叛变提示框（屏幕下方居中，只有 Impostor 可见）
func _create_betrayal_hint_panel() -> void:
	_betrayal_hint_panel = PanelContainer.new()
	_betrayal_hint_panel.name = "BetrayalHintPanel"
	
	# 样式 - 醒目的橙色边框
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.05, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(1.0, 0.5, 0.0)  # 橙色边框
	style.shadow_color = Color(1.0, 0.5, 0.0, 0.3)
	style.shadow_size = 8
	_betrayal_hint_panel.add_theme_stylebox_override("panel", style)
	
	# 内容容器
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	_betrayal_hint_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# 标题
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🎭 你是内鬼"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox.add_child(title_label)
	
	# 按键提示
	var key_hint = Label.new()
	key_hint.name = "KeyHintLabel"
	key_hint.text = "按 [ B ] 键叛变"
	key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_hint.add_theme_font_size_override("font_size", 28)
	key_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(key_hint)
	
	# 警告提示
	var warning_label = Label.new()
	warning_label.name = "WarningLabel"
	warning_label.text = "⚠ 叛变后不可撤销，所有人都会知道你是叛变者"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 14)
	warning_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
	vbox.add_child(warning_label)
	
	add_child(_betrayal_hint_panel)
	_betrayal_hint_panel.visible = false
	
	# 延迟设置位置（等待布局完成）
	call_deferred("_position_betrayal_hint")


## 设置叛变提示框位置（屏幕下方居中）
func _position_betrayal_hint() -> void:
	if not _betrayal_hint_panel:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = _betrayal_hint_panel.size
	
	# 如果还没有计算出大小，使用预估值
	if panel_size.x <= 0:
		panel_size = Vector2(400, 120)
	
	_betrayal_hint_panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		viewport_size.y - panel_size.y - 80  # 距离底部 80 像素
	)


## 更新叛变提示框显示状态
func _update_betrayal_hint() -> void:
	if not _betrayal_hint_panel:
		return
	
	# 只有 Impostor 且未叛变时才显示
	var should_show = NetworkPlayerManager.can_betray()
	
	if _betrayal_hint_panel.visible != should_show:
		_betrayal_hint_panel.visible = should_show
		if should_show:
			# 重新定位
			call_deferred("_position_betrayal_hint")


## ==================== 调试功能 ====================

## 创建调试标签
func _create_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.position = Vector2(20, 450)
	_debug_label.add_theme_font_size_override("font_size", 16)
	_debug_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_debug_label)


## 更新调试标签
func _update_debug_label() -> void:
	if not _debug_label:
		return
	
	var local_peer_id = NetworkManager.get_peer_id()
	var lines: Array = []
	lines.append("=== 调试: 玩家名字列表 ===")
	lines.append("本地 peer_id: %d" % local_peer_id)
	lines.append("players.keys(): %s" % str(NetworkPlayerManager.players.keys()))
	lines.append("player_info_items.keys(): %s" % str(player_info_items.keys()))
	lines.append("---")
	
	for peer_id in NetworkPlayerManager.players.keys():
		var player = NetworkPlayerManager.players[peer_id]
		if player and is_instance_valid(player):
			var name = player.display_name if "display_name" in player else "???"
			var is_local = " (本地)" if peer_id == local_peer_id else ""
			var is_skipped = " [跳过]" if peer_id <= 1 else ""
			lines.append("peer_%d: %s%s%s" % [peer_id, name, is_local, is_skipped])
		else:
			lines.append("peer_%d: [无效]" % peer_id)
	
	_debug_label.text = "\n".join(lines)
