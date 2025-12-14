extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $TextureButton

func _ready() -> void:
	# 暂停背景音乐（让视频音频不被干扰，保留播放位置）
	BGMManager.pause_bgm()
	print("[Cutscene_Chapter2] 章节2动画开始播放")


func _input(event: InputEvent) -> void:
	# ESC键或鼠标左键点击结束播放
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			_skip_video()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_skip_video()


func _skip_video() -> void:
	BGMManager.resume_bgm()  # 恢复背景音乐
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")


func _on_texture_button_pressed() -> void:
	BGMManager.resume_bgm()  # 恢复背景音乐
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")


func _on_video_stream_player_finished() -> void:
	BGMManager.resume_bgm()  # 恢复背景音乐
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")
