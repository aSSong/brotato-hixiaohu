extends Control

# 获取AnimationPlayer节点的引用
#@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_info: Label = $player_info
@onready var begin_btn: TextureButton = $menu/VBoxContainer/beginBtn
@onready var board_btn: TextureButton = $menu/VBoxContainer/boardButton
@onready var info_label: Label = $player_info/infoLabel
@onready var clean_name_btn: Button = $player_info/cleannameButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# 检查存档中的名字
var player_name = SaveManager.get_player_name()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	print("[MainTitle] 开始播放标题BGM")
	
	animation_player.play("default")
	
	if player_name != "":
		var floor_id = SaveManager.get_floor_id()
		var floor_text = FloorConfig.get_floor_short_text(floor_id)
		if floor_text == "":
			floor_text = str(floor_id) + "F"
		player_info.text = player_name + "  " + floor_text
	else:
		player_info.visible = false
	#信息公告不可见
	info_label.visible = false
	# 连接 beginBtn 信号
	if begin_btn:
		begin_btn.pressed.connect(_on_begin_btn_pressed)
	
	# 连接排行榜按钮信号
	if board_btn:
		board_btn.pressed.connect(_on_board_btn_pressed)
	
	# 连接清空名字按钮信号
	if clean_name_btn:
		clean_name_btn.pressed.connect(_on_clean_name_btn_pressed)
		clean_name_btn.visible = false  # 默认隐藏清空名字按钮

func _input(event: InputEvent) -> void:
	# 按下 "info" 键切换清空名字按钮的显示状态（仅编辑器或debug版本生效）
	if event.is_action_pressed("info"):
		if OS.has_feature("editor") or OS.is_debug_build():
			if clean_name_btn:
				clean_name_btn.visible = !clean_name_btn.visible

func _on_begin_btn_pressed() -> void:
	# 如果存档信息不为空，进入 cutscene_open 场景
	# 否则进入 level_select 场景
	if player_name != "":
		get_tree().change_scene_to_file("res://scenes/UI/level_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/UI/cutscene_open.tscn")


func _on_btn_quit_pressed() -> void:
	get_tree().quit()


func _on_board_btn_pressed() -> void:
	print("[MainTitle] 进入排行榜")
	get_tree().change_scene_to_file("res://scenes/UI/leaderboard_ui.tscn")


func _on_clean_name_btn_pressed() -> void:
	# 清空玩家名字
	SaveManager.set_player_name("")
	player_name = ""
	player_info.visible = false
	info_label.visible = true
	print("[MainTitle] 玩家名字已清空")


func _on_settingsbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")
