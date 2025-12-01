extends Node
class_name WaveSystemOnline

## 新的波次系统 Online

## ========== 状态定义 ==========
enum WaveState {
	IDLE,           # 空闲，等待开始
	SPAWNING,       # 正在生成敌人
	FIGHTING,       # 战斗中（生成完毕，等待击杀）
	WAVE_COMPLETE,  # 本波完成，准备显示商店
	SHOP_OPEN,      # 商店开启中
}

## ========== 配置 ==========
var wave_configs: Array = []  # 波次配置
var current_wave: int = 0
var current_state: WaveState = WaveState.IDLE
var enemy_add_multi:int = 5 #每波增加敌人数

## ========== 敌人追踪 ==========
var active_enemies: Array = []  # 当前存活的敌人实例列表（直接引用）
var total_enemies_this_wave: int = 0
var spawned_enemies_this_wave: int = 0
var killed_enemies_this_wave: int = 0  # 用于统计击杀数

## ========== 兼容性属性（供UI等外部访问）==========
## 为了兼容旧代码，提供这些属性的访问
var enemies_killed_this_wave: int:
	get:
		return killed_enemies_this_wave

var enemies_total_this_wave: int:
	get:
		return total_enemies_this_wave

var enemies_spawned_this_wave: int:
	get:
		return spawned_enemies_this_wave

## ========== 信号 ==========
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()
signal state_changed(new_state: WaveState)
signal enemy_killed(wave_number: int, killed: int, total: int)  # 兼容UI

## ========== 引用 ==========
var enemy_spawner: Node = null  # 敌人生成器
var shop_countdown_seconds: int = 10 # 商店倒计时时间
var _shop_timer: Timer = null
var _shop_remaining_seconds: int = 0

func _is_network_server() -> bool:
	return NetworkManager.is_server()

func _ready() -> void:
	_initialize_waves()

	if _shop_timer == null:
		_shop_timer = Timer.new()
		_shop_timer.one_shot = true
		_shop_timer.wait_time = float(shop_countdown_seconds)
		add_child(_shop_timer)
		_shop_timer.timeout.connect(_on_shop_timer_timeout)

## 初始化波次配置
func _initialize_waves() -> void:
	wave_configs.clear()
	
	# 200波，每波比上一波多2个敌人
	# 第1波: 10个敌人 (9个普通 + 1个BOSS)
	# 第2波: 12个敌人 (11个普通 + 1个BOSS)
	# ...
	# 第200波: 408个敌人
	
	# 敌人配比：50%基础，20%快速，20%坦克，10%精英
	
	for wave in range(200):
		var wave_number = wave + 1
		
		# 计算本波普通敌人数量（不含BOSS）
		# 第1波: 9个普通 + 1个BOSS = 10个
		# 第2波: 11个普通 + 1个BOSS = 12个
		var normal_enemy_count = 9 + (wave * enemy_add_multi )
		
		# 按照配比分配敌人数量
		var basic_count = int(normal_enemy_count * 0.5)   # 50%基础敌人
		var fast_count = int(normal_enemy_count * 0.2)    # 20%快速敌人
		var tank_count = int(normal_enemy_count * 0.2)    # 20%坦克敌人
		var elite_count = int(normal_enemy_count * 0.1)   # 10%精英敌人
		
		# 确保总数正确（处理取整误差）
		var total = basic_count + fast_count + tank_count + elite_count
		var diff = normal_enemy_count - total
		if diff > 0:
			basic_count += diff  # 余数加到基础敌人
		
		# 确保每种敌人至少有1个（从第1波开始）
		if basic_count == 0:
			basic_count = 1
		if fast_count == 0:
			fast_count = 1
		if tank_count == 0:
			tank_count = 1
		if elite_count == 0:
			elite_count = 1
		
		# 重新平衡（如果强制添加后超出）
		total = basic_count + fast_count + tank_count + elite_count
		if total > normal_enemy_count:
			var excess = total - normal_enemy_count
			basic_count = max(1, basic_count - excess)
		
		var config = {
			"wave_number": wave_number,
			"enemies": [
				{"id": "basic", "count": basic_count},
				{"id": "fast", "count": fast_count},
				{"id": "tank", "count": tank_count},
				{"id": "elite", "count": elite_count}
			],
			"last_enemy": {"id": "last_enemy", "count": 1}  # BOSS
		}
		
		wave_configs.append(config)
	
	print("[WaveSystem Online] 初始化完成：", wave_configs.size(), "波")
	print("[WaveSystem Online] 第1波配置：", wave_configs[0])
	print("[WaveSystem Online] 第10波配置：", wave_configs[9])

