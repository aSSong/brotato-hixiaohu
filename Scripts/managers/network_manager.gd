extends Node

## 全局网络管理器 - 负责多人联机模式的底层连接与事件管理
## TODO: 后续补充房间列表、断线重连等完整逻辑

signal network_started(is_server: bool)
signal network_stopped()
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()
signal connected_to_server()

# 默认端口与Tick配置，可在GameConfig后续补充
const DEFAULT_PORT: int = 19010
const DEFAULT_MAX_CLIENTS: int = 5

var _multiplayer_api: MultiplayerAPI = null
var _is_server: bool = false
var _is_started: bool = false

func _ready() -> void:
	_multiplayer_api = MultiplayerAPI.create_default_interface()
	multiplayer.multiplayer_peer = null
	_register_signals()
	print("[NetworkManager] Ready")

func _register_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func start_host(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> bool:
	if _is_started:
		print("[NetworkManager] Host already running")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		push_error("[NetworkManager] Failed to start host: %s" % error_string(err))
		return false
	peer.refuse_new_connections = false
	multiplayer.multiplayer_peer = peer
	_is_server = true
	_is_started = true
	print("[NetworkManager] Host started on port %d" % port)
	network_started.emit(true)
	return true

func start_client(address: String, port: int = DEFAULT_PORT) -> bool:
	if _is_started:
		print("[NetworkManager] Client already connected")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("[NetworkManager] Failed to connect: %s" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	_is_server = false
	_is_started = true
	print("[NetworkManager] Connecting to %s:%d" % [address, port])
	network_started.emit(false)
	return true

func stop_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_is_started = false
	_is_server = false
	print("[NetworkManager] Network stopped")
	network_stopped.emit()

func is_server() -> bool:
	return _is_server and _is_started

func is_client() -> bool:
	return not _is_server and _is_started

func get_peer_id() -> int:
	return multiplayer.get_unique_id()

func get_multiplayer_peer() -> MultiplayerPeer:
	return multiplayer.multiplayer_peer

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % id)
	peer_disconnected.emit(id)

func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed")
	stop_network()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	stop_network()
	server_disconnected.emit()

func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server")
	connected_to_server.emit()
