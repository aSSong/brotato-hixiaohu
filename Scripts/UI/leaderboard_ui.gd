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
const COLUMN_WIDTHS_MODE1 = [150, 200, 150, 250, 250, 250]  # 排名, 名字, 楼层, 通关时间, 达成时间, 穿越次数
const COLUMN_WIDTHS_MODE2 = [150, 150, 200, 150, 250, 250]  # 排名, 楼层, 关键人物, 最佳波次, 完成时间, 穿越次数

## ==================== 节点引用 ====================

@onready var switch1_button: TextureButton = $bg_panel/labelContainer/swich1Button
@onready var switch2_button: TextureButton = $bg_panel/labelContainer/swich1Button2
@onready var back_button: TextureButton = $backButton
@onready var board1_panel: Control = $bg_panel/board1panel
@onready var board2_panel: Control = $bg_panel/board2panel
@onready var bg_key: TextureRect = $"bg-key"

# 缓存字体资源
var _cached_font: Font = null

# 缓存排名图片资源（前3名）
var _rank_textures: Array[Texture2D] = []

# 服务器数据
var leaderboard_data: Dictionary = {}
var is_loading: bool = false

# 当前选中的模式 (1 或 2)
var current_mode: int = 1

## ==================== 滚动背景 ====================

## 背景滚动速度（像素/秒）
@export var scroll_speed: Vector2 = Vector2(100, 100)

