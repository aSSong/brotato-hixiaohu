extends Control

signal floor_changed(floor_id: int)   # 把结果广播出去，别的节点直接监听即可
@onready var floor_choose: MenuButton = $Label/floor_choose
@onready var name_input: LineEdit = $Label/name_input

var current_floor_id: int = FloorConfig.FLOOR_ID_INVALID  # 当前选择的楼层ID

func _ready():
	# 播放标题BGM（如果还未播放）
	BGMManager.play_bgm("title")
	print("[CreateAccount] 确保标题BGM播放中")
	
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
		print("[CreateAccount] 已加载保存的名字: %s" % saved_name)
	
	# 读取已保存的楼层
	var saved_floor_id = SaveManager.get_floor_id()
	if FloorConfig.is_available_floor(saved_floor_id):
		current_floor_id = saved_floor_id
		floor_choose.text = FloorConfig.get_floor_name(saved_floor_id)
		print("[CreateAccount] 已加载保存的楼层: %s (ID: %d)" % [FloorConfig.get_floor_name(saved_floor_id), saved_floor_id])


func _on_floor_selected(id: int):
	current_floor_id = id
	floor_choose.text = FloorConfig.get_floor_name(id)
	emit_signal("floor_changed", id)


func _on_fight_pressed() -> void:
	# 获取用户输入的名字
	var player_name = name_input.text.strip_edges()
	
	# 验证输入
	if player_name == "":
		print("[CreateAccount] 警告: 名字为空，使用默认值")
		player_name = "未命名玩家"
	
	if current_floor_id == FloorConfig.FLOOR_ID_INVALID:
		print("[CreateAccount] 警告: 未选择楼层")
		return
	
	# 保存用户数据
	SaveManager.set_player_name(player_name)
	SaveManager.set_floor(current_floor_id, FloorConfig.get_floor_name(current_floor_id))
	print("[CreateAccount] 已保存用户数据: 名字=%s, 楼层=%s" % [player_name, FloorConfig.get_floor_name(current_floor_id)])
	
	# 切换到关卡选择场景
	get_tree().change_scene_to_file("res://scenes/UI/level_select.tscn")