## 设置敌人生成器
func set_enemy_spawner(spawner: Node) -> void:
	enemy_spawner = spawner
	print("[WaveSystem Online] 设置生成器：", spawner.name)

## 开始游戏（第一波）
func start_game() -> void:
	if not _is_network_server():
		push_warning("[WaveSystem Online] 非服务器节点，忽略开始游戏")
		return

	if current_state != WaveState.IDLE:
		push_warning("[WaveSystem Online] 游戏已经开始，忽略")
		return
	
	print("[WaveSystem Online] 开始游戏")
	start_next_wave()

## 开始下一波 (仅服务器端调用)
func start_next_wave() -> void:
	# 状态检查
	if current_state != WaveState.IDLE and current_state != WaveState.WAVE_COMPLETE:
		push_warning("[WaveSystem Online] 波次进行中，不能开始新波次")
		return
	
	# 检查是否还有波次
	if current_wave >= wave_configs.size():
		_change_state_local(WaveState.IDLE)
		all_waves_completed.emit()
		print("[WaveSystem Online] ===== 所有波次完成！=====")
		return
		
	# 开始新波次
	current_wave += 1
	var config = wave_configs[current_wave - 1]
	
	# 计算总敌人数
	total_enemies_this_wave = 0
	for enemy_group in config.enemies:
		total_enemies_this_wave += enemy_group.count
	total_enemies_this_wave += config.last_enemy.count
	
	spawned_enemies_this_wave = 0
	killed_enemies_this_wave = 0  # 重置击杀计数
	
	# 广播波次开始
	_broadcast_wave_start()

## 敌人生成成功的回调（由生成器调用）
func on_enemy_spawned(enemy: Node) -> void:
	if current_state != WaveState.SPAWNING and current_state != WaveState.FIGHTING:
		return
	register_enemy_instance(enemy)

