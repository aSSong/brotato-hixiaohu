extends Control

@onready var chapter1_btn: TextureButton = $bg/MarginContainer/HBoxContainer/chaper1panel/chaper1beginBtn
@onready var chapter2_btn: TextureButton = $bg/MarginContainer/HBoxContainer/chaper2panel/chaper2beginBtn
@onready var back_button: TextureButton = $bg/backButton

func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	print("[LevelSelect] 关卡选择界面就绪")
	
	# 连接按钮信号
	if chapter1_btn:
		chapter1_btn.pressed.connect(_on_chapter1_begin_pressed)
	
	if chapter2_btn:
		chapter2_btn.pressed.connect(_on_chapter2_begin_pressed)
	
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)


func _on_chapter1_begin_pressed() -> void:
	# Chapter 1: 孤勇者模式 - Survival
	GameMain.current_mode_id = "survival"
	print("[LevelSelect] 选择 Chapter 1: Survival 模式")
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")


func _on_chapter2_begin_pressed() -> void:
	# Chapter 2: 同心同力模式 - Multi
	GameMain.current_mode_id = "multi"
	print("[LevelSelect] 选择 Chapter 2: Multi 模式")
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")


func _on_back_button_pressed() -> void:
	print("[LevelSelect] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")

