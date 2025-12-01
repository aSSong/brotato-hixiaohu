extends Control

# 获取AnimationPlayer节点的引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player_info: Label = $menu/VBoxContainer/player_info

	# 检查存档中的名字
var player_name = SaveManager.get_player_name()

@onready var online_host_button: Button = %btn_online_host
@onready var online_join_button: Button = %btn_online_join

const ONLINE_MODE_ID := "online"
const ONLINE_MAP_ID := "online_stage_1"
const ONLINE_SCENE_PATH := "res://scenes/map/online_map.tscn"

var _ip_address = "127.0.0.1"
var _is_waiting_for_join: bool = false

func run_online_mode() -> String:
	var args := OS.get_cmdline_args()
	for i in args.size():
		var arg := args[i]
		if arg == "-s" or arg == "--server":
			return "s"
		if arg == "-c" or arg == "--client":
			if i + 1 < args.size():
				var ip_string = args[i + 1]
				if IP.resolve_hostname_addresses(ip_string, IP.TYPE_ANY).size() > 0:
					_ip_address = ip_string
			return "c"
	return ""


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	print("[MainTitle] 开始播放标题BGM")

	_connect_network_signals()
	var mode := run_online_mode()
	online_host_button.visible = (mode == "s")
	online_host_button.disabled = (mode != "s")
	online_join_button.visible = (mode == "c")
	online_join_button.disabled = (mode != "c")

	if player_name != "":
		var floor_name = SaveManager.get_floor_name()
		player_info.text = player_name + "  " + floor_name
		animation_player.play("kkey")
	else:
		player_info.visible = false


func _exit_tree() -> void:
	_disconnect_network_signals()


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
	
	if player_name != "":
		get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/UI/cutscene_0.tscn")


func _on_btn_multi_play_pressed() -> void:
	# 设置为multi模式
	GameMain.current_mode_id = "multi"
	# 跳过剧情，直接进入start_menu
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
	print("[MainTitle] 进入Multi模式")


func _on_btn_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_btn_online_host_pressed() -> void:
	if not NetworkManager.start_host(NetworkManager.DEFAULT_PORT):
		_show_online_status("主机启动失败，请检查端口是否被占用。")
		return
	_prepare_online_session()
	_show_online_status("主机已启动，等待其他玩家加入...")
	online_host_button.disabled = true
	online_join_button.disabled = true
	await SceneCleanupManager.change_scene_safely_keep_mode(ONLINE_SCENE_PATH)


func _on_btn_online_join_pressed() -> void:
	var port := NetworkManager.DEFAULT_PORT
	_prepare_online_session()
	if NetworkManager.start_client(_ip_address, port):
		_show_online_status("正在连接 %s:%d ..." % [_ip_address, port])
		online_host_button.disabled = true
		online_join_button.disabled = true
		_is_waiting_for_join = true
	else:
		_show_online_status("连接失败，请确认地址与端口。")


func _prepare_online_session() -> void:
	GameMain.current_mode_id = ONLINE_MODE_ID
	GameMain.current_map_id = ONLINE_MAP_ID
	ModeRegistry.set_current_mode(ONLINE_MODE_ID)
	MapRegistry.set_current_map(ONLINE_MAP_ID)


func _connect_network_signals() -> void:
	if not NetworkManager.network_started.is_connected(_on_network_started):
		NetworkManager.network_started.connect(_on_network_started)
	if not NetworkManager.network_stopped.is_connected(_on_network_stopped):
		NetworkManager.network_stopped.connect(_on_network_stopped)
	if not NetworkManager.connection_failed.is_connected(_on_network_connection_failed):
		NetworkManager.connection_failed.connect(_on_network_connection_failed)
	if not NetworkManager.server_disconnected.is_connected(_on_network_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_network_server_disconnected)
	if not NetworkManager.connected_to_server.is_connected(_on_network_connected_to_server):
		NetworkManager.connected_to_server.connect(_on_network_connected_to_server)


func _disconnect_network_signals() -> void:
	if NetworkManager.network_started.is_connected(_on_network_started):
		NetworkManager.network_started.disconnect(_on_network_started)
	if NetworkManager.network_stopped.is_connected(_on_network_stopped):
		NetworkManager.network_stopped.disconnect(_on_network_stopped)
	if NetworkManager.connection_failed.is_connected(_on_network_connection_failed):
		NetworkManager.connection_failed.disconnect(_on_network_connection_failed)
	if NetworkManager.server_disconnected.is_connected(_on_network_server_disconnected):
		NetworkManager.server_disconnected.disconnect(_on_network_server_disconnected)
	if NetworkManager.connected_to_server.is_connected(_on_network_connected_to_server):
		NetworkManager.connected_to_server.disconnect(_on_network_connected_to_server)


func _on_network_started(is_server: bool) -> void:
	if is_server:
		_show_online_status("主机启动成功。")
	else:
		_show_online_status("正在尝试连接服务器...")


func _on_network_stopped() -> void:
	if _is_waiting_for_join:
		_show_online_status("连接已关闭。")
	_is_waiting_for_join = false
	online_host_button.disabled = false
	online_join_button.disabled = false


func _on_network_connection_failed() -> void:
	_show_online_status("连接失败，请重试。")
	_is_waiting_for_join = false
	online_host_button.disabled = false
	online_join_button.disabled = false


func _on_network_server_disconnected() -> void:
	_show_online_status("与主机断开连接。")
	_is_waiting_for_join = false
	online_host_button.disabled = false
	online_join_button.disabled = false


func _on_network_connected_to_server() -> void:
	if not _is_waiting_for_join:
		return
	_show_online_status("连接成功，正在进入战场...")
	_is_waiting_for_join = false
	await SceneCleanupManager.change_scene_safely_keep_mode(ONLINE_SCENE_PATH)


func _show_online_status(message: String) -> void:
	print("[MainTitle] %s" % message)