## 生成完毕
## 敌人死亡回调
func _on_enemy_died(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 敌人被移除（queue_free）
func _on_enemy_removed(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 从追踪列表中移除敌人
func _remove_enemy(enemy_ref: Node) -> void:
	if not enemy_ref:
		return
	_untrack_enemy_instance(enemy_ref)
	if _is_network_server():
		_server_register_enemy_kill(enemy_ref)

func _untrack_enemy_instance(enemy_ref: Node) -> void:
	var index := active_enemies.find(enemy_ref)
	if index != -1:
		active_enemies.remove_at(index)
	if enemy_ref and enemy_ref.tree_exiting.is_connected(_on_enemy_removed):
		enemy_ref.tree_exiting.disconnect(_on_enemy_removed)
	if enemy_ref and enemy_ref.has_signal("enemy_killed") and enemy_ref.enemy_killed.is_connected(_on_enemy_died):
		enemy_ref.enemy_killed.disconnect(_on_enemy_died)
	print("[WaveSystem Online] 敌人移除 | 当前存活：", active_enemies.size())

func _server_register_enemy_kill(enemy_ref: Node) -> void:
	killed_enemies_this_wave = min(killed_enemies_this_wave + 1, total_enemies_this_wave)
	print("[WaveSystem Online] 敌人被击杀 | 击杀：", killed_enemies_this_wave, " 剩余：", total_enemies_this_wave - killed_enemies_this_wave)
	if enemy_spawner and enemy_ref is Enemy and enemy_spawner.has_method("notify_enemy_removed"):
		enemy_spawner.notify_enemy_removed(enemy_ref)
	_broadcast_wave_status()
	if killed_enemies_this_wave >= total_enemies_this_wave:
		_server_on_wave_completed()

func _server_on_wave_completed() -> void:
	print("[WaveSystem Online] ========== 第 ", current_wave, " 波完成！==========")
	print("[WaveSystem Online] 已生成：", spawned_enemies_this_wave, " 目标：", total_enemies_this_wave)
	_change_state_local(WaveState.WAVE_COMPLETE)
	_broadcast_wave_status()
	call_deferred("_show_shop")

## 检查波次是否完成
func _check_wave_complete() -> void:
	if not _is_network_server():
		return
	if current_state != WaveState.FIGHTING:
		return
	
	# 清理无效引用
	_cleanup_invalid_enemies()
	
	# 检查是否所有敌人都被清除
	if active_enemies.is_empty():
		killed_enemies_this_wave = total_enemies_this_wave
		_broadcast_wave_status()
		_server_on_wave_completed()

## 清理无效的敌人引用
func _cleanup_invalid_enemies() -> void:
	var valid_enemies = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

## 显示商店
func _show_shop() -> void:
	if current_state != WaveState.WAVE_COMPLETE:
		return
	
	if _is_network_server():
		rpc(&"rpc_show_shop")


@rpc("authority", "call_local")
func rpc_show_shop() -> void:
	if current_state != WaveState.WAVE_COMPLETE:
		_change_state_local(WaveState.WAVE_COMPLETE)
	await _open_shop_sequence()


func _open_shop_sequence() -> void:
	if current_state != WaveState.WAVE_COMPLETE:
		return
	
	# 延迟2秒再打开商店
	print("[WaveSystem Online] 波次完成，2秒后打开商店...")
	
	# 使用安全的方式等待（避免场景切换时出错）
	var tree = get_tree()
	if tree == null:
		return
	
	await tree.create_timer(2.0).timeout
	
	# await后再次检查tree（可能在等待期间场景被切换了）
	tree = get_tree()
	if tree == null:
		return
	
	# 检查玩家是否死亡（如果死亡则不打开商店）
	var death_manager = tree.get_first_node_in_group("death_manager")
	if death_manager and death_manager.get("is_dead"):
		print("[WaveSystem Online] 玩家死亡，延迟打开商店")
		# 等待玩家复活
		if death_manager.has_signal("player_revived"):
			await death_manager.player_revived
		
		# 再次检查tree
		tree = get_tree()
		if tree == null:
			return
		
		print("[WaveSystem Online] 玩家已复活，继续打开商店")
	
	_change_state_local(WaveState.SHOP_OPEN)
	print("[WaveSystem Online] ========== 打开商店 ==========")
	
	# 暂停游戏
	tree.paused = true
	
	# 查找商店
	var shop = tree.get_first_node_in_group("upgrade_shop")
	if shop and shop.has_method("open_shop"):
		if shop.has_method("set_close_button_enabled"):
			shop.call("set_close_button_enabled", false)
		if shop.has_method("update_close_button_text"):
			shop.call("update_close_button_text", str(shop_countdown_seconds))

		# 连接商店关闭信号
		if shop.has_signal("shop_closed"):
			if not shop.shop_closed.is_connected(_on_shop_closed):
				shop.shop_closed.connect(_on_shop_closed)
		
		if death_manager:
			var player = death_manager.get("player")
			if player and player.visible:
				shop.open_shop()
		else:
			shop.open_shop()
	else:
		push_warning("[WaveSystem Online] 未找到商店，直接进入下一波")
		_on_shop_closed()

	if _is_network_server():
		_start_shop_countdown()

## 商店关闭回调
func _on_shop_closed() -> void:
	if current_state != WaveState.SHOP_OPEN:
		return
	
	if _shop_timer:
		_shop_timer.stop()
	print("[WaveSystem Online] ========== 商店关闭 ==========")
	
	# 恢复游戏
	var tree = get_tree()
	if tree and tree.paused:
		tree.paused = false
	
	_change_state_local(WaveState.IDLE)
	
	# 延迟开始下一波
	tree = get_tree()
	if tree == null:
		return
	
	await tree.create_timer(1.0).timeout
	
	# await后再次检查
	tree = get_tree()
	if tree == null:
		return
	
	if current_wave < wave_configs.size():
		start_next_wave()
	else:
		all_waves_completed.emit()


func _start_shop_countdown() -> void:
	if not _is_network_server():
		return
	if shop_countdown_seconds <= 0:
		_close_shop_due_to_timeout()
		return
	if _shop_timer == null:
		_shop_timer = Timer.new()
		_shop_timer.one_shot = true
		_shop_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_shop_timer)
		_shop_timer.timeout.connect(_on_shop_timer_timeout)
	_shop_timer.wait_time = float(shop_countdown_seconds)
	_shop_timer.start()
	_shop_remaining_seconds = shop_countdown_seconds
	_update_close_button_text(_shop_remaining_seconds)
	rpc("rpc_shop_countdown_started", shop_countdown_seconds)
	_start_countdown_tick()
	print("[WaveSystem Online] 倒计时启动 (总时长=%d 秒)" % shop_countdown_seconds)


func _on_shop_timer_timeout() -> void:
	if _is_network_server():
		print("[WaveSystem Online] 倒计时Timer到期, 调用关闭")
		_close_shop_due_to_timeout()


func _start_countdown_tick() -> void:
	if not _is_network_server():
		return
	if current_state != WaveState.SHOP_OPEN:
		print("[WaveSystem Online] 倒计时tick：当前状态非SHOP_OPEN，终止 tick")
		return
	_shop_remaining_seconds -= 1
	if _shop_remaining_seconds <= 0:
		_update_close_button_text(0)
		_close_shop_due_to_timeout()
		return
	_update_close_button_text(_shop_remaining_seconds)
	rpc("rpc_update_shop_countdown", _shop_remaining_seconds)
	get_tree().create_timer(1.0, true).timeout.connect(_start_countdown_tick)


func _close_shop_due_to_timeout() -> void:
	if current_state != WaveState.SHOP_OPEN:
		print("[WaveSystem Online] _close_shop_due_to_timeout：当前状态 %d，跳过" % current_state)
		return
	print("[WaveSystem Online] 商店倒计时结束，服务器关闭商店")
	_shop_remaining_seconds = 0
	_update_close_button_text(0)
	_close_shop_ui()
	rpc(&"rpc_force_close_shop")


@rpc("authority", "call_local")
func rpc_shop_countdown_started(seconds: int) -> void:
	print("[WaveSystem Online] 商店倒计时开始：%d 秒" % seconds)
	_update_close_button_text(seconds)


@rpc("authority", "call_local")
func rpc_force_close_shop() -> void:
	print("[WaveSystem Online] 接收服务器商店关闭指令（当前状态=%d）" % current_state)
	_close_shop_ui()


@rpc("authority", "call_local")
func rpc_update_shop_countdown(value: int) -> void:
	_update_close_button_text(value)


func _update_close_button_text(value: int) -> void:
	var shop = get_tree().get_first_node_in_group("upgrade_shop")
	if not shop:
		return
	if value <= 0:
		if shop.has_method("set_close_button_enabled"):
			shop.call("set_close_button_enabled", true)
		if shop.has_method("update_close_button_text"):
			shop.call("update_close_button_text", "关闭")
	else:
		if shop.has_method("set_close_button_enabled"):
			shop.call("set_close_button_enabled", false)
		if shop.has_method("update_close_button_text"):
			var text = "自动关闭 (%d 秒)" % value
			shop.call("update_close_button_text", text)


func _close_shop_ui() -> void:
	var shop = get_tree().get_first_node_in_group("upgrade_shop")
	if shop and shop.has_method("close_shop"):
		print("[WaveSystem Online] 调用 UpgradeShop.close_shop()")
		shop.call("close_shop")
	else:
		print("[WaveSystem Online] 未找到可关闭的 UpgradeShop")


func _broadcast_wave_start() -> void:
	if not _is_network_server():
		return
	var payload := {
		"current_wave": current_wave,
		"state": int(WaveState.SPAWNING),
		"total_enemies": total_enemies_this_wave,
		"spawned_enemies": spawned_enemies_this_wave,
		"killed_enemies": killed_enemies_this_wave
	}
	rpc("rpc_set_wave_start", payload)

func _broadcast_wave_status() -> void:
	if not _is_network_server():
		return
	var payload := {
		"current_wave": current_wave,
		"state": int(current_state),
		"total_enemies": total_enemies_this_wave,
		"spawned_enemies": spawned_enemies_this_wave,
		"killed_enemies": killed_enemies_this_wave
	}
	rpc("rpc_set_wave_status", payload)

func server_register_enemy_spawn(spawn_data: Dictionary) -> void:
	if not _is_network_server():
		return
	spawned_enemies_this_wave += 1
	if spawned_enemies_this_wave >= total_enemies_this_wave:
		_change_state_local(WaveState.FIGHTING)
		print("[WaveSystem Online] ========== 生成完毕，进入战斗 ==========")
		print("[WaveSystem Online] 场上敌人数：", active_enemies.size())
	_broadcast_wave_status()

func register_enemy_instance(enemy: Node) -> void:
	if not enemy:
		return
	active_enemies.append(enemy)
	if enemy.has_signal("enemy_killed"):
		if not enemy.enemy_killed.is_connected(_on_enemy_died):
			enemy.enemy_killed.connect(_on_enemy_died)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy))
	print("[WaveSystem Online] 敌人生成 | 当前存活：", active_enemies.size())

