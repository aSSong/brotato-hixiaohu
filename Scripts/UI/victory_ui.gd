extends Control
class_name VictoryUI

## 胜利UI
## 当玩家达到目标时显示
@onready var return_button: TextureButton = $MainPanel/ReturnButton
@onready var main_panel: ColorRect = $MainPanel
@onready var bg_key: TextureRect = $MainPanel/"bg-key"
@onready var victory_text: TextureRect = $MainPanel/text
@onready var poster: TextureRect = $MainPanel/poster

## 模式样式配置
const MODE_STYLES = {
	"survival": {
		"panel_color": Color(0.20392157, 0.84313726, 0.62352943, 1),  # #34d79f
		"bg_texture": "res://assets/UI/common/bg-greenkey-01.png",
		"text_texture": "res://assets/UI/victory_ui/text_victory_01.png"
	},
	"multi": {
		"panel_color": Color(0.95686275, 0.17254902, 0.29019608, 1),  # #f42c4a
		"bg_texture": "res://assets/UI/common/bg-redkey-01.png",
		"text_texture": "res://assets/UI/victory_ui/text_victory_02.png"
	}
}

## 记录显示节点引用
@onready var record_container: Control = $MainPanel/record
@onready var now_record_label: Label = $MainPanel/record/nowRecord
@onready var history_record_label: Label = $MainPanel/record/histroyRecord
@onready var new_record_sign: Control = $MainPanel/record/newRecordSign

## 上传状态标签
@onready var upload_state_label: Label = $MainPanel/ReturnButton/uploadstateLabel

## 背景滚动速度（像素/秒）
@export var scroll_speed: Vector2 = Vector2(100, 100)

## 是否有新纪录需要上传
var _has_new_record: bool = false

## 背景贴图尺寸（用于无缝循环）
var bg_texture_size: Vector2 = Vector2.ZERO
var scroll_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 确保状态正确
	if GameState.current_state != GameState.State.GAME_VICTORY:
		GameState.change_state(GameState.State.GAME_VICTORY)
	
	# 连接返回按钮
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)
	
	# 根据模式设置样式
	_setup_mode_style()
	
	# 初始化背景
	_setup_scrolling_background()
	
	# 更新职业海报
	_update_poster()
	
	# 更新记录显示（仅 Survival 模式）
	_update_record_display()
	
	# 初始化上传状态显示
	_setup_upload_state_display()

## 根据模式设置样式
func _setup_mode_style() -> void:
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"
	
	# 获取模式样式配置，默认使用 survival 样式
	var style = MODE_STYLES.get(mode_id, MODE_STYLES["survival"])
	
	# 设置面板颜色
	if main_panel:
		main_panel.color = style["panel_color"]
	
	# 设置背景纹理
	if bg_key:
		var bg_texture = load(style["bg_texture"])
		if bg_texture:
			bg_key.texture = bg_texture
	
	# 设置胜利文字纹理
	if victory_text:
		var text_texture = load(style["text_texture"])
		if text_texture:
			victory_text.texture = text_texture

## 初始化滚动背景
func _setup_scrolling_background() -> void:
	if not bg_key or not bg_key.texture:
		return
	
	# 获取贴图尺寸
	bg_texture_size = bg_key.texture.get_size()
	
	# 设置背景铺满并可重复
	bg_key.anchor_left = 0
	bg_key.anchor_top = 0
	bg_key.anchor_right = 1
	bg_key.anchor_bottom = 1
	bg_key.offset_left = 0
	bg_key.offset_top = 0
	bg_key.offset_right = 0
	bg_key.offset_bottom = 0
	
	# 扩展背景尺寸以支持无缝滚动（2倍大小）
	bg_key.anchor_right = 0
	bg_key.anchor_bottom = 0
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

## 更新职业海报
func _update_poster() -> void:
	if not poster:
		return
	
	var class_id = GameMain.selected_class_id
	if class_id == "":
		class_id = "balanced"
	
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data and class_data.poster:
		poster.texture = class_data.poster

## 返回主菜单
func _on_return_button_pressed() -> void:
	print("[VictoryUI] 返回主菜单...")
	# 使用SceneCleanupManager安全切换场景（会清理所有游戏对象并重置数据）
	SceneCleanupManager.change_scene_safely("res://scenes/UI/main_title.tscn")

