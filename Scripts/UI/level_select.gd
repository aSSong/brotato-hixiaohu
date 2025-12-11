extends Control

@onready var chapter1_btn: TextureButton = $bg/MarginContainer/HBoxContainer/chaper1panel/chaper1beginBtn
@onready var chapter2_btn: TextureButton = $bg/MarginContainer/HBoxContainer/chaper2panel/chaper2beginBtn
@onready var back_button: TextureButton = $bg/backButton

## 个人记录显示标签
@onready var chapter1_record_label: RichTextLabel = $bg/MarginContainer/HBoxContainer/chaper1panel/chaper1text/selfrecordLabel
@onready var chapter2_record_label: RichTextLabel = $bg/MarginContainer/HBoxContainer/chaper2panel/chaper2text/selfrecordLabel

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
	
	# 更新个人记录显示
	_update_record_labels()


func _on_chapter1_begin_pressed() -> void:
	# Chapter 1: 孤勇者模式 - Survival
	GameMain.current_mode_id = "survival"
	print("[LevelSelect] 选择 Chapter 1: Survival 模式")
	get_tree().change_scene_to_file("res://scenes/UI/Class_choose.tscn")


func _on_chapter2_begin_pressed() -> void:
	# Chapter 2: 同心同力模式 - Multi
	GameMain.current_mode_id = "multi"
	print("[LevelSelect] 选择 Chapter 2: Multi 模式")
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_chapter2.tscn")


func _on_back_button_pressed() -> void:
	print("[LevelSelect] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")

## 更新个人记录显示
func _update_record_labels() -> void:
	# 更新 Chapter 1 (Survival 模式) 记录
	if chapter1_record_label:
		var survival_record = LeaderboardManager.get_survival_record()
		if survival_record.is_empty():
			chapter1_record_label.text = "[i]个人最速通关：[color=#ea33bf]--[/color][/i]"
		else:
			var time_seconds = survival_record.get("completion_time_seconds", 0.0)
			var time_str = _format_time(time_seconds)
			chapter1_record_label.text = "[i]个人最速通关：[color=#ea33bf]%s[/color][/i]" % time_str
	
	# 更新 Chapter 2 (Multi 模式) 记录
	if chapter2_record_label:
		var multi_record = LeaderboardManager.get_multi_record()
		if multi_record.is_empty():
			chapter2_record_label.text = "[i]个人最高波次：[color=#ea33bf]--[/color][/i]"
		else:
			var best_wave = multi_record.get("best_wave", 0)
			chapter2_record_label.text = "[i]个人最高波次：[color=#ea33bf]%d[/color][/i]" % best_wave

## 格式化时间显示 (秒 -> 分'秒''毫秒)
func _format_time(seconds: float) -> String:
	var total_minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	var centiseconds = int((seconds - int(seconds)) * 100)
	
	return "%d'%02d''%02d" % [total_minutes, secs, centiseconds]
