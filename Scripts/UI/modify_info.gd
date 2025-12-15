extends Control

## 修改用户信息界面
## 从设置界面进入，用于修改玩家名字和楼层

signal floor_changed(floor_id: int)

@onready var floor_choose: MenuButton = $Label/floor_choose
@onready var name_input: LineEdit = $Label/name_input
@onready var confirm_button_label: Label = $Label/floor_choose/fight/Label

var current_floor_id: int = FloorConfig.FLOOR_ID_INVALID

func _ready():
	# 播放标题BGM（如果还未播放）
	BGMManager.play_bgm("title")
	
	# 修改按钮文字为"确定"
	confirm_button_label.text = "确定"
	
	# 1. 拿到内置的 PopupMenu
	var popup = floor_choose.get_popup()
	
	# 2. 从 FloorConfig 获取可选楼层并添加到菜单
	var floor_ids = FloorConfig.get_available_floor_ids()
	for floor_id in floor_ids:
		var floor_name = FloorConfig.get_floor_name(floor_id)
		popup.add_item(floor_name, floor_id)
	
	# 3. 监听选中信号
	popup.id_pressed.connect(_on_floor_selected)
	
	# 4. 加载已保存的数据
	_load_saved_data()


func _load_saved_data() -> void:
	# 读取已保存的名字
	var saved_name = SaveManager.get_player_name()
	if saved_name != "":
		name_input.text = saved_name
		print("[ModifyInfo] 已加载保存的名字: %s" % saved_name)
	
	# 读取已保存的楼层
	var saved_floor_id = SaveManager.get_floor_id()
	if FloorConfig.is_available_floor(saved_floor_id):
		current_floor_id = saved_floor_id
		floor_choose.text = FloorConfig.get_floor_name(saved_floor_id)
		print("[ModifyInfo] 已加载保存的楼层: %s (ID: %d)" % [FloorConfig.get_floor_name(saved_floor_id), saved_floor_id])


func _on_floor_selected(id: int):
	current_floor_id = id
	floor_choose.text = FloorConfig.get_floor_name(id)
	emit_signal("floor_changed", id)


func _on_fight_pressed() -> void:
	# 获取用户输入的名字，去除半角空格和全角空格后检查是否为空
	var raw_name = name_input.text.strip_edges()
	var check_name = raw_name.replace("　", "").replace(" ", "")
	
	# 验证输入：名字为空或仅包含空格则不可继续
	if check_name == "":
		print("[ModifyInfo] 警告: 名字为空或仅包含空格，无法继续")
		return
	
	var player_name = raw_name
	
	if current_floor_id == FloorConfig.FLOOR_ID_INVALID:
		print("[ModifyInfo] 警告: 未选择楼层")
		return
	
	# 保存用户数据
	SaveManager.set_player_name(player_name)
	SaveManager.set_floor(current_floor_id, FloorConfig.get_floor_name(current_floor_id))
	print("[ModifyInfo] 已保存用户数据: 名字=%s, 楼层=%s" % [player_name, FloorConfig.get_floor_name(current_floor_id)])
	
	# 返回设置界面
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")

