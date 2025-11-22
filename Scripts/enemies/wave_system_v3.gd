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
var wave_config_id: String = "default"  # 当前使用的配置ID

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

## 兼容旧系统：is_wave_in_progress
var is_wave_in_progress: bool:
	get:
		return current_state == WaveState.SPAWNING or current_state == WaveState.FIGHTING

## ========== 信号 ==========
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_ended(wave_number: int)  # 兼容旧系统（与wave_completed相同）
signal all_waves_completed()
signal state_changed(new_state: WaveState)
signal enemy_killed(wave_number: int, killed: int, total: int)  # 兼容UI

## ========== 引用 ==========
var enemy_spawner: Node = null  # 敌人生成器

func _ready() -> void:
	# 添加到 wave_manager 组，以便其他系统能找到（兼容性）
	if not is_in_group("wave_manager"):
		add_to_group("wave_manager")
	if not is_in_group("wave_system"):
		add_to_group("wave_system")
	
	print("[WaveSystem V3] 已添加到组: wave_manager, wave_system")
	
	# 从当前模式获取配置ID（如果有）
	if GameMain.current_session and "mode" in GameMain.current_session:
		var mode = GameMain.current_session.mode
		if mode and "wave_config_id" in mode:
			wave_config_id = mode.wave_config_id
			print("[WaveSystem V3] 从模式获取配置ID: ", wave_config_id)
	
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
	# 从JSON加载配置
	load_wave_config(wave_config_id)

## 加载波次配置
func load_wave_config(config_id: String) -> void:
	wave_config_id = config_id
	wave_configs.clear()
	
	print("[WaveSystem V3] 开始加载波次配置: ", config_id)
	
	# 使用WaveConfigLoader加载配置
	var config_data = WaveConfigLoader.load_config(config_id)
	
	if config_data.is_empty():
		push_error("[WaveSystem V3] 配置加载失败，使用默认配置")
		_create_fallback_config()
		return
	
	# 转换JSON配置为内部格式
	for wave_data in config_data.waves:
		var wave_config = _convert_wave_config(wave_data)
		wave_configs.append(wave_config)
	
	print("[WaveSystem V3] 配置加载完成：", wave_configs.size(), " 波")
	if wave_configs.size() > 0:
		print("[WaveSystem V3] 第1波配置：", wave_configs[0])
	if wave_configs.size() >= 10:
		print("[WaveSystem V3] 第10波配置：", wave_configs[9])

## 转换波次配置（从JSON格式到内部格式）
func _convert_wave_config(wave_data: Dictionary) -> Dictionary:
	var config = {
		"wave_number": wave_data.wave,
		"spawn_interval": wave_data.get("spawn_interval", 0.4),
		"hp_growth": wave_data.get("hp_growth", 0.0),
		"damage_growth": wave_data.get("damage_growth", 0.0),
		"enemies": [],
		"last_enemy": {}
	}
	
	# 处理敌人配比
	var total_count = wave_data.get("total_count", 10)
	var enemy_ratios = wave_data.get("enemies", {})
	
	# 收集所有敌人类型及其数量
	var enemy_list = []
	for enemy_id in enemy_ratios:
		var ratio = enemy_ratios[enemy_id]
		var count = int(total_count * ratio)
		if count > 0:
			enemy_list.append({"id": enemy_id, "count": count})
	
	# 处理BOSS配置
	var boss_config = wave_data.get("boss_config", {})
	var boss_count = boss_config.get("count", 1)
	var boss_id = boss_config.get("enemy_id", "last_enemy")
	var boss_at_end = boss_config.get("spawn_at_end", true)
	
	# 处理special_spawns（特殊刷怪位置）
	var special_spawns = wave_data.get("special_spawns", [])
	
	# 如果有特殊刷怪配置，需要特殊处理
	if special_spawns.size() > 0:
		config["special_spawns"] = special_spawns
	
	# 如果BOSS在最后刷出
	if boss_at_end:
		config["enemies"] = enemy_list
		config["last_enemy"] = {"id": boss_id, "count": boss_count}
	else:
		# BOSS不在最后，需要根据special_spawns处理
		config["enemies"] = enemy_list
		config["last_enemy"] = {"id": boss_id, "count": 0}  # 标记为0，实际通过special_spawns刷出
	
	return config

