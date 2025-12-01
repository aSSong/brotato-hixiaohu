extends Node

## 网络玩家管理器
## 负责在线模式下玩家的创建、同步和管理

const PLAYER_SCENE := preload("res://scenes/players/player_online.tscn")
const SPAWN_POSITION := Vector2(1200, 950)

## 职业列表: boss 职业固定，其他职业可随机分配给 player/impostor
const BOSS_CLASS := "boss"  # boss 专用职业
const PLAYER_CLASSES := ["player1", "player3", "player2"]  # player/impostor 可用的职业

## 角色列表: boss, impostor, player
const ROLE_BOSS := "boss"
const ROLE_IMPOSTOR := "impostor"
const ROLE_PLAYER := "player"

## 初始血量加成 (累加值)
const INIT_HP_BONUS_BOSS := 100
const INIT_HP_BONUS_IMPOSTOR := 100
const INIT_HP_BONUS_PLAYER := 100

## 初始钥匙数量
const INIT_GOLD_BOSS := 20
const INIT_GOLD_IMPOSTOR := 10
const INIT_GOLD_PLAYER := 10
const INIT_MASTER_KEY_BOSS := 4
const INIT_MASTER_KEY_IMPOSTOR := 2
const INIT_MASTER_KEY_PLAYER := 2

## 初始武器 (武器ID数组)
const INIT_WEAPONS_PLAYER := ["rifle", "axe"] # axe
const INIT_WEAPONS_IMPOSTOR := ["rifle", "axe"] # fireball
const INIT_WEAPONS_BOSS := []

## 复活费用
const REVIVE_COST_MASTER_KEY := 1  # 复活消耗的 master_key 数量

var players: Dictionary = {}  # peer_id -> PlayerCharacter
var local_player: PlayerCharacter = null
var local_peer_id: int = 0

## 服务器摄像机（服务器用于观察游戏）
var _server_camera: Camera2D = null
var _following_peer_id: int = 0  # 当前跟随的玩家 peer_id

## Impostor 叛变状态
var impostor_betrayed: bool = false  # 是否已叛变
var impostor_peer_id: int = 0  # Impostor 的 peer_id

## 叛变信号
signal impostor_betrayal_triggered(impostor_peer_id: int)

func _ready() -> void:
	local_peer_id = NetworkManager.get_peer_id()
	print("[NetworkPlayerManager] Ready, peer_id=%d" % local_peer_id)
	
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.network_stopped.connect(_on_network_stopped)


func _process(delta: float) -> void:
	# 服务器摄像机跟随当前客户端
	if _server_camera and _following_peer_id != 0:
		var player = get_player_by_peer_id(_following_peer_id)
		if player and is_instance_valid(player):
			_server_camera.global_position = player.global_position


func _unhandled_input(event: InputEvent) -> void:
	# 只有服务器才能切换视角
	if not NetworkManager.is_server() or GameMain.current_mode_id != "online":
		return
	
	# 按 Tab 键切换跟随的玩家
	if event.is_action_pressed("ui_focus_next"):  # Tab 键
		_switch_to_next_player()
		get_viewport().set_input_as_handled()


## 切换到下一个玩家
func _switch_to_next_player() -> void:
	if players.size() == 0:
		return
	
	# 获取所有有效的 peer_id 列表并排序
	var peer_ids: Array = []
	for peer_id in players.keys():
		var player = players[peer_id]
		if player and is_instance_valid(player):
			peer_ids.append(peer_id)
	
	if peer_ids.size() == 0:
		return
	
	peer_ids.sort()
	
	# 找到当前跟随的玩家在列表中的位置
	var current_index = peer_ids.find(_following_peer_id)
	
	# 切换到下一个（循环）
	var next_index = (current_index + 1) % peer_ids.size()
	_following_peer_id = peer_ids[next_index]
	
	var player = get_player_by_peer_id(_following_peer_id)
	var player_name = player.display_name if player else "Unknown"
	print("[NetworkPlayerManager] 切换跟随: peer_id=%d, name=%s" % [_following_peer_id, player_name])


## ==================== 公共接口 ====================

## 初始化在线模式（由 GameInitializerOnline 调用）
func init_online_mode() -> void:
	if NetworkManager.is_server():
		_setup_server_camera()
	else:
		# 客户端请求服务器创建玩家
		_request_spawn_player()


## 获取指定 peer_id 的玩家
func get_player_by_peer_id(peer_id: int) -> PlayerCharacter:
	if players.has(peer_id):
		var player = players[peer_id]
		if player and is_instance_valid(player):
			return player
	return null


## 注册本地玩家（仅单机模式使用，联网模式使用 player_online）
func register_local_player(player: Node) -> void:
	if GameMain.current_mode_id == "online":
		# 在线模式不使用此方法
		if player and is_instance_valid(player):
			player.queue_free()
		return
	
	# 单机模式（使用原版 PlayerCharacter）
	local_peer_id = NetworkManager.get_peer_id()
	local_player = null  # 单机模式不使用 local_player
	# 单机模式不需要注册到 players 字典


## ==================== 服务器端 ====================

## 设置服务器摄像机
func _setup_server_camera() -> void:
	# 禁用场景中的所有摄像机
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			cam.enabled = false
	
	# 创建服务器摄像机
	_server_camera = Camera2D.new()
	_server_camera.name = "ServerCamera"
	_server_camera.zoom = Vector2(0.9, 0.9)
	_server_camera.position_smoothing_enabled = true
	_server_camera.position_smoothing_speed = 5.0
	_server_camera.enabled = true
	_server_camera.global_position = SPAWN_POSITION
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(_server_camera)
		_server_camera.make_current()
	
	print("[NetworkPlayerManager] 服务器摄像机已创建")


## 服务器：处理客户端的 spawn 请求
@rpc("any_peer", "reliable")
func rpc_request_spawn(display_name: String) -> void:
	if not NetworkManager.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	print("[NetworkPlayerManager] 收到 spawn 请求: peer_id=%d, name=%s" % [peer_id, display_name])
	
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		print("[NetworkPlayerManager] 玩家已存在，跳过")
		return
	
	_server_create_player(peer_id, display_name)