## 背景贴图尺寸（用于无缝循环）
var bg_texture_size: Vector2 = Vector2.ZERO
var scroll_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 加载字体资源
	_cached_font = load(FONT_PATH)
	
	# 预加载排名图片（前3名）
	_rank_textures = [
		load("res://assets/UI/leaderboard_ui/label-num-01.png"),
		load("res://assets/UI/leaderboard_ui/label-num-02.png"),
		load("res://assets/UI/leaderboard_ui/label-num-03.png")
	]
	
	# 连接按钮信号
	if switch1_button:
		switch1_button.pressed.connect(_on_switch1_pressed)
	if switch2_button:
		switch2_button.pressed.connect(_on_switch2_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# 初始化滚动背景
	_setup_scrolling_background()
	
	# 初始化为模式2（默认显示模式2排行榜）
	_switch_to_mode(2)
	
	# 设置模式2按钮为focused
	if switch2_button:
		switch2_button.grab_focus()
	
	# 加载数据
	_load_leaderboard_data()

## 初始化滚动背景
func _setup_scrolling_background() -> void:
	if not bg_key or not bg_key.texture:
		return
	
	# 获取贴图尺寸
	bg_texture_size = bg_key.texture.get_size()
	
	# 设置背景铺满并可重复
	bg_key.anchor_left = 0
	bg_key.anchor_top = 0
	bg_key.anchor_right = 0
	bg_key.anchor_bottom = 0
	
	# 扩展背景尺寸以支持无缝滚动（2倍大小）
	var viewport_size = get_viewport_rect().size
	bg_key.size = viewport_size + bg_texture_size
	
	# 设置纹理平铺模式
	bg_key.stretch_mode = TextureRect.STRETCH_TILE

func _process(delta: float) -> void:
	if not bg_key or bg_texture_size == Vector2.ZERO:
		return
	
	# 更新滚动偏移（向左下角滚动）
	scroll_offset.x += scroll_speed.x * delta
	scroll_offset.y += scroll_speed.y * delta
	
	# 循环重置（当滚动超过贴图尺寸时重置）
	if scroll_offset.x >= bg_texture_size.x:
		scroll_offset.x -= bg_texture_size.x
	if scroll_offset.y >= bg_texture_size.y:
		scroll_offset.y -= bg_texture_size.y
	
	# 应用位置偏移（向左下移动 = position 向右上移动的负值）
	bg_key.position = -scroll_offset

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
	
	var floor_id = int(record.get("floor_id", 0))
	var death_count = int(record.get("total_death_count", 0))
	
	var columns = [
		_format_rank(rank),
		record.get("player_name", "???"),
		_format_floor(floor_id),
		_format_time(record.get("completion_time_seconds", 0)),
		_format_datetime(record.get("completed_at", "")),
		str(death_count)
	]
	
	for i in range(columns.size()):
		if i == 0:
			# 第一列是排名，使用特殊处理
			var rank_cell = _create_rank_cell(rank, COLUMN_WIDTHS_MODE1[i])
			row.add_child(rank_cell)
		else:
			var label = Label.new()
			label.text = columns[i]
			label.custom_minimum_size.x = COLUMN_WIDTHS_MODE1[i]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	
	var best_wave = int(record.get("best_wave", 0))
	var death_count = int(record.get("total_death_count", 0))
	
	var columns = [
		_format_rank(group_rank) if show_rank else "",
		_format_floor(floor_id) if show_rank else "",
		record.get("player_name", "???"),
		"Wave" + str(best_wave),
		_format_datetime(record.get("achieved_at", "")),
		str(death_count)
	]
	
	for i in range(columns.size()):
		if i == 0 and show_rank:
			# 第一列是排名，使用特殊处理
			var rank_cell = _create_rank_cell(group_rank, COLUMN_WIDTHS_MODE2[i])
			row.add_child(rank_cell)
		else:
			var label = Label.new()
			label.text = columns[i]
			label.custom_minimum_size.x = COLUMN_WIDTHS_MODE2[i]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
			label.add_theme_color_override("font_color", CONTENT_FONT_COLOR)
			if _cached_font:
				label.add_theme_font_override("font", _cached_font)
			row.add_child(label)
	
	return row

## ==================== 格式化工具函数 ====================

## 创建排名单元格（前3名用图片，其他用文字）
func _create_rank_cell(rank: int, width: float) -> Control:
	var container = Control.new()
	container.custom_minimum_size.x = width
	container.custom_minimum_size.y = 50
	
	if rank >= 1 and rank <= 3 and rank - 1 < _rank_textures.size():
		# 前3名：显示图片（直接指定目标尺寸）
		var icon = TextureRect.new()
		icon.texture = _rank_textures[rank - 1]
		var target_height = 10.0  # ← 调整这个值来控制图片高度
		# 根据目标高度计算宽度，保持宽高比
		var original_size = _rank_textures[rank - 1].get_size()
		var aspect_ratio = original_size.x / original_size.y
		var target_size = Vector2(target_height * aspect_ratio, target_height)
		icon.custom_minimum_size = target_size
		icon.size = target_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		container.add_child(icon)
	else:
		# 4名及以后：显示文字
		var label = Label.new()
		label.text = _format_rank(rank)
		label.custom_minimum_size.x = width
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
		label.add_theme_color_override("font_color", CONTENT_FONT_COLOR)
		if _cached_font:
			label.add_theme_font_override("font", _cached_font)
		container.add_child(label)
	
	return container

## 格式化排名显示 (1st, 2nd, 3rd, 4th...)
func _format_rank(rank: int) -> String:
	match rank:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return str(rank) + "TH"

## 格式化楼层显示（使用 FloorConfig）
func _format_floor(floor_id: int) -> String:
	var floor_text = FloorConfig.get_floor_short_text(floor_id)
	if floor_text.is_empty():
		return str(floor_id) + "F"
	return floor_text

## 格式化通关时间 (秒 -> xx分xx秒xx 格式)
func _format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var mins = total_seconds / 60
	var secs = total_seconds % 60
	var ms = int((seconds - total_seconds) * 100)
	return "%d分%02d秒%02d" % [mins, secs, ms]

## 格式化日期时间 (ISO 8601 -> YYYY/MM/DD HH:MM)
func _format_datetime(iso_date: String) -> String:
	if iso_date.is_empty():
		return "???"
	
	# 解析 ISO 8601 格式: "2025-12-08T14:17:31Z"
	var datetime_parts = iso_date.split("T")
	if datetime_parts.size() < 2:
		return iso_date
	
	var date_part = datetime_parts[0]
	var time_part = datetime_parts[1].replace("Z", "")
	
	var date_components = date_part.split("-")
	var time_components = time_part.split(":")
	
	if date_components.size() >= 3 and time_components.size() >= 2:
		var year = date_components[0]
		var month = date_components[1]
		var day = date_components[2]
		var hour = time_components[0]
		var minute = time_components[1]
		return "%s/%s/%s %s:%s" % [year, month, day, hour, minute]
	
	return iso_date

## ==================== 按钮回调 ====================

func _on_switch1_pressed() -> void:
	_switch_to_mode(1)

func _on_switch2_pressed() -> void:
	_switch_to_mode(2)

func _on_back_pressed() -> void:
	print("[LeaderboardUI] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")
