extends Control

## 排行榜UI控制器
## 支持模式1（Survival速通榜）和模式2（Multi楼层榜）

## ==================== 样式常量 ====================

# 字体路径
const FONT_PATH = "res://assets/fonts/CangErYuYangTiW05-2.ttf"

# 表头样式
const HEADER_FONT_SIZE: int = 32
const HEADER_FONT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

# 正文样式
const CONTENT_FONT_SIZE: int = 24
const CONTENT_FONT_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)

# 表头列宽配置
const COLUMN_WIDTHS_MODE1 = [80, 150, 80, 120, 150, 100]  # 排名, 名字, 楼层, 通关时间, 达成时间, 穿越次数
const COLUMN_WIDTHS_MODE2 = [80, 80, 150, 100, 150, 100]  # 排名, 楼层, 关键人物, 最佳波次, 完成时间, 穿越次数

## ==================== 节点引用 ====================

@onready var switch1_button: TextureButton = $bg_panel/labelContainer/swich1Button
@onready var switch2_button: TextureButton = $bg_panel/labelContainer/swich1Button2
@onready var back_button: TextureButton = $backButton
@onready var board1_panel: Control = $bg_panel/board1panel
@onready var board2_panel: Control = $bg_panel/board2panel

# 缓存字体资源
var _cached_font: Font = null

# 服务器数据
var leaderboard_data: Dictionary = {}
var is_loading: bool = false

# 当前选中的模式 (1 或 2)
var current_mode: int = 1