## 服务器：创建玩家节点（使用默认 skin/class，游戏开始时会重新分配）
func _server_create_player(peer_id: int, display_name: String) -> void:
	var parent = _get_players_parent()
	if not parent:
		push_error("[NetworkPlayerManager] 找不到 Players 父节点")
		return
	
	var new_player: PlayerCharacter = PLAYER_SCENE.instantiate()
	
	new_player.name = "player_%d" % peer_id
	new_player.peer_id = peer_id
	new_player.display_name = display_name if display_name != "" else "Player %d" % peer_id
	new_player.player_class_id = "balanced"  # 默认，游戏开始时会分配
	new_player.position = SPAWN_POSITION
	
	parent.add_child(new_player, true)
	new_player.set_multiplayer_authority(peer_id)
	
	# 服务器端配置为远程玩家（服务器观察所有客户端玩家）
	new_player.configure_as_remote()
	new_player.mark_sync_completed()  # 服务器端立即显示
	
	# 更新武器的 owner_peer_id（关键：服务器上的武器需要知道它属于哪个客户端）
	_update_weapons_owner_peer_id(new_player)
	
	# 禁用摄像机（服务器使用自己的摄像机）
	var cam = new_player.get_node_or_null("Camera2D")
	if cam:
		cam.enabled = false
	
	players[peer_id] = new_player
	
	if _following_peer_id == 0:
		_following_peer_id = peer_id
	
	print("[NetworkPlayerManager] 服务器创建玩家完成: peer_id=%d, pos=%s" % [peer_id, str(new_player.global_position)])


## ==================== 客户端端 ====================

## 客户端：请求服务器创建玩家
func _request_spawn_player() -> void:
	local_peer_id = NetworkManager.get_peer_id()
	var display_name = _get_display_name()
	
	print("[NetworkPlayerManager] 客户端请求 spawn: name=%s" % display_name)
	rpc_id(1, "rpc_request_spawn", display_name)


## 客户端：MultiplayerSpawner 同步回调
func on_player_spawned(node: Node) -> void:
	if not node is PlayerCharacter:
		return
	
	# 服务器不处理（服务器在 _server_create_player 中已处理）
	if NetworkManager.is_server():
		return
	
	var player: PlayerCharacter = node as PlayerCharacter
	
	# 从节点名称解析 peer_id
	var peer_id = _parse_peer_id_from_name(player.name)
	if peer_id == 0:
		print("[NetworkPlayerManager] 无法解析 peer_id: %s" % player.name)
		return
	
	local_peer_id = NetworkManager.get_peer_id()
	var is_local = (peer_id == local_peer_id)
	
	print("[NetworkPlayerManager] 收到玩家同步: peer_id=%d, is_local=%s" % [peer_id, str(is_local)])
	
	# 设置基本属性
	player.peer_id = peer_id
	player.set_multiplayer_authority(peer_id)
	
	if is_local:
		# 本地玩家
		local_player = player
		_setup_local_player(player)
	else:
		# 远程玩家
		_setup_remote_player(player)
	
	players[peer_id] = player


## 服务器：游戏开始时为所有玩家分配身份（由 GameInitializerOnline 调用）
## 分配规则: 4名玩家 = 1 boss + 1 impostor + 2 player
## boss 的 class 固定，player/impostor 随机分配 class
func assign_player_identities() -> void:
	if not NetworkManager.is_server():
		return
	
	print("[NetworkPlayerManager] 开始分配玩家身份")
	
	# 重置叛变状态
	impostor_betrayed = false
	impostor_peer_id = 0
	
	# 获取所有玩家的 peer_id 并随机打乱（随机分配角色）
	var peer_ids: Array = players.keys()
	peer_ids.shuffle()
	
	# 准备 player/impostor 可用的职业（随机打乱，不重复分配）
	var player_classes = PLAYER_CLASSES.duplicate()
	player_classes.shuffle()
	
	# 准备角色列表: 1 boss, 1 impostor, 2 player
	var roles: Array = [ROLE_BOSS, ROLE_IMPOSTOR, ROLE_PLAYER, ROLE_PLAYER]
	
	# 如果当前只有一个玩家，则是分配 impostor
	if peer_ids.size() == 1:
		roles = [ROLE_IMPOSTOR]
	
	# 为每个玩家分配 role 和 class
	for i in range(peer_ids.size()):
		var peer_id = peer_ids[i]
		var role_id = roles[i] if i < roles.size() else ROLE_PLAYER
		var class_id: String
		
		# boss 角色使用固定职业，其他角色从打乱后的列表中依次取出（不重复）
		if role_id == ROLE_BOSS:
			class_id = BOSS_CLASS
		else:
			if player_classes.size() > 0:
				class_id = player_classes.pop_front()  # 取出并移除，保证不重复
			else:
				class_id = PLAYER_CLASSES[0]  # 备用：如果职业不够用
		
		# 记录 impostor 的 peer_id
		if role_id == ROLE_IMPOSTOR:
			impostor_peer_id = peer_id
		
		# 根据角色确定初始钥匙数量、武器和血量加成
		var init_gold: int
		var init_master_key: int
		var init_weapons: Array
		var init_hp_bonus: int
		match role_id:
			ROLE_BOSS:
				init_gold = INIT_GOLD_BOSS
				init_master_key = INIT_MASTER_KEY_BOSS
				init_weapons = INIT_WEAPONS_BOSS.duplicate()
				init_hp_bonus = INIT_HP_BONUS_BOSS
			ROLE_IMPOSTOR:
				init_gold = INIT_GOLD_IMPOSTOR
				init_master_key = INIT_MASTER_KEY_IMPOSTOR
				init_weapons = INIT_WEAPONS_IMPOSTOR.duplicate()
				init_hp_bonus = INIT_HP_BONUS_IMPOSTOR
			_:  # ROLE_PLAYER 或其他
				init_gold = INIT_GOLD_PLAYER
				init_master_key = INIT_MASTER_KEY_PLAYER
				init_weapons = INIT_WEAPONS_PLAYER.duplicate()
				init_hp_bonus = INIT_HP_BONUS_PLAYER
		
		# 更新服务器端的玩家
		var player = players[peer_id]
		if player and is_instance_valid(player):
			player.player_class_id = class_id
			player.player_role_id = role_id
			player.chooseClass(class_id)
			
			# boss 角色禁用武器（boss 不能攻击怪物）
			if role_id == ROLE_BOSS and player.has_method("disable_weapons"):
				player.disable_weapons()
			
			# 服务器端添加初始武器
			if init_weapons.size() > 0 and player.has_method("add_initial_weapons"):
				player.add_initial_weapons(init_weapons)
		
		# 广播给所有客户端（每个客户端都需要看到所有玩家的身份变化）
		rpc("rpc_assign_identity", peer_id, class_id, role_id, init_gold, init_master_key, init_weapons, init_hp_bonus)
		print("[NetworkPlayerManager] 分配身份: peer_id=%d, class=%s, role=%s, gold=%d, master_key=%d, hp_bonus=%d" % [peer_id, class_id, role_id, init_gold, init_master_key, init_hp_bonus])