func broadcast_status_to_peer(peer_id: int) -> void:
	if not _is_network_server():
		return
	var payload := {
		"current_wave": current_wave,
		"state": int(current_state),
		"total_enemies": total_enemies_this_wave,
		"spawned_enemies": spawned_enemies_this_wave,
		"killed_enemies": killed_enemies_this_wave
	}
	rpc_id(peer_id, "rpc_set_wave_status", payload)

@rpc("authority", "call_local")
func rpc_set_wave_start(payload: Dictionary) -> void:
	_cleanup_wave_data(false)
	_apply_wave_status(payload)
	_change_state_local(WaveState.SPAWNING)

	if _is_network_server():
		var config = wave_configs[current_wave - 1]
		
		print("\n[WaveSystem Online] ========== 第 ", current_wave, " 波开始 ==========")
		print("[WaveSystem Online] 目标敌人数：", total_enemies_this_wave)
		
		# 请求生成器开始生成
		enemy_spawner.spawn_wave(config)

@rpc("authority", "call_local")
func rpc_set_wave_status(payload: Dictionary) -> void:
	_apply_wave_status(payload)

func _apply_wave_status(payload: Dictionary) -> void:
	var previous_wave := current_wave
	if payload.has("current_wave"):
		current_wave = int(payload["current_wave"])
	if payload.has("state"):
		var state_val := int(payload["state"])
		if state_val >= 0 and state_val < WaveState.size():
			_change_state_local(WaveState.values()[state_val])
	if payload.has("total_enemies"):
		total_enemies_this_wave = int(payload["total_enemies"])
	if payload.has("spawned_enemies"):
		spawned_enemies_this_wave = int(payload["spawned_enemies"])
	if payload.has("killed_enemies"):
		killed_enemies_this_wave = int(payload["killed_enemies"])
	if current_wave != previous_wave:
		wave_started.emit(current_wave)
	enemy_killed.emit(current_wave, killed_enemies_this_wave, total_enemies_this_wave)