## 创建后备配置（当JSON加载失败时）
func _create_fallback_config() -> void:
	for wave in range(20):
		var wave_number = wave + 1
		var config = {
			"wave_number": wave_number,
			"spawn_interval": 0.4,
			"hp_growth": wave * 0.05,
			"damage_growth": wave * 0.05,
			"enemies": [
				{"id": "basic", "count": 5},
				{"id": "fast", "count": 2},
				{"id": "tank", "count": 2},
			],
			"last_enemy": {"id": "last_enemy", "count": 1}
		}
		wave_configs.append(config)
	print("[WaveSystem V3] 使用后备配置：", wave_configs.size(), " 波")

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
	
	# 如果有special_spawns，也需要计算进去
	if config.has("special_spawns"):
		total_enemies_this_wave += config.special_spawns.size()
	
	spawned_enemies_this_wave = 0
	killed_enemies_this_wave = 0  # 重置击杀计数
	
	_change_state(WaveState.SPAWNING)
	wave_started.emit(current_wave)
	
	print("\n[WaveSystem V3] ========== 第 ", current_wave, " 波开始 ==========")
	print("[WaveSystem V3] 目标敌人数：", total_enemies_this_wave)
	print("[WaveSystem V3] HP成长率：", config.get("hp_growth", 0.0) * 100, "%")
	print("[WaveSystem V3] 伤害成长率：", config.get("damage_growth", 0.0) * 100, "%")
	print("[WaveSystem V3] 刷新间隔：", config.get("spawn_interval", 0.4), " 秒")
	
	# Multi模式：刷新墓碑
	_handle_multi_mode_graves()
	
	# 延迟刷怪（给玩家2秒准备时间）
	print("[WaveSystem V3] 延迟2秒开始刷怪...")
	var timer_tree = get_tree()
	if timer_tree:
		await timer_tree.create_timer(2.0).timeout
	
	# 再次检查状态，确保没有在等待期间发生变化（如游戏结束）
	if current_state != WaveState.SPAWNING:
		print("[WaveSystem V3] 状态已变更，取消刷怪")
		return
	
	# 请求生成器开始生成（传递完整配置）
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
	
	#print("[WaveSystem V3] 敌人生成：", spawned_enemies_this_wave, "/", total_enemies_this_wave, 
		  #" | 存活：", active_enemies.size())
	
	# 检查是否生成完毕
	if spawned_enemies_this_wave >= total_enemies_this_wave:
		_on_spawn_complete()

## 生成完毕
func _on_spawn_complete() -> void:
	if current_state != WaveState.SPAWNING:
		return
	
	_change_state(WaveState.FIGHTING)
	print("[WaveSystem V3] ========== 生成完毕，进入战斗 ==========")
	#print("[WaveSystem V3] 场上敌人数：", active_enemies.size())

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
		
		#print("[WaveSystem V3] 敌人移除 | 击杀：", killed_enemies_this_wave, " 剩余：", active_enemies.size(), "/", total_enemies_this_wave)
		
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
		#print("[WaveSystem V3] 已生成：", spawned_enemies_this_wave, " 目标：", total_enemies_this_wave)
		_change_state(WaveState.WAVE_COMPLETE)
		wave_completed.emit(current_wave)
		wave_ended.emit(current_wave)  # 兼容旧系统


## 清理无效的敌人引用
func _cleanup_invalid_enemies() -> void:
	var valid_enemies = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

## 显示商店
func _show_shop() -> void:
	# 逻辑已移交至 GameInitializer，不再由此处直接控制
	pass

## 商店关闭回调
func _on_shop_closed() -> void:
	# 逻辑已移交至 GameInitializer，不再由此处直接控制
	pass

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