## 客户端：接收服务器分配的身份（广播给所有客户端）
@rpc("authority", "call_local", "reliable")
func rpc_assign_identity(peer_id: int, class_id: String, role_id: String, init_gold: int = INIT_GOLD_PLAYER, init_master_key: int = INIT_MASTER_KEY_PLAYER, init_weapons: Array = [], init_hp_bonus: int = 0) -> void:
	print("[NetworkPlayerManager] 收到身份分配: peer_id=%d, class=%s, role=%s, gold=%d, master_key=%d, hp_bonus=%d" % [peer_id, class_id, role_id, init_gold, init_master_key, init_hp_bonus])
	
	# 查找对应的玩家
	var player = get_player_by_peer_id(peer_id)
	if not player:
		push_warning("[NetworkPlayerManager] 找不到 peer_id=%d 的玩家" % peer_id)
		return
	
	# 更新玩家的身份
	player.player_class_id = class_id
	player.player_role_id = role_id
	player.chooseClass(class_id)
	
	# 设置初始血量和钥匙数量（只有本地玩家设置，然后 MultiplayerSynchronizer 同步给其他人）
	if player.is_local_player:
		# 应用血量加成（累加）
		if init_hp_bonus > 0:
			var base_hp = player.base_max_hp if "base_max_hp" in player else player.max_hp
			player.max_hp = base_hp + init_hp_bonus
			player.now_hp = player.max_hp
			print("[NetworkPlayerManager] 本地玩家血量加成: base=%d, bonus=%d, max_hp=%d" % [base_hp, init_hp_bonus, player.max_hp])
		
		# 设置初始钥匙数量
		player.gold = init_gold
		player.master_key = init_master_key
		print("[NetworkPlayerManager] 本地玩家设置初始钥匙: gold=%d, master_key=%d" % [init_gold, init_master_key])
	
	# 为所有玩家添加初始武器（本地和远程都需要显示武器）
	if init_weapons.size() > 0 and player.has_method("add_initial_weapons"):
		player.add_initial_weapons(init_weapons)
		print("[NetworkPlayerManager] 玩家 %d 添加初始武器: %s" % [peer_id, str(init_weapons)])
	
	# boss 角色禁用武器（boss 不能攻击怪物）
	if role_id == ROLE_BOSS and player.has_method("disable_weapons"):
		player.disable_weapons()
	
	# 如果是远程玩家且还未显示，现在可以显示了
	if not player.is_local_player and not player._sync_completed:
		player.mark_sync_completed()
	
	# 记录 impostor 的 peer_id（客户端也需要知道）
	if role_id == ROLE_IMPOSTOR:
		impostor_peer_id = peer_id
	
	print("[NetworkPlayerManager] 玩家身份已更新: peer_id=%d, class=%s, role=%s" % [peer_id, class_id, role_id])


## 配置本地玩家
func _setup_local_player(player: PlayerCharacter) -> void:
	# 如果位置无效（0,0），设置为出生点
	if player.global_position == Vector2.ZERO or player.global_position.length() < 10:
		player.global_position = SPAWN_POSITION
		print("[NetworkPlayerManager] 修正本地玩家位置到: %s" % str(SPAWN_POSITION))
	
	player.configure_as_local()
	
	# 应用职业
	if player.player_class_id != "":
		player.chooseClass(player.player_class_id)
	if player.name_label and player.display_name != "":
		player.name_label.text = player.display_name
	
	# 更新武器的 owner_peer_id（武器的 _ready 可能在 peer_id 设置之前执行）
	_update_weapons_owner_peer_id(player)
	
	print("[NetworkPlayerManager] 本地玩家配置完成: %s, pos=%s" % [player.display_name, str(player.global_position)])


## 配置远程玩家
func _setup_remote_player(player: PlayerCharacter) -> void:
	player.configure_as_remote()
	print("[NetworkPlayerManager] 远程玩家配置完成: peer_id=%d" % player.peer_id)


## 更新玩家武器的 owner_peer_id
func _update_weapons_owner_peer_id(player: PlayerCharacter) -> void:
	var weapons_node = player.get_node_or_null("now_weapons")
	if not weapons_node:
		return
	
	for weapon in weapons_node.get_children():
		if weapon.has_method("set_owner_player"):
			weapon.set_owner_player(player)
	
	print("[NetworkPlayerManager] 更新武器 owner_peer_id: %d" % player.peer_id)


## ==================== 掉落物系统 ====================

var _drop_id_counter: int = 1

## 服务器：生成掉落物并同步给所有客户端
func spawn_drop(item_name: String, pos: Vector2, item_scale: Vector2 = Vector2(4, 4)) -> void:
	if not NetworkManager.is_server():
		return
	
	var drop_id = _drop_id_counter
	_drop_id_counter += 1
	
	# 服务器本地生成
	_create_drop_item(item_name, pos, item_scale, drop_id)
	
	# 广播给所有客户端
	rpc("rpc_spawn_drop", item_name, pos, item_scale, drop_id)
	
	print("[NetworkPlayerManager] 生成掉落物: %s, drop_id=%d" % [item_name, drop_id])


## 客户端：接收服务器生成的掉落物
@rpc("authority", "call_remote", "reliable")
func rpc_spawn_drop(item_name: String, pos: Vector2, item_scale: Vector2, drop_id: int) -> void:
	_create_drop_item(item_name, pos, item_scale, drop_id)


## 创建掉落物实例
func _create_drop_item(item_name: String, pos: Vector2, item_scale: Vector2, drop_id: int) -> void:
	if not GameMain.drop_item_scene_online_obj:
		push_error("[NetworkPlayerManager] drop_item_scene_online_obj 不存在")
		return
	
	GameMain.drop_item_scene_online_obj.gen_drop_item({
		"ani_name": item_name,
		"position": pos,
		"scale": item_scale,
		"drop_id": drop_id
	})


## 服务器：给玩家奖励资源
func award_player_resource(peer_id: int, item_type: String, amount: int = 1) -> void:
	if not NetworkManager.is_server():
		return
	
	print("[NetworkPlayerManager] 奖励玩家 peer_id=%d: %s x%d" % [peer_id, item_type, amount])
	
	# 如果是发给服务器自己（peer_id = 1），服务器不需要处理
	if peer_id == 1:
		print("[NetworkPlayerManager] 警告: peer_id=1 是服务器，服务器不收集资源")
		return
	
	var player = get_player_by_peer_id(peer_id)
	if not player or not is_instance_valid(player):
		print("[NetworkPlayerManager] 警告: 找不到玩家 peer_id=%d" % peer_id)
		return
	
	# 和 HP 一样：服务器通知客户端（authority）修改属性，MultiplayerSynchronizer 会自动同步给其他人
	if player.has_method("rpc_add_resource"):
		player.rpc_id(peer_id, "rpc_add_resource", item_type, amount)
		print("[NetworkPlayerManager] 通知客户端 %d 添加资源: %s x%d" % [peer_id, item_type, amount])


