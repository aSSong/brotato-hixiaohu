extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $TextureButton

func _ready() -> void:
	# 暂停背景音乐（让视频音频不被干扰，保留播放位置）
	BGMManager.pause_bgm()
	print("[CutsceneOpen] 开场动画开始播放")
	
	# 连接视频播放完成信号
	if video_player:
		video_player.finished.connect(_on_video_finished)
	
	# 连接跳过按钮信号
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)


func _on_video_finished() -> void:
	print("[CutsceneOpen] 视频播放完成，跳转至 create_account")
	BGMManager.resume_bgm()  # 恢复背景音乐
	get_tree().change_scene_to_file("res://scenes/UI/create_account.tscn")


func _on_skip_pressed() -> void:
	print("[CutsceneOpen] 用户跳过视频，跳转至 create_account")
	BGMManager.resume_bgm()  # 恢复背景音乐
	get_tree().change_scene_to_file("res://scenes/UI/create_account.tscn")
