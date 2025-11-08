extends Control

signal floor_changed(class_id: int)   # 把结果广播出去，别的节点直接监听即可
@onready var floor_choose: MenuButton = $Label/floor_choose

const FLOOR_NAMES = ["1 楼", "2 楼", "3 楼", "4 楼", "5 楼", "6 楼", "7 楼", "8 楼", "9 楼", "10 楼", "11 楼", "12 楼", "13 楼", "14 楼", "15 楼", "16 楼", "17 楼", "18 楼", "19 楼", "20 楼", "21 楼", "22 楼", "23 楼", "24 楼", "25 楼", "26 楼", "27 楼", "28 楼", "29 楼", "30 楼", "31 楼", "32 楼", "33 楼", "34 楼", "35 楼", "36 楼", "37 楼", "38 楼", "不在漕河泾"]

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
	
	# 4. 初始显示
	#floor_choose.text = "你在哪个楼层"


func _on_floor_selected(id: int):
	floor_choose.text = FLOOR_NAMES[id]          # 按钮文字实时更新
	emit_signal("floor_changed", id + 1)   # 外部拿到 1/2/3


func _on_fight_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
