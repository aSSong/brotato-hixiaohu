extends Node
class_name PlayerPvPOnline

## 玩家 PvP 系统（联网模式）
## 管理 Boss 移动攻击和玩家间战斗
## Boss 在移动时会自动攻击附近的非 Boss 玩家

## 引用父节点（玩家）
var player: PlayerCharacter = null

## Boss 移动攻击参数
@export var boss_attack_damage: int = 20             # 攻击伤害
@export var boss_attack_cooldown: float = 1.0        # 对同一玩家的攻击冷却
@export var boss_attack_range: float = 120.0         # 攻击判定范围
@export var boss_min_speed_for_attack: float = 100.0 # 触发攻击的最小移动速度

## 内部状态 - 记录每个玩家的攻击冷却
var _player_attack_cooldowns: Dictionary = {}  # peer_id -> cooldown_timer


func _ready() -> void:
	# 获取父节点（玩家）
	player = get_parent() as PlayerCharacter
	if not player:
		push_error("[PlayerPvPOnline] 父节点不是 PlayerCharacter")
		return


func _process(delta: float) -> void:
	if not player:
		return
	
	# 只有本地 Boss 玩家才处理攻击逻辑
	if player.is_local_player and player.player_role_id == "boss":
		_update_boss_attack(delta)


## ==================== Boss 移动攻击系统 ====================

## 更新 Boss 移动攻击
func _update_boss_attack(delta: float) -> void:
	# 更新所有玩家的攻击冷却
	_update_attack_cooldowns(delta)
	
	# 检查是否在移动（速度足够快）
	var current_speed = player.velocity.length()
	if current_speed < boss_min_speed_for_attack:
		return
	
	# 检测并攻击附近的非 Boss 玩家
	_check_and_attack_nearby_players()


## 更新攻击冷却计时器
func _update_attack_cooldowns(delta: float) -> void:
	var keys_to_remove: Array = []
	
	for peer_id in _player_attack_cooldowns.keys():
		_player_attack_cooldowns[peer_id] -= delta
		if _player_attack_cooldowns[peer_id] <= 0:
			keys_to_remove.append(peer_id)
	
	for peer_id in keys_to_remove:
		_player_attack_cooldowns.erase(peer_id)


## 检测并攻击附近的玩家
func _check_and_attack_nearby_players() -> void:
	for player_peer_id in NetworkPlayerManager.players.keys():
		var target_player = NetworkPlayerManager.players[player_peer_id]
		if not target_player or not is_instance_valid(target_player):
			continue
		
		# 跳过自己
		if target_player == player:
			continue
		
		# 跳过其他 boss
		if target_player.get("player_role_id") == "boss":
			continue
		
		# 跳过已死亡的玩家
		var target_hp = target_player.get("now_hp")
		if target_hp != null and target_hp <= 0:
			continue
		
		# 跳过正在冷却的玩家
		if _player_attack_cooldowns.has(player_peer_id):
			continue
		
		# 检查距离
		var distance = player.global_position.distance_to(target_player.global_position)
		if distance < boss_attack_range:
			# 命中！设置冷却
			_player_attack_cooldowns[player_peer_id] = boss_attack_cooldown
			print("[Boss] 移动攻击命中玩家: peer_id=%d" % player_peer_id)
			
			# 通知服务器处理伤害
			if GameMain.current_mode_id == "online":
				rpc_id(1, "rpc_boss_attack_hit", player_peer_id, boss_attack_damage)


## ==================== RPC 函数 ====================

## RPC：服务器处理 Boss 攻击命中伤害
@rpc("any_peer", "call_remote", "reliable")
func rpc_boss_attack_hit(target_peer_id: int, damage: int) -> void:
	# 只有服务器处理伤害
	if not NetworkManager.is_server():
		return
	
	var target_player = NetworkPlayerManager.get_player_by_peer_id(target_peer_id)
	if not target_player or not target_player.has_method("player_hurt"):
		return
	
	# 检查目标是否已死亡
	if target_player.now_hp <= 0:
		return
	
	print("[Server] Boss 攻击伤害: target=%d, damage=%d" % [target_peer_id, damage])
	target_player.player_hurt(damage)


## ==================== 查询方法 ====================

## 是否可以攻击指定玩家（未在冷却中）
func can_attack_player(peer_id: int) -> bool:
	return not _player_attack_cooldowns.has(peer_id)


## 获取对指定玩家的剩余冷却时间
func get_attack_cooldown(peer_id: int) -> float:
	return _player_attack_cooldowns.get(peer_id, 0.0)
