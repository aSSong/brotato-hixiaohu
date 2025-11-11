extends Node
class_name WaveSystemV3

## 新的波次系统 V3
## 设计原则：
## 1. 直接追踪敌人实例，不依赖计数
## 2. 清晰的状态机
## 3. 信号驱动的通信

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

func _ready() -> void:
	_initialize_waves()

## Multi模式：处理墓碑刷新
func _handle_multi_mode_graves() -> void:
	# 检查是否是multi模式
	if GameMain.current_mode_id != "multi":
		return
	
	# 查找MultiGravesManager
	var graves_manager = get_tree().get_first_node_in_group("multi_graves_manager")
	if not graves_manager:
		print("[WaveSystem V3] Multi模式但未找到MultiGravesManager")
		return
	
	# 刷新当前wave的墓碑
	if graves_manager.has_method("spawn_graves_for_wave"):
		graves_manager.spawn_graves_for_wave(current_wave)
		print("[WaveSystem V3] Multi模式 - 已刷新Wave%d的墓碑" % current_wave)
	else:
		push_warning("[WaveSystem V3] MultiGravesManager没有spawn_graves_for_wave方法")

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
		var normal_enemy_count = 9 + (wave * 2)
		
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
	
	print("[WaveSystem V3] 初始化完成：", wave_configs.size(), "波")
	print("[WaveSystem V3] 第1波配置：", wave_configs[0])
	print("[WaveSystem V3] 第10波配置：", wave_configs[9])

## 设置敌人生成器
func set_enemy_spawner(spawner: Node) -> void:
	enemy_spawner = spawner
	print("[WaveSystem V3] 设置生成器：", spawner.name)

## 开始游戏（第一波）
func start_game() -> void:
	if current_state != WaveState.IDLE:
		push_warning("[WaveSystem V3] 游戏已经开始，忽略")
		return
	
	print("[WaveSystem V3] 开始游戏")
	start_next_wave()

## 开始下一波
func start_next_wave() -> void:
	# 状态检查
	if current_state == WaveState.SPAWNING or current_state == WaveState.FIGHTING:
		push_warning("[WaveSystem V3] 波次进行中，不能开始新波次")
		return
	
	if current_state == WaveState.SHOP_OPEN:
		push_warning("[WaveSystem V3] 商店开启中，不能开始新波次")
		return
	
	# 检查玩家是否死亡
	var tree = get_tree()
	if tree == null:
		return
	
	var death_manager = tree.get_first_node_in_group("death_manager")
	if death_manager and death_manager.get("is_dead"):
		print("[WaveSystem V3] 玩家死亡，暂停开始新波次")
		# 等待玩家复活
		if death_manager.has_signal("player_revived"):
			await death_manager.player_revived
		
		# await后重新检查tree
		tree = get_tree()
		if tree == null:
			return
		
		print("[WaveSystem V3] 玩家已复活，继续开始新波次")
	
	# 检查是否还有波次
	if current_wave >= wave_configs.size():
		_change_state(WaveState.IDLE)
		all_waves_completed.emit()
		print("[WaveSystem V3] ===== 所有波次完成！=====")
		return
	
	# 清理上一波的数据
	_cleanup_wave_data()
	
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
	
	_change_state(WaveState.SPAWNING)
	wave_started.emit(current_wave)
	
	print("\n[WaveSystem V3] ========== 第 ", current_wave, " 波开始 ==========")
	print("[WaveSystem V3] 目标敌人数：", total_enemies_this_wave)
	
	# Multi模式：刷新墓碑
	_handle_multi_mode_graves()
	
	# 请求生成器开始生成
	if enemy_spawner and enemy_spawner.has_method("spawn_wave"):
		enemy_spawner.spawn_wave(config)
	else:
		push_error("[WaveSystem V3] 敌人生成器未设置或没有spawn_wave方法")

## 敌人生成成功的回调（由生成器调用）
func on_enemy_spawned(enemy: Node) -> void:
	if current_state != WaveState.SPAWNING:
		push_warning("[WaveSystem V3] 不在生成状态，忽略敌人生成")
		return
	
	spawned_enemies_this_wave += 1
	active_enemies.append(enemy)
	
	# 连接敌人死亡信号
	if enemy.has_signal("enemy_killed"):
		if not enemy.enemy_killed.is_connected(_on_enemy_died):
			enemy.enemy_killed.connect(_on_enemy_died)
	
	# 监听敌人被移除（queue_free）
	if not enemy.tree_exiting.is_connected(_on_enemy_removed):
		enemy.tree_exiting.connect(_on_enemy_removed.bind(enemy))
	
	print("[WaveSystem V3] 敌人生成：", spawned_enemies_this_wave, "/", total_enemies_this_wave, 
		  " | 存活：", active_enemies.size())
	
	# 检查是否生成完毕
	if spawned_enemies_this_wave >= total_enemies_this_wave:
		_on_spawn_complete()

