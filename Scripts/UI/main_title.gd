extends Control

# 获取AnimationPlayer节点的引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	print("[MainTitle] 开始播放标题BGM")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


# 处理输入事件
func _input(event: InputEvent) -> void:
	# 检测是否按下K键
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			# 播放kkey动画
			if animation_player:
				animation_player.play("kkey")


func _on_btn_single_play_pressed() -> void:
	# 设置为survival模式（默认模式）
	GameMain.current_mode_id = "survival"
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_0.tscn")
	pass # Replace with function body.


func _on_btn_multi_play_pressed() -> void:
	# 设置为multi模式
	GameMain.current_mode_id = "multi"
	# 跳过剧情，直接进入start_menu
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
	print("[MainTitle] 进入Multi模式")


func _on_btn_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.