func _ready() -> void:
	# 加载字体资源
	_cached_font = load(FONT_PATH)
	
	# 连接按钮信号
	if switch1_button:
		switch1_button.pressed.connect(_on_switch1_pressed)
	if switch2_button:
		switch2_button.pressed.connect(_on_switch2_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# 初始化为模式1
	_switch_to_mode(1)
	
	# 加载数据
	_load_leaderboard_data()

## 从服务器加载排行榜数据
func _load_leaderboard_data() -> void:
	if is_loading:
		return
	
	is_loading = true
	print("[LeaderboardUI] 正在加载排行榜数据...")
	
	leaderboard_data = await LeaderboardManager.load_leaderboard_data()
	
	is_loading = false
	
	if leaderboard_data.is_empty():
		print("[LeaderboardUI] 排行榜数据为空或加载失败")
	else:
		print("[LeaderboardUI] 排行榜数据加载成功: ", leaderboard_data.keys())
	
	# 刷新当前显示
	_refresh_current_board()

## 切换到指定模式
func _switch_to_mode(mode: int) -> void:
	current_mode = mode
	
	# 更新按钮状态
	if mode == 1:
		switch1_button.disabled = true
		switch2_button.disabled = false
		board1_panel.visible = true
		board2_panel.visible = false
	else:
		switch1_button.disabled = false
		switch2_button.disabled = true
		board1_panel.visible = false
		board2_panel.visible = true
	
	# 刷新显示
	_refresh_current_board()

## 刷新当前榜单
func _refresh_current_board() -> void:
	if current_mode == 1:
		_populate_survival_board()
	else:
		_populate_multi_board()

## ==================== 模式1：Survival 排行榜 ====================

func _populate_survival_board() -> void:
	# 清空现有内容
	var content_container = board1_panel.get_node_or_null("ScrollContainer/ContentContainer")
	if not content_container:
		return
	
	for child in content_container.get_children():
		child.queue_free()
	
	# 获取 survival 数据
	var survival_list = leaderboard_data.get("survival", [])
	if survival_list is not Array:
		survival_list = []
	
	# 按通关时间排序（升序，时间越短越好）
	survival_list.sort_custom(func(a, b): 
		return a.get("completion_time_seconds", INF) < b.get("completion_time_seconds", INF)
	)
	
	# 填充数据行
	var rank = 1
	for record in survival_list:
		var row = _create_survival_row(rank, record)
		content_container.add_child(row)
		rank += 1
	
	print("[LeaderboardUI] Survival榜单已刷新，共 %d 条记录" % survival_list.size())

## 创建 Survival 模式的数据行
func _create_survival_row(rank: int, record: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var columns = [
		_format_rank(rank),
		record.get("player_name", "???"),
		str(record.get("floor_id", 0)) + "F",
		_format_time(record.get("completion_time_seconds", 0)),
		_format_date(record.get("completed_at", "")),
		str(record.get("total_death_count", 0))
	]
	
	for i in range(columns.size()):
		var label = Label.new()
		label.text = columns[i]
		label.custom_minimum_size.x = COLUMN_WIDTHS_MODE1[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
		label.add_theme_color_override("font_color", CONTENT_FONT_COLOR)
		if _cached_font:
			label.add_theme_font_override("font", _cached_font)
		row.add_child(label)
	
	return row

## ==================== 模式2：Multi 排行榜 ====================

func _populate_multi_board() -> void:
	# 清空现有内容
	var content_container = board2_panel.get_node_or_null("ScrollContainer/ContentContainer")
	if not content_container:
		return
	
	for child in content_container.get_children():
		child.queue_free()
	
	# 获取 multi 数据
	var multi_list = leaderboard_data.get("multi", [])
	if multi_list is not Array:
		multi_list = []
	
	# 按楼层分组
	var floor_groups: Dictionary = {}
	for record in multi_list:
		var floor_id = record.get("floor_id", 0)
		if not floor_groups.has(floor_id):
			floor_groups[floor_id] = []
		floor_groups[floor_id].append(record)
	
	# 每组内按波次降序排序，相同波次按时间升序
	for floor_id in floor_groups.keys():
		floor_groups[floor_id].sort_custom(func(a, b):
			var wave_a = a.get("best_wave", 0)
			var wave_b = b.get("best_wave", 0)
			if wave_a != wave_b:
				return wave_a > wave_b  # 波次降序
			# 相同波次，按达成时间升序（先到者靠前）
			return a.get("achieved_at", "") < b.get("achieved_at", "")
		)
		# 每组只取前3名
		floor_groups[floor_id] = floor_groups[floor_id].slice(0, 3)
	
	# 组间排序：按各组最高波次降序，相同则按最早达成时间
	var sorted_floors = floor_groups.keys()
	sorted_floors.sort_custom(func(a, b):
		var max_wave_a = floor_groups[a][0].get("best_wave", 0) if floor_groups[a].size() > 0 else 0
		var max_wave_b = floor_groups[b][0].get("best_wave", 0) if floor_groups[b].size() > 0 else 0
		if max_wave_a != max_wave_b:
			return max_wave_a > max_wave_b
		var time_a = floor_groups[a][0].get("achieved_at", "") if floor_groups[a].size() > 0 else ""
		var time_b = floor_groups[b][0].get("achieved_at", "") if floor_groups[b].size() > 0 else ""
		return time_a < time_b
	)
	
	# 填充数据行（分组显示）
	var group_rank = 1
	for floor_id in sorted_floors:
		var group = floor_groups[floor_id]
		var is_first_in_group = true
		
		for record in group:
			var row = _create_multi_row(group_rank, floor_id, record, is_first_in_group)
			content_container.add_child(row)
			is_first_in_group = false
		
		# 添加分隔线（除了最后一组）
		if group_rank < sorted_floors.size():
			var separator = HSeparator.new()
			separator.custom_minimum_size.y = 10
			content_container.add_child(separator)
		
		group_rank += 1
	
	print("[LeaderboardUI] Multi榜单已刷新，共 %d 个楼层组" % sorted_floors.size())

## 创建 Multi 模式的数据行
func _create_multi_row(group_rank: int, floor_id: int, record: Dictionary, show_rank: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var columns = [
		_format_rank(group_rank) if show_rank else "",
		(str(floor_id) + "F") if show_rank else "",
		record.get("player_name", "???"),
		"Wave" + str(record.get("best_wave", 0)),
		_format_date(record.get("achieved_at", "")),
		str(record.get("total_death_count", 0))
	]
	
	for i in range(columns.size()):
		var label = Label.new()
		label.text = columns[i]
		label.custom_minimum_size.x = COLUMN_WIDTHS_MODE2[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
		label.add_theme_color_override("font_color", CONTENT_FONT_COLOR)
		if _cached_font:
			label.add_theme_font_override("font", _cached_font)
		row.add_child(label)
	
	return row

## ==================== 格式化工具函数 ====================

## 格式化排名显示 (1st, 2nd, 3rd, 4th...)
func _format_rank(rank: int) -> String:
	match rank:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return str(rank) + "TH"

## 格式化时间 (秒 -> mm:ss.ms)
func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	var ms = int((seconds - int(seconds)) * 100)
	return "%02d:%02d.%02d" % [mins, secs, ms]

## 格式化日期 (ISO 8601 -> MM/DD日YYYY年)
func _format_date(iso_date: String) -> String:
	if iso_date.is_empty():
		return "???"
	
	# 解析 ISO 8601 格式: "2025-12-08T14:17:31Z"
	var date_part = iso_date.split("T")[0] if "T" in iso_date else iso_date
	var parts = date_part.split("-")
	
	if parts.size() >= 3:
		var year = parts[0]
		var month = parts[1]
		var day = parts[2]
		return "%s/%s日%s年" % [month, day, year]
	
	return iso_date

## ==================== 按钮回调 ====================

func _on_switch1_pressed() -> void:
	_switch_to_mode(1)

func _on_switch2_pressed() -> void:
	_switch_to_mode(2)

func _on_back_pressed() -> void:
	print("[LeaderboardUI] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")