## 清理波次数据
func _cleanup_wave_data(reset_counts: bool = true) -> void:
	# 清理上一波的敌人引用
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			# 断开信号连接
			if enemy.has_signal("enemy_killed") and enemy.enemy_killed.is_connected(_on_enemy_died):
				enemy.enemy_killed.disconnect(_on_enemy_died)
			if enemy.tree_exiting.is_connected(_on_enemy_removed):
				enemy.tree_exiting.disconnect(_on_enemy_removed)
	
	active_enemies.clear()
	if reset_counts:
		spawned_enemies_this_wave = 0
		total_enemies_this_wave = 0
		killed_enemies_this_wave = 0
		_broadcast_wave_status()

## 改变状态
func _change_state_local(new_state: WaveState) -> void:
	if current_state == new_state:
		return
	
	var state_names = ["IDLE", "SPAWNING", "FIGHTING", "WAVE_COMPLETE", "SHOP_OPEN"]
	print("[WaveSystem Online] 状态变化：", state_names[current_state], " -> ", state_names[new_state])
	
	current_state = new_state
	state_changed.emit(new_state)
	if new_state == WaveState.WAVE_COMPLETE:
		wave_completed.emit(current_wave)
	if new_state == WaveState.SPAWNING:
		wave_started.emit(current_wave)

## 获取当前波次配置
func get_current_wave_config() -> Dictionary:
	if current_wave == 0 or current_wave > wave_configs.size():
		return {}
	return wave_configs[current_wave - 1]

## 获取状态信息（用于调试）
func get_status_info() -> Dictionary:
	return {
		"wave": current_wave,
		"state": current_state,
		"total_enemies": total_enemies_this_wave,
		"spawned": spawned_enemies_this_wave,
		"active": active_enemies.size(),
		"active_valid": _count_valid_enemies()
	}

## 统计有效的敌人数量
func _count_valid_enemies() -> int:
	var count = 0
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count

## 强制结束当前波（调试用）
func force_end_wave() -> void:
	print("[WaveSystem Online] 强制结束当前波")
	active_enemies.clear()
	_check_wave_complete()