## 服务器：通知掉落物已被拾取
func notify_drop_collected(drop_id: int) -> void:
	if not NetworkManager.is_server():
		return
	
	print("[NetworkPlayerManager] 通知删除掉落物 drop_id=%d" % drop_id)
	
	# 广播给所有客户端（使用 call_local 确保服务器也执行）
	rpc("rpc_drop_collected", drop_id)


## 所有端：处理掉落物被拾取
@rpc("authority", "call_local", "reliable")
func rpc_drop_collected(drop_id: int) -> void:
	var peer_id = NetworkManager.get_peer_id()
	print("[NetworkPlayerManager] 删除掉落物 drop_id=%d (peer_id=%d, is_server=%s)" % [drop_id, peer_id, NetworkManager.is_server()])
	
	# 查找并删除对应的掉落物
	var drop_name = "drop_item_%d" % drop_id
	var drops = get_tree().get_nodes_in_group("network_drop")
	print("[NetworkPlayerManager] 当前 network_drop 组中有 %d 个物品" % drops.size())
	
	var found = false
	for drop in drops:
		var d_id = drop.get_meta("drop_id") if drop.has_meta("drop_id") else -1
		print("[NetworkPlayerManager] 检查物品: name=%s, meta_drop_id=%d" % [drop.name, d_id])
		if drop.name == drop_name or d_id == drop_id:
			drop.queue_free()
			print("[NetworkPlayerManager] 找到并删除掉落物: %s" % drop.name)
			found = true
			break
	
	if not found:
		print("[NetworkPlayerManager] 警告: 未找到 drop_id=%d 的掉落物!" % drop_id)


## ==================== 死亡系统 ====================

## 客户端请求复活（发送到服务器）
@rpc("any_peer", "call_remote", "reliable")
func request_revive() -> void:
	if not NetworkManager.is_server():
		return
	
	var requester_peer_id = multiplayer.get_remote_sender_id()
	print("[NetworkPlayerManager] 收到复活请求: peer_id=%d" % requester_peer_id)
	
	var player = get_player_by_peer_id(requester_peer_id)
	if not player or not is_instance_valid(player):
		print("[NetworkPlayerManager] 复活失败: 找不到玩家 peer_id=%d" % requester_peer_id)
		rpc_id(requester_peer_id, "rpc_revive_result", false, "找不到玩家")
		return
	
	# 检查玩家是否已死亡
	if player.now_hp > 0:
		print("[NetworkPlayerManager] 复活失败: 玩家未死亡 peer_id=%d" % requester_peer_id)
		rpc_id(requester_peer_id, "rpc_revive_result", false, "玩家未死亡")
		return
	
	# 检查 master_key 是否足够
	if player.master_key < REVIVE_COST_MASTER_KEY:
		print("[NetworkPlayerManager] 复活失败: master_key 不足 peer_id=%d (需要 %d, 拥有 %d)" % [requester_peer_id, REVIVE_COST_MASTER_KEY, player.master_key])
		rpc_id(requester_peer_id, "rpc_revive_result", false, "生命钥匙不足")
		return
	
	# 扣除 master_key（通知客户端修改，然后同步给其他人）
	if player.has_method("rpc_add_resource"):
		player.rpc_id(requester_peer_id, "rpc_add_resource", "master_key", -REVIVE_COST_MASTER_KEY)
	
	# 执行复活
	_server_revive_player(requester_peer_id)
	
	print("[NetworkPlayerManager] 玩家复活成功: peer_id=%d, 消耗 %d master_key" % [requester_peer_id, REVIVE_COST_MASTER_KEY])


## 服务器执行复活
func _server_revive_player(peer_id: int) -> void:
	var player = get_player_by_peer_id(peer_id)
	if not player or not is_instance_valid(player):
		return
	
	# 恢复满血（服务器直接修改，通过 rpc 通知客户端）
	var full_hp = player.max_hp
	
	# 通知客户端执行复活（客户端会修改 now_hp，然后 MultiplayerSynchronizer 同步）
	player.rpc_id(peer_id, "rpc_revive", full_hp)
	
	# 广播给所有其他客户端，让他们也看到复活效果
	for client_peer_id in multiplayer.get_peers():
		if client_peer_id != peer_id:
			player.rpc_id(client_peer_id, "rpc_show_revive_effect", peer_id)
	
	# 通知请求者复活成功
	rpc_id(peer_id, "rpc_revive_result", true, "复活成功")


## 客户端：接收复活结果
@rpc("authority", "call_remote", "reliable")
func rpc_revive_result(success: bool, message: String) -> void:
	print("[NetworkPlayerManager] 复活结果: success=%s, message=%s" % [success, message])
	
	# 通知本地玩家
	if local_player and is_instance_valid(local_player):
		if local_player.has_method("on_revive_result"):
			local_player.on_revive_result(success, message)


## ==================== 工具方法 ====================

func _get_players_parent() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root:
		var players_node = scene_root.get_node_or_null("Players")
		if players_node:
			return players_node
	return null


func _get_display_name() -> String:
	var name = SaveManager.get_player_name()
	if name == null or str(name).strip_edges() == "":
		name = "Player %d" % local_peer_id
	var death_count = SaveManager.get_total_death_count()
	return "%s - 第 %d 世" % [name, death_count + 1]


func _parse_peer_id_from_name(node_name: String) -> int:
	var parts = node_name.split("_")
	if parts.size() >= 2:
		return int(parts[-1])
	return 0


## ==================== 网络事件 ====================

func _on_peer_disconnected(peer_id: int) -> void:
	if GameMain.current_mode_id != "online":
		return
	
	if players.has(peer_id):
		var player = players[peer_id]
		if player and is_instance_valid(player):
			player.queue_free()
		players.erase(peer_id)
	
	# 更新摄像机跟随目标
	if NetworkManager.is_server() and peer_id == _following_peer_id:
		_following_peer_id = 0
		for pid in players.keys():
			if is_instance_valid(players[pid]):
				_following_peer_id = pid
				break


func _on_server_disconnected() -> void:
	if GameMain.current_mode_id != "online":
		return
	_cleanup()
	await SceneCleanupManager.change_scene_safely("res://scenes/UI/main_title.tscn")


func _on_network_stopped() -> void:
	_cleanup()


func _cleanup() -> void:
	for peer_id in players.keys():
		var player = players[peer_id]
		if is_instance_valid(player):
			player.queue_free()
	players.clear()
	local_player = null
	
	if _server_camera and is_instance_valid(_server_camera):
		_server_camera.queue_free()
		_server_camera = null
	_following_peer_id = 0


## ==================== 武器攻击效果同步系统 ====================