## 更新记录显示
func _update_record_display() -> void:
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"
	
	# 仅 Survival 模式显示记录容器
	if mode_id != "survival":
		if record_container:
			record_container.visible = false
	else:
		# 显示记录容器
		if record_container:
			record_container.visible = true
	
	# 获取当前通关时间
	var elapsed_time: float = 0.0
	if GameMain.current_session:
		elapsed_time = GameMain.current_session.get_elapsed_time()
	
	# 根据模式获取历史最佳记录和判断新纪录
	if mode_id == "survival":
		_update_survival_record(elapsed_time)
	else:
		_update_multi_record()

## 更新 Survival 模式记录显示
func _update_survival_record(elapsed_time: float) -> void:
	# 获取历史最佳记录
	var record = LeaderboardManager.get_survival_record()
	var best_time: float = INF
	if not record.is_empty():
		best_time = record.get("completion_time_seconds", INF)
	
	# 更新当前通关时间标签
	if now_record_label:
		var time_str = _format_time_chinese(elapsed_time)
		now_record_label.text = "通关时间：%s" % time_str
	
	# 更新历史最佳标签
	if history_record_label:
		if best_time == INF or best_time <= 0:
			history_record_label.text = "历史最佳：--"
		else:
			var best_time_str = _format_time_chinese(best_time)
			history_record_label.text = "历史最佳：%s" % best_time_str
	
	# 判断是否为新纪录
	# 胜利界面只在通关时显示，所以如果当前时间比历史最佳更短就是新纪录
	# 注意：这里需要检查 pending_upload 来判断是否刚刚创建了新纪录
	_has_new_record = LeaderboardManager.is_pending_upload("survival") or LeaderboardManager.is_uploading("survival")
	
	if new_record_sign:
		new_record_sign.visible = _has_new_record

## 更新 Multi 模式记录显示（Multi 模式不显示记录容器，只处理上传状态）
func _update_multi_record() -> void:
	# 检查是否有新纪录需要上传
	_has_new_record = LeaderboardManager.is_pending_upload("multi") or LeaderboardManager.is_uploading("multi")

## 格式化时间为中文格式 "XX分XX秒XX"
func _format_time_chinese(seconds: float) -> String:
	var total_seconds = int(seconds)
	var centiseconds = int((seconds - total_seconds) * 100)
	var mins = total_seconds / 60
	var secs = total_seconds % 60
	return "%d分%02d秒%02d" % [mins, secs, centiseconds]

## 初始化上传状态显示
func _setup_upload_state_display() -> void:
	# 默认隐藏上传状态标签
	if upload_state_label:
		upload_state_label.visible = false
	
	# 如果没有新纪录，不显示上传状态
	if not _has_new_record:
		return
	
	# 连接上传状态信号
	if not LeaderboardManager.upload_state_changed.is_connected(_on_upload_state_changed):
		LeaderboardManager.upload_state_changed.connect(_on_upload_state_changed)
	
	# 获取当前模式
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"
	
	# 检查当前上传状态
	var current_state = LeaderboardManager.get_upload_state(mode_id)
	_update_upload_state_display(mode_id, current_state)

## 上传状态变化回调
func _on_upload_state_changed(mode_id: String, state: String) -> void:
	# 获取当前模式
	var current_mode_id = GameMain.current_mode_id
	if current_mode_id.is_empty():
		current_mode_id = "survival"
	
	# 只处理当前模式的上传状态
	if mode_id != current_mode_id:
		return
	
	_update_upload_state_display(mode_id, state)

## 更新上传状态显示
func _update_upload_state_display(mode_id: String, state: String) -> void:
	if not upload_state_label:
		return
	
	# 如果没有新纪录，不显示
	if not _has_new_record:
		upload_state_label.visible = false
		return
	
	match state:
		"uploading":
			upload_state_label.visible = true
			upload_state_label.text = "新记录上传中……建议稍后再切换画面"
			upload_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.67))
		"success":
			upload_state_label.visible = true
			upload_state_label.text = "新记录已上传成功！"
			upload_state_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
		"failed":
			upload_state_label.visible = true
			upload_state_label.text = "上传失败，重启游戏会再次上传"
			upload_state_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
		"pending":
			# 待上传状态（正在等待上传）
			upload_state_label.visible = true
			upload_state_label.text = "新记录上传中……建议稍后再切换画面"
			upload_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.67))
		_:
			# idle 或其他状态，隐藏
			upload_state_label.visible = false

## 节点退出时断开信号
func _exit_tree() -> void:
	if LeaderboardManager.upload_state_changed.is_connected(_on_upload_state_changed):
		LeaderboardManager.upload_state_changed.disconnect(_on_upload_state_changed)
