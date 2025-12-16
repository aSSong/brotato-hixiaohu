extends Control

@onready var fullscreen_btn: TextureButton = $DisplayModeContainer/FullscreenBtn
@onready var window_btn: TextureButton = $DisplayModeContainer/WindowBtn

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
	SaveManager.set_display_mode("windowed")
	print("[SettingsUI] 切换到窗口模式")

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