## 服务器广播子弹生成
## 服务器处理碰撞和伤害，客户端只显示视觉效果
func broadcast_spawn_bullet(start_pos: Vector2, direction: Vector2, speed: float, damage: int, is_critical: bool, owner_peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	
	print("[NetworkPlayerManager] 广播子弹: pos=%s, dir=%s, owner=%d" % [start_pos, direction, owner_peer_id])
	
	# 服务器本地生成（有碰撞检测，处理伤害）
	_spawn_bullet_server(start_pos, direction, speed, damage, is_critical, owner_peer_id)
	
	# 广播给所有客户端（只显示视觉效果）
	var peers = multiplayer.get_peers()
	print("[NetworkPlayerManager] 广播给客户端数量: %d" % peers.size())
	for peer_id in peers:
		rpc_id(peer_id, "rpc_spawn_bullet_visual", start_pos, direction, speed, is_critical, owner_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_spawn_bullet_visual(start_pos: Vector2, direction: Vector2, speed: float, is_critical: bool, owner_peer_id: int) -> void:
	# 客户端只创建视觉子弹（无碰撞检测）
	_spawn_bullet_client(start_pos, direction, speed, is_critical, owner_peer_id)


## 服务器创建子弹（有碰撞检测，处理伤害）
func _spawn_bullet_server(start_pos: Vector2, direction: Vector2, speed: float, damage: int, is_critical: bool, owner_peer_id: int) -> void:
	var bullet_scene = preload("res://scenes/bullets/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	# 获取武器数据（用于特殊效果）
	var weapon_data = null
	var player_stats = null
	var player = get_player_by_peer_id(owner_peer_id)
	if player:
		var weapons_node = player.get_node_or_null("now_weapons")
		if weapons_node and weapons_node.get_child_count() > 0:
			for w in weapons_node.get_children():
				if w is RangedWeapon:
					weapon_data = w.weapon_data
					player_stats = w.player_stats
					break
	
	bullet.start(start_pos, direction, speed, damage, is_critical, player_stats, weapon_data, owner_peer_id)


## 客户端创建视觉子弹（有碰撞检测用于消失，但不处理伤害）
func _spawn_bullet_client(start_pos: Vector2, direction: Vector2, speed: float, is_critical: bool, owner_peer_id: int) -> void:
	var bullet_scene = preload("res://scenes/bullets/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	# 标记为客户端视觉子弹（碰撞时只消失，不处理伤害）
	bullet.is_visual_only = true
	
	# 启动子弹（damage=0 因为客户端不处理伤害）
	bullet.start(start_pos, direction, speed, 0, is_critical, null, null, owner_peer_id)


## 服务器广播近战攻击动画
func broadcast_melee_attack(owner_peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	
	# 广播给所有客户端
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "rpc_melee_attack", owner_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_melee_attack(owner_peer_id: int) -> void:
	var player = get_player_by_peer_id(owner_peer_id)
	if not player:
		return
	
	var weapons_node = player.get_node_or_null("now_weapons")
	if not weapons_node:
		return
	
	for weapon in weapons_node.get_children():
		if weapon is MeleeWeapon:
			weapon._start_attack_animation()


## 服务器广播魔法攻击开始
func broadcast_magic_cast(target_pos: Vector2, radius: float, delay: float, owner_peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	
	# 广播给所有客户端
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "rpc_magic_cast", target_pos, radius, delay, owner_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_magic_cast(target_pos: Vector2, radius: float, delay: float, owner_peer_id: int) -> void:
	var player = get_player_by_peer_id(owner_peer_id)
	if not player:
		return
	
	var weapons_node = player.get_node_or_null("now_weapons")
	if not weapons_node:
		return
	
	for weapon in weapons_node.get_children():
		if weapon is MagicWeapon:
			weapon._client_show_cast(target_pos, radius, delay)
			break


## 服务器广播魔法攻击执行（无延迟）
func broadcast_magic_execute(target_pos: Vector2, radius: float, owner_peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	
	# 广播给所有客户端
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "rpc_magic_execute", target_pos, radius, owner_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_magic_execute(target_pos: Vector2, radius: float, owner_peer_id: int) -> void:
	var player = get_player_by_peer_id(owner_peer_id)
	if not player:
		return
	
	var weapons_node = player.get_node_or_null("now_weapons")
	if not weapons_node:
		return
	
	for weapon in weapons_node.get_children():
		if weapon is MagicWeapon:
			weapon._client_show_execute(target_pos, radius)
			break


## ==================== PvP 玩家间攻击系统 ====================

## 检查目标是否是有效的 PvP 目标（供 base_weapon 调用）
## 攻击规则：
## 1. Boss 和非 Boss 永远可以互相攻击
## 2. 叛变后：Impostor 和 Player 可以互相攻击
func is_valid_pvp_target(attacker_peer_id: int, target: Node2D) -> bool:
	if GameMain.current_mode_id != "online":
		return false
	
	# 目标必须是玩家
	if not target.is_in_group("player"):
		return false
	
	# 不能攻击自己
	if target.get("peer_id") == attacker_peer_id:
		return false
	
	# 目标已死亡，不能攻击
	var target_hp = target.get("now_hp")
	if target_hp != null and target_hp <= 0:
		return false
	
	# 获取攻击者
	var attacker = get_player_by_peer_id(attacker_peer_id)
	if not attacker:
		return false
	
	# 攻击者已死亡，不能攻击
	if attacker.now_hp <= 0:
		return false
	
	var attacker_role = attacker.get("player_role_id")
	var target_role = target.get("player_role_id")
	
	# 使用统一的攻击规则检查
	return can_attack_each_other(attacker_role, target_role)


## 处理近战武器碰撞（范围内检测可攻击玩家）
## 返回命中的玩家数组（用于应用特效）
func handle_melee_collision(attacker_peer_id: int, attack_pos: Vector2, hit_range: float, damage: int) -> Array:
	var hit_players: Array = []
	
	if GameMain.current_mode_id != "online":
		return hit_players
	
	var attacker = get_player_by_peer_id(attacker_peer_id)
	if not attacker:
		return hit_players
	
	var attacker_role = attacker.get("player_role_id")
	
	for player_peer_id in players.keys():
		var target_player = players[player_peer_id]
		if not target_player or not is_instance_valid(target_player):
			continue
		
		# 跳过自己
		if player_peer_id == attacker_peer_id:
			continue
		
		var target_role = target_player.get("player_role_id")
		
		# 检查是否可以攻击
		if not can_attack_each_other(attacker_role, target_role):
			continue
		
		# 检查距离
		var distance = attack_pos.distance_to(target_player.global_position)
		if distance > hit_range:
			continue
		
		hit_players.append(target_player)
		print("[NetworkPlayerManager] 近战 PvP 攻击: attacker=%d(%s), target=%d(%s), damage=%d" % [
			attacker_peer_id, attacker_role, player_peer_id, target_role, damage
		])
		
		# 服务器直接处理伤害
		_apply_pvp_damage(attacker_peer_id, player_peer_id, damage)
	
	return hit_players


## 子弹碰撞结果
enum BulletHitResult {
	IGNORE = 0,       # 忽略碰撞，继续飞行（如碰到自己）
	DESTROY = 1,      # 销毁子弹（视觉效果或无效目标）
	HIT_PLAYER = 2,   # 命中玩家（服务器已处理伤害）
	HIT_ENEMY = 3,    # 命中敌人（需要处理伤害）
}


## 统一处理子弹碰撞
## 参数:
##   owner_peer_id: 子弹发射者的 peer_id
##   body: 碰撞到的物体
##   damage: 伤害值
##   is_critical: 是否暴击
##   is_visual_only: 是否为客户端视觉子弹
## 返回: BulletHitResult
func handle_bullet_collision(owner_peer_id: int, body: Node2D, damage: int, is_critical: bool, is_visual_only: bool) -> int:
	# 检查是否碰到玩家
	if body.is_in_group("player"):
		var target_peer_id = body.get("peer_id")
		
		# 碰到自己，忽略碰撞
		if target_peer_id == owner_peer_id:
			return BulletHitResult.IGNORE
		
		# 客户端视觉子弹：只消失，不处理伤害
		if is_visual_only:
			return BulletHitResult.DESTROY
		
		# 服务器：检查 PvP 攻击
		if GameMain.current_mode_id == "online":
			var shooter = get_player_by_peer_id(owner_peer_id)
			if not shooter:
				return BulletHitResult.DESTROY
			
			var shooter_role = shooter.get("player_role_id")
			var target_role = body.get("player_role_id")
			
			# 检查是否可以攻击
			if not can_attack_each_other(shooter_role, target_role):
				return BulletHitResult.IGNORE  # 不能攻击，忽略碰撞
			
			print("[NetworkPlayerManager] 子弹 PvP 命中: shooter=%d(%s), target=%d(%s), damage=%d" % [
				owner_peer_id, shooter_role, target_peer_id, target_role, damage
			])
			
			# 服务器处理伤害
			_apply_pvp_damage(owner_peer_id, target_peer_id, damage)
			return BulletHitResult.HIT_PLAYER
		
		return BulletHitResult.DESTROY
	
	# 检查是否碰到敌人
	if body.is_in_group("enemy"):
		# 客户端视觉子弹：只消失，不处理伤害
		if is_visual_only:
			return BulletHitResult.DESTROY
		
		# 返回命中敌人，让 bullet.gd 处理伤害和特效
		return BulletHitResult.HIT_ENEMY
	
	# 其他碰撞，销毁子弹
	return BulletHitResult.DESTROY


## 处理魔法武器爆炸碰撞（范围内检测可攻击玩家）
## 返回命中的玩家数组（用于应用特效）
func handle_explosion_collision(caster_peer_id: int, explosion_pos: Vector2, radius: float, base_damage: int, damage_multiplier: float = 1.0) -> Array:
	var hit_players: Array = []
	
	if GameMain.current_mode_id != "online":
		return hit_players
	
	var caster = get_player_by_peer_id(caster_peer_id)
	if not caster:
		return hit_players
	
	var caster_role = caster.get("player_role_id")
	
	for player_peer_id in players.keys():
		var target_player = players[player_peer_id]
		if not target_player or not is_instance_valid(target_player):
			continue
		
		# 跳过自己
		if player_peer_id == caster_peer_id:
			continue
		
		var target_role = target_player.get("player_role_id")
		
		# 检查是否可以攻击
		if not can_attack_each_other(caster_role, target_role):
			continue
		
		# 检查距离
		var distance = explosion_pos.distance_to(target_player.global_position)
		if distance > radius:
			continue
		
		# 根据距离计算伤害
		var explosion_damage_mult = 1.0 - (distance / radius) * 0.5
		var final_damage = int(base_damage * explosion_damage_mult * damage_multiplier)
		
		hit_players.append(target_player)
		print("[NetworkPlayerManager] 爆炸 PvP 命中: caster=%d(%s), target=%d(%s), damage=%d" % [
			caster_peer_id, caster_role, player_peer_id, target_role, final_damage
		])
		
		# 服务器直接处理伤害
		_apply_pvp_damage(caster_peer_id, player_peer_id, final_damage)
	
	return hit_players


## 内部函数：处理 PvP 伤害（服务器调用）
func _apply_pvp_damage(attacker_peer_id: int, target_peer_id: int, damage: int) -> void:
	var attacker = get_player_by_peer_id(attacker_peer_id)
	var target = get_player_by_peer_id(target_peer_id)
	
	if not attacker or not target:
		return
	
	# 检查攻击者或目标是否已死亡
	if attacker.now_hp <= 0:
		return
	if target.now_hp <= 0:
		return
	
	var attacker_role = attacker.get("player_role_id")
	var target_role = target.get("player_role_id")
	
	# 使用统一的攻击规则检查
	var is_valid_attack = can_attack_each_other(attacker_role, target_role)
	
	if not is_valid_attack:
		print("[NetworkPlayerManager] 无效的 PvP 攻击: attacker_role=%s, target_role=%s" % [attacker_role, target_role])
		return
	
	print("[NetworkPlayerManager] PvP 攻击: attacker=%d(%s) -> target=%d(%s), damage=%d" % [
		attacker_peer_id, attacker_role, target_peer_id, target_role, damage
	])
	
	# 造成伤害
	if target.has_method("player_hurt"):
		target.player_hurt(damage)


## RPC：处理玩家攻击玩家（客户端发送给服务器，如 Boss 玩家攻击）
@rpc("any_peer", "call_remote", "reliable")
func rpc_player_attack_player(attacker_peer_id: int, target_peer_id: int, damage: int) -> void:
	# 只有服务器处理伤害
	if not NetworkManager.is_server():
		return
	
	_apply_pvp_damage(attacker_peer_id, target_peer_id, damage)


## ==================== Impostor 叛变系统 ====================

## 检查本地玩家是否是 Impostor
func is_local_player_impostor() -> bool:
	return local_player and local_player.player_role_id == ROLE_IMPOSTOR


## 检查是否可以叛变（只有 Impostor 且未叛变才能触发）
func can_betray() -> bool:
	return is_local_player_impostor() and not impostor_betrayed


## Impostor 触发叛变（由客户端调用）
func trigger_betrayal() -> void:
	if not can_betray():
		return
	
	print("[NetworkPlayerManager] Impostor 请求叛变")
	# 发送叛变请求给服务器
	rpc_id(1, "rpc_request_betrayal")


## 服务器：处理叛变请求
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_betrayal() -> void:
	if not NetworkManager.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# 验证发送者是 Impostor
	if sender_id != impostor_peer_id:
		print("[NetworkPlayerManager] 非法叛变请求: sender=%d, impostor=%d" % [sender_id, impostor_peer_id])
		return
	
	# 验证尚未叛变
	if impostor_betrayed:
		print("[NetworkPlayerManager] 已经叛变过了")
		return
	
	# 执行叛变
	_execute_betrayal()


## 服务器：执行叛变
func _execute_betrayal() -> void:
	impostor_betrayed = true
	print("[NetworkPlayerManager] Impostor 叛变成功！peer_id=%d" % impostor_peer_id)
	
	# 广播叛变消息给所有客户端
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "rpc_betrayal_notification", impostor_peer_id)
	
	# 服务器本地也执行
	_on_betrayal_confirmed(impostor_peer_id)
	
	# 发送信号
	impostor_betrayal_triggered.emit(impostor_peer_id)


## 客户端：接收叛变通知
@rpc("any_peer", "call_remote", "reliable")
func rpc_betrayal_notification(betrayer_peer_id: int) -> void:
	_on_betrayal_confirmed(betrayer_peer_id)


## 叛变确认后的处理（服务器和客户端都执行）
func _on_betrayal_confirmed(betrayer_peer_id: int) -> void:
	impostor_betrayed = true
	impostor_peer_id = betrayer_peer_id
	
	print("[NetworkPlayerManager] 收到叛变通知！Impostor peer_id=%d" % betrayer_peer_id)
	
	# 获取 Impostor 玩家
	var impostor = get_player_by_peer_id(betrayer_peer_id)
	if impostor and is_instance_valid(impostor):
		# 可以在这里添加视觉效果，如改变名字颜色等
		if impostor.has_method("on_betrayal"):
			impostor.on_betrayal()
	
	# 显示叛变提示
	var impostor_name = "未知"
	if impostor:
		impostor_name = impostor.display_name
	
	FloatingText.create_floating_text(
		Vector2(get_viewport().get_visible_rect().size.x / 2, 200),
		"⚠ %s 叛变了！" % impostor_name,
		Color(1.0, 0.5, 0.0, 1.0),  # 橙色
		true
	)


## 检查两个角色是否可以互相攻击
func can_attack_each_other(attacker_role: String, target_role: String) -> bool:
	# Boss 和非 Boss 永远可以互相攻击
	if attacker_role == ROLE_BOSS and target_role != ROLE_BOSS:
		return true
	if attacker_role != ROLE_BOSS and target_role == ROLE_BOSS:
		return true
	
	# 叛变后：Impostor、Player、Boss 三方混战
	if impostor_betrayed:
		# Impostor 和 Player 可以互相攻击
		if attacker_role == ROLE_IMPOSTOR and target_role == ROLE_PLAYER:
			return true
		if attacker_role == ROLE_PLAYER and target_role == ROLE_IMPOSTOR:
			return true
	
	return false


## ==================== 升级商店系统 ====================

## Boss 可购买的升级类型（血量和移动速度相关）
const BOSS_ALLOWED_UPGRADE_TYPES := [
	UpgradeData.UpgradeType.HP_MAX,       # HP上限
	UpgradeData.UpgradeType.MOVE_SPEED,   # 移动速度
	UpgradeData.UpgradeType.HEAL_HP,      # 恢复HP
]


## 检查玩家是否可以使用商店
func can_use_shop(peer_id: int) -> bool:
	var player = get_player_by_peer_id(peer_id)
	if not player:
		return false
	return true


## 检查升级类型是否对 Boss 可用
func is_upgrade_allowed_for_boss(upgrade_type: int) -> bool:
	return upgrade_type in BOSS_ALLOWED_UPGRADE_TYPES


## 客户端请求购买升级
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_purchase(upgrade_type: int, upgrade_name: String, cost: int, weapon_id: String, custom_value: float, stats_data: Dictionary) -> void:
	if not NetworkManager.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_player_by_peer_id(sender_id)
	
	if not player:
		print("[NetworkPlayerManager] 购买失败: 找不到玩家 peer_id=%d" % sender_id)
		rpc_id(sender_id, "rpc_purchase_result", false, "找不到玩家")
		return
	
	# 检查是否是 Boss
	var role = player.get("player_role_id")
	if role == ROLE_BOSS:
		# Boss 只能购买血量和移动速度相关的升级
		if not is_upgrade_allowed_for_boss(upgrade_type):
			print("[NetworkPlayerManager] 购买失败: Boss 不能购买此类型升级 (type=%d)" % upgrade_type)
			rpc_id(sender_id, "rpc_purchase_result", false, "Boss 不能购买此升级")
			return
	
	# 检查钥匙是否足够（通过 RPC 让客户端扣除）
	var player_gold = player.get("gold")
	if player_gold == null or player_gold < cost:
		print("[NetworkPlayerManager] 购买失败: 钥匙不足 (需要 %d, 拥有 %d)" % [cost, player_gold if player_gold else 0])
		rpc_id(sender_id, "rpc_purchase_result", false, "钥匙不足")
		return
	
	print("[NetworkPlayerManager] 处理购买请求: peer_id=%d, upgrade=%s, cost=%d" % [sender_id, upgrade_name, cost])
	
	# 扣除钥匙（通知客户端）
	rpc_id(sender_id, "rpc_deduct_gold", cost)
	
	# 根据升级类型应用效果
	_apply_upgrade_on_server(sender_id, upgrade_type, upgrade_name, weapon_id, custom_value, stats_data)
	
	# 通知购买成功
	rpc_id(sender_id, "rpc_purchase_result", true, "购买成功")


## 客户端请求刷新商店
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_shop_refresh(cost: int) -> void:
	if not NetworkManager.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_player_by_peer_id(sender_id)
	
	if not player:
		print("[NetworkPlayerManager] 刷新失败: 找不到玩家 peer_id=%d" % sender_id)
		rpc_id(sender_id, "rpc_refresh_result", false, "找不到玩家")
		return
	
	# 检查钥匙是否足够
	var player_gold = player.get("gold")
	if player_gold == null or player_gold < cost:
		print("[NetworkPlayerManager] 刷新失败: 钥匙不足 (需要 %d, 拥有 %d)" % [cost, player_gold if player_gold else 0])
		rpc_id(sender_id, "rpc_refresh_result", false, "钥匙不足")
		return
	
	print("[NetworkPlayerManager] 处理刷新请求: peer_id=%d, cost=%d" % [sender_id, cost])
	
	# 扣除钥匙（通知客户端）
	rpc_id(sender_id, "rpc_deduct_gold", cost)
	
	# 通知刷新成功
	rpc_id(sender_id, "rpc_refresh_result", true, "刷新成功")


## 客户端：刷新商店结果
@rpc("authority", "call_remote", "reliable")
func rpc_refresh_result(success: bool, message: String) -> void:
	print("[NetworkPlayerManager] 刷新结果: success=%s, message=%s" % [success, message])
	
	# 通知商店 UI 处理结果
	var upgrade_shop = get_tree().get_first_node_in_group("upgrade_shop")
	if upgrade_shop and upgrade_shop.has_method("on_refresh_result"):
		upgrade_shop.on_refresh_result(success, message)


## 服务器端应用升级效果
func _apply_upgrade_on_server(peer_id: int, upgrade_type: int, upgrade_name: String, weapon_id: String, custom_value: float, stats_data: Dictionary) -> void:
	var player = get_player_by_peer_id(peer_id)
	if not player:
		return
	
	match upgrade_type:
		UpgradeData.UpgradeType.HEAL_HP:
			_server_apply_heal(peer_id, custom_value)
		UpgradeData.UpgradeType.NEW_WEAPON:
			_server_apply_new_weapon(peer_id, weapon_id)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_server_apply_weapon_level_up(peer_id, weapon_id)
		_:
			# 属性升级
			_server_apply_attribute_upgrade(peer_id, stats_data)
	
	print("[NetworkPlayerManager] 升级已应用: peer_id=%d, type=%d, name=%s" % [peer_id, upgrade_type, upgrade_name])


## 服务器应用治疗效果
func _server_apply_heal(peer_id: int, heal_amount: float) -> void:
	var amount = int(heal_amount) if heal_amount > 0 else 10
	# 通知客户端恢复血量
	var player = get_player_by_peer_id(peer_id)
	if player and player.has_method("rpc_heal"):
		rpc_id(peer_id, "rpc_heal", amount)
		print("[NetworkPlayerManager] 治疗: peer_id=%d, amount=%d" % [peer_id, amount])


## 服务器应用新武器
func _server_apply_new_weapon(peer_id: int, weapon_id: String) -> void:
	# 广播给所有客户端添加武器
	rpc("rpc_add_weapon", peer_id, weapon_id)
	print("[NetworkPlayerManager] 新武器: peer_id=%d, weapon=%s" % [peer_id, weapon_id])


## 服务器应用武器升级
func _server_apply_weapon_level_up(peer_id: int, weapon_id: String) -> void:
	# 广播给所有客户端升级武器
	rpc("rpc_upgrade_weapon", peer_id, weapon_id)
	print("[NetworkPlayerManager] 武器升级: peer_id=%d, weapon=%s" % [peer_id, weapon_id])


## 服务器应用属性升级
func _server_apply_attribute_upgrade(peer_id: int, stats_data: Dictionary) -> void:
	# 广播给所有客户端应用属性升级
	rpc("rpc_apply_stats_upgrade", peer_id, stats_data)
	print("[NetworkPlayerManager] 属性升级: peer_id=%d, stats=%s" % [peer_id, str(stats_data)])


## 客户端：扣除钥匙
@rpc("authority", "call_remote", "reliable")
func rpc_deduct_gold(amount: int) -> void:
	if not local_player:
		return
	
	local_player.gold -= amount
	if local_player.gold < 0:
		local_player.gold = 0
	print("[NetworkPlayerManager] 扣除钥匙: %d, 剩余: %d" % [amount, local_player.gold])


## 客户端：购买结果
@rpc("authority", "call_remote", "reliable")
func rpc_purchase_result(success: bool, message: String) -> void:
	print("[NetworkPlayerManager] 购买结果: success=%s, message=%s" % [success, message])
	
	# 通知商店 UI 处理结果
	var upgrade_shop = get_tree().get_first_node_in_group("upgrade_shop")
	if upgrade_shop and upgrade_shop.has_method("on_purchase_result"):
		upgrade_shop.on_purchase_result(success, message)


## 所有客户端：添加武器
@rpc("authority", "call_local", "reliable")
func rpc_add_weapon(peer_id: int, weapon_id: String) -> void:
	var player = get_player_by_peer_id(peer_id)
	if not player:
		return
	
	var weapons_node = player.get_node_or_null("now_weapons")
	if weapons_node and weapons_node.has_method("add_weapon"):
		weapons_node.add_weapon(weapon_id, 1)
		print("[NetworkPlayerManager] 玩家 %d 添加武器: %s" % [peer_id, weapon_id])


## 所有客户端：升级武器
@rpc("authority", "call_local", "reliable")
func rpc_upgrade_weapon(peer_id: int, weapon_id: String) -> void:
	var player = get_player_by_peer_id(peer_id)
	if not player:
		return
	
	var weapons_node = player.get_node_or_null("now_weapons")
	if weapons_node and weapons_node.has_method("get_lowest_level_weapon_of_type"):
		var weapon = weapons_node.get_lowest_level_weapon_of_type(weapon_id)
		if weapon and weapon.has_method("upgrade_level"):
			weapon.upgrade_level()
			print("[NetworkPlayerManager] 玩家 %d 武器升级: %s" % [peer_id, weapon_id])


## 所有客户端：应用属性升级
@rpc("authority", "call_local", "reliable")
func rpc_apply_stats_upgrade(peer_id: int, stats_data: Dictionary) -> void:
	var player = get_player_by_peer_id(peer_id)
	if not player:
		return
	
	# 只有本地玩家实际应用属性（然后通过 MultiplayerSynchronizer 同步）
	if player.is_local_player:
		_apply_stats_to_player(player, stats_data)
		print("[NetworkPlayerManager] 本地玩家应用属性升级: %s" % str(stats_data))


## 应用属性到玩家
func _apply_stats_to_player(player: PlayerCharacter, stats_data: Dictionary) -> void:
	# 检查是否使用新属性系统
	if player.has_node("AttributeManager"):
		var attr_manager = player.get_node("AttributeManager")
		var modifier = AttributeModifier.new()
		modifier.modifier_type = AttributeModifier.ModifierType.UPGRADE
		modifier.modifier_id = "upgrade_" + str(Time.get_ticks_msec())
		
		# 从 stats_data 创建 CombatStats（增量模式，需要清零默认值）
		var stats = CombatStats.new()
		# ⭐ 清零默认值，避免意外累加
		stats.max_hp = 0
		stats.speed = 0.0
		stats.crit_damage = 0.0
		
		# 只设置传入的属性值
		for key in stats_data.keys():
			if key in stats:
				stats.set(key, stats_data[key])
		
		modifier.stats_delta = stats
		attr_manager.add_permanent_modifier(modifier)
		print("[NetworkPlayerManager] 应用属性升级到 AttributeManager: %s" % str(stats_data))
	else:
		# 降级方案：直接修改玩家属性
		if stats_data.has("max_hp") and stats_data["max_hp"] != 0:
			player.max_hp += int(stats_data["max_hp"])
		if stats_data.has("speed") and stats_data["speed"] != 0:
			player.speed += stats_data["speed"]
		print("[NetworkPlayerManager] 应用属性升级（降级方案）: %s" % str(stats_data))
