extends Control

@onready var fullscreen_btn: TextureButton = $DisplayModeContainer/FullscreenBtn
@onready var window_btn: TextureButton = $DisplayModeContainer/WindowBtn

# 最佳纪录界面场景
const BESTRECORD_UI_SCENE = preload("res://scenes/UI/bestrecord_ui.tscn")
# 视频设置界面场景
const VIDEOSET_UI_SCENE = preload("res://scenes/UI/videoset_ui.tscn")

# 当前打开的最佳纪录界面实例
var _bestrecord_ui_instance: CanvasLayer = null
# 当前打开的视频设置界面实例
var _videoset_ui_instance: CanvasLayer = null

func _ready() -> void:
	# 根据当前窗口模式设置按钮状态
	_update_display_mode_buttons()

## 更新显示模式按钮状态
func _update_display_mode_buttons() -> void:
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		fullscreen_btn.button_pressed = true
	else:
		window_btn.button_pressed = true

## 全屏按钮按下
func _on_fullscreen_btn_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	SaveManager.set_display_mode("fullscreen")
	print("[SettingsUI] 切换到全屏模式")

## 窗口按钮按下
func _on_window_btn_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_set_windowed_size()
	SaveManager.set_display_mode("windowed")
	print("[SettingsUI] 切换到窗口模式")

## 根据屏幕分辨率设置窗口大小
func _set_windowed_size() -> void:
	var screen_size = DisplayServer.screen_get_size()
	var window_size: Vector2i
	
	# 根据屏幕分辨率选择窗口大小
	if screen_size.x > 1920 or screen_size.y > 1080:
		# 大于 1920x1080 的屏幕，窗口设为 1920x1080
		window_size = Vector2i(1920, 1080)
	else:
		# 1920x1080 或更小的屏幕，窗口设为 1600x900
		window_size = Vector2i(1600, 900)
	
	DisplayServer.window_set_size(window_size)
	# 居中显示
	var window_pos = (screen_size - window_size) / 2
	DisplayServer.window_set_position(window_pos)

## 打开最佳纪录界面（弹窗）
func _on_recordbtn_pressed() -> void:
	# 如果已经有一个实例存在，先关闭它
	if _bestrecord_ui_instance != null and is_instance_valid(_bestrecord_ui_instance):
		_bestrecord_ui_instance.queue_free()
	
	# 创建新实例
	_bestrecord_ui_instance = BESTRECORD_UI_SCENE.instantiate()
	add_child(_bestrecord_ui_instance)
	print("[SettingsUI] 打开最佳纪录界面")

## 打开视频设置界面（弹窗）
func _on_videobtn_pressed() -> void:
	# 如果已经有一个实例存在，先关闭它
	if _videoset_ui_instance != null and is_instance_valid(_videoset_ui_instance):
		_videoset_ui_instance.queue_free()
	
	# 创建新实例
	_videoset_ui_instance = VIDEOSET_UI_SCENE.instantiate()
	add_child(_videoset_ui_instance)
	print("[SettingsUI] 打开视频设置界面")

func _on_cut_1_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_playback_1.tscn")


func _on_cut_2_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_playback_2.tscn")


func _on_stuffbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/creators.tscn")


func _on_filesbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/ui_modify_info.tscn")


func _on_backbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")
