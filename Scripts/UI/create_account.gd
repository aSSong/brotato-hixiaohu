extends Control

signal floor_changed(class_id: int)   # 把结果广播出去，别的节点直接监听即可
@onready var floor_choose: MenuButton = $Label/floor_choose
@onready var name_input: LineEdit = $Label/name_input

const FLOOR_NAMES = ["1 楼", "2 楼", "3 楼", "4 楼", "5 楼", "6 楼", "7 楼", "8 楼", "9 楼", "10 楼", "11 楼", "12 楼", "13 楼", "14 楼", "15 楼", "16 楼", "17 楼", "18 楼", "19 楼", "20 楼", "21 楼", "22 楼", "23 楼", "24 楼", "25 楼", "26 楼", "27 楼", "28 楼", "29 楼", "30 楼", "31 楼", "32 楼", "33 楼", "34 楼", "35 楼", "36 楼", "37 楼", "38 楼", "不在漕河泾"]

var current_floor_id: int = -1  # 当前选择的楼层ID

func _ready():
	# 播放标题BGM（如果还未播放）
	BGMManager.play_bgm("title")
	print("[CreateAccount] 确保标题BGM播放中")
	
	# 1. 拿到内置的 PopupMenu
	var popup = floor_choose.get_popup()
	
	# 2. 把楼层数据
	for id in FLOOR_NAMES.size():
		popup.add_item(FLOOR_NAMES[id], id)   # 参数：文本、id
	
	# 3. 监听选中信号
	popup.id_pressed.connect(_on_floor_selected)
	
	# 4. 加载已保存的数据
	_load_saved_data()


func _load_saved_data() -> void:
	# 读取已保存的名字
	var saved_name = SaveManager.get_player_name()
	if saved_name != "":
		name_input.text = saved_name
		print("[CreateAccount] 已加载保存的名字: %s" % saved_name)
	
	# 读取已保存的楼层
	var saved_floor_id = SaveManager.get_floor_id()
	if saved_floor_id >= 0 and saved_floor_id < FLOOR_NAMES.size():
		current_floor_id = saved_floor_id
		floor_choose.text = FLOOR_NAMES[saved_floor_id]
		print("[CreateAccount] 已加载保存的楼层: %s (ID: %d)" % [FLOOR_NAMES[saved_floor_id], saved_floor_id])


func _on_floor_selected(id: int):
	current_floor_id = id
	floor_choose.text = FLOOR_NAMES[id]          # 按钮文字实时更新
	emit_signal("floor_changed", id + 1)   # 外部拿到 1/2/3


func _on_fight_pressed() -> void:
	# 获取用户输入的名字
	var player_name = name_input.text.strip_edges()
	
	# 验证输入
	if player_name == "":
		print("[CreateAccount] 警告: 名字为空，使用默认值")
		player_name = "未命名玩家"
	
	if current_floor_id < 0:
		print("[CreateAccount] 警告: 未选择楼层")
		return
	
	# 保存用户数据
	SaveManager.set_player_name(player_name)
	SaveManager.set_floor(current_floor_id, FLOOR_NAMES[current_floor_id])
	print("[CreateAccount] 已保存用户数据: 名字=%s, 楼层=%s" % [player_name, FLOOR_NAMES[current_floor_id]])
	
	# 切换到下一个场景
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
