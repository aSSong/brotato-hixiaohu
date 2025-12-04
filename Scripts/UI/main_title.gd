extends Control

# 获取AnimationPlayer节点的引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_info: Label = $menu/VBoxContainer/player_info
@onready var begin_btn: TextureButton = $menu/VBoxContainer/beginBtn

# 检查存档中的名字
var player_name = SaveManager.get_player_name()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	print("[MainTitle] 开始播放标题BGM")
	
	if player_name != "":
		var floor_name = SaveManager.get_floor_name()
		player_info.text = player_name + "  " + floor_name
		animation_player.play("kkey")
	else:
		player_info.visible = false
	
	# 连接 beginBtn 信号
	if begin_btn:
		begin_btn.pressed.connect(_on_begin_btn_pressed)


# 处理输入事件
func _input(event: InputEvent) -> void:
	# 检测是否按下K键
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			# 播放kkey动画
			if animation_player:
				animation_player.play("kkey")


func _on_begin_btn_pressed() -> void:
	# 如果存档信息不为空，进入 cutscene_open 场景
	# 否则进入 level_select 场景
	if player_name != "":
		get_tree().change_scene_to_file("res://scenes/UI/level_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/UI/cutscene_open.tscn")


func _on_btn_quit_pressed() -> void:
	get_tree().quit()