## 生成完毕
func _on_spawn_complete() -> void:
	if current_state != WaveState.SPAWNING:
		return
	
	_change_state(WaveState.FIGHTING)
	print("[WaveSystem V3] ========== 生成完毕，进入战斗 ==========")
	print("[WaveSystem V3] 场上敌人数：", active_enemies.size())

## 敌人死亡回调
func _on_enemy_died(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 敌人被移除（queue_free）
func _on_enemy_removed(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 从追踪列表中移除敌人
func _remove_enemy(enemy_ref: Node) -> void:
	if not is_instance_valid(enemy_ref):
		return
	
	var index = active_enemies.find(enemy_ref)
	if index != -1:
		active_enemies.remove_at(index)
		killed_enemies_this_wave += 1  # 增加击杀计数
		
		print("[WaveSystem V3] 敌人移除 | 击杀：", killed_enemies_this_wave, " 剩余：", active_enemies.size(), "/", total_enemies_this_wave)
		
		# 发出击杀信号（供UI等监听）
		enemy_killed.emit(current_wave, killed_enemies_this_wave, total_enemies_this_wave)
		
		# 检查是否波次完成
		_check_wave_complete()

## 检查波次是否完成
func _check_wave_complete() -> void:
	# 只在战斗状态检查
	if current_state != WaveState.FIGHTING:
		return
	
	# 清理无效引用
	_cleanup_invalid_enemies()
	
	# 检查是否所有敌人都被清除
	if active_enemies.is_empty():
		print("[WaveSystem V3] ========== 第 ", current_wave, " 波完成！==========")
		print("[WaveSystem V3] 已生成：", spawned_enemies_this_wave, " 目标：", total_enemies_this_wave)
		_change_state(WaveState.WAVE_COMPLETE)
		wave_completed.emit(current_wave)
		
		# 显示商店
		call_deferred("_show_shop")

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
	
	# 延迟2秒再打开商店
	print("[WaveSystem V3] 波次完成，2秒后打开商店...")
	
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
		print("[WaveSystem V3] 玩家死亡，延迟打开商店")
		# 等待玩家复活
		if death_manager.has_signal("player_revived"):
			await death_manager.player_revived
		
		# 再次检查tree
		tree = get_tree()
		if tree == null:
			return
		
		print("[WaveSystem V3] 玩家已复活，继续打开商店")
	
	_change_state(WaveState.SHOP_OPEN)
	print("[WaveSystem V3] ========== 打开商店 ==========")
	
	# 暂停游戏
	tree.paused = true
	
	# 查找商店
	var shop = tree.get_first_node_in_group("upgrade_shop")
	if shop and shop.has_method("open_shop"):
		# 连接商店关闭信号
		if shop.has_signal("shop_closed"):
			if not shop.shop_closed.is_connected(_on_shop_closed):
				shop.shop_closed.connect(_on_shop_closed)
		
		shop.open_shop()
	else:
		push_warning("[WaveSystem V3] 未找到商店，直接进入下一波")
		_on_shop_closed()

## 商店关闭回调
func _on_shop_closed() -> void:
	if current_state != WaveState.SHOP_OPEN:
		return
	
	print("[WaveSystem V3] ========== 商店关闭 ==========")
	
	# 恢复游戏
	var tree = get_tree()
	if tree and tree.paused:
		tree.paused = false
	
	_change_state(WaveState.IDLE)
	
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

## 清理波次数据
func _cleanup_wave_data() -> void:
	# 清理上一波的敌人引用
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			# 断开信号连接
			if enemy.has_signal("enemy_killed") and enemy.enemy_killed.is_connected(_on_enemy_died):
				enemy.enemy_killed.disconnect(_on_enemy_died)
			if enemy.tree_exiting.is_connected(_on_enemy_removed):
				enemy.tree_exiting.disconnect(_on_enemy_removed)
	
	active_enemies.clear()
	spawned_enemies_this_wave = 0
	total_enemies_this_wave = 0

## 改变状态
func _change_state(new_state: WaveState) -> void:
	if current_state == new_state:
		return
	
	var state_names = ["IDLE", "SPAWNING", "FIGHTING", "WAVE_COMPLETE", "SHOP_OPEN"]
	print("[WaveSystem V3] 状态变化：", state_names[current_state], " -> ", state_names[new_state])
	
	current_state = new_state
	state_changed.emit(new_state)

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
	print("[WaveSystem V3] 强制结束当前波")
	active_enemies.clear()
	_check_wave_complete()
