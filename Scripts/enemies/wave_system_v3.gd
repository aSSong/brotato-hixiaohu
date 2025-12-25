extends Node
class_name WaveSystemV3

## 新的波次系统 V3 - Phase优化版
## 设计原则：
## 1. 直接追踪敌人实例，不依赖计数
## 2. 清晰的状态机
## 3. 信号驱动的通信
## 4. 支持多阶段(Phase)刷怪
## 5. 支持min/max活跃怪物数量控制

## ========== 状态定义 ==========
enum WaveState {
	IDLE,           # 空闲，等待开始
	SPAWNING,       # 正在生成敌人
	FIGHTING,       # 战斗中（生成完毕，等待击杀）
	WAVE_COMPLETE,  # 本波完成，准备显示商店
	SHOP_OPEN,      # 商店开启中
}

## ========== 配置 ==========
const DEFAULT_MIN_ALIVE_ENEMIES: int = 3    # 默认场上最少活跃怪物数
const DEFAULT_MAX_ALIVE_ENEMIES: int = 100  # 默认场上最大活跃怪物数

var wave_configs: Array = []  # 波次配置
var current_wave: int = 0
var current_state: WaveState = WaveState.IDLE
var wave_config_id: String = "default"  # 当前使用的配置ID

## ========== 敌人追踪 ==========
var active_enemies: Array = []  # 当前存活的敌人实例列表（直接引用）
var total_enemies_this_wave: int = 0
var spawned_enemies_this_wave: int = 0
var killed_enemies_this_wave: int = 0  # 用于统计击杀数
var failed_spawns_this_wave: int = 0  # 生成失败次数（用于止血：避免SPAWNING卡死）

## ========== Phase追踪 ==========
var current_phase_index: int = 0           # 当前phase索引
var phase_spawned_count: int = 0           # 当前phase已刷怪数量
var global_spawn_index: int = 0            # 整个wave的累计刷怪序号(用于special_spawns)
var current_phase_enemy_list: Array = []   # 当前phase的待刷怪列表
var all_phases_complete: bool = false      # 是否所有phase都刷完了

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
signal enemy_spawned(enemy: Enemy)  # 敌人生成信号（用于 BOSS 血条等）

## ========== 引用 ==========
var enemy_spawner: Node = null  # 敌人生成器

func _ready() -> void:
	# 添加到 wave_manager 组，以便其他系统能找到（兼容性）
	if not is_in_group("wave_manager"):
		add_to_group("wave_manager")
	if not is_in_group("wave_system"):
		add_to_group("wave_system")
	
	print("[WaveSystem V3] 已添加到组: wave_manager, wave_system")
	
	# 保护：避免同时存在旧 WaveManager 和 V3 导致 get_first_node_in_group("wave_manager") 随机取错
	_ensure_single_wave_manager_in_group()
	
	# 从当前模式获取配置ID（如果有）
	var mode_id = GameMain.current_mode_id
	if mode_id and not mode_id.is_empty():
		var mode = ModeRegistry.get_mode(mode_id)
		if mode and "wave_config_id" in mode:
			wave_config_id = mode.wave_config_id
			print("[WaveSystem V3] 从模式获取配置ID: ", wave_config_id, " (模式: ", mode_id, ")")
		else:
			print("[WaveSystem V3] 模式 ", mode_id, " 没有 wave_config_id，使用默认配置")
	else:
		print("[WaveSystem V3] 未设置模式ID，使用默认配置: ", wave_config_id)
	
	_initialize_waves()

## 保护：确保 wave_manager 组里不会混入旧的 WaveManager（否则外部查找可能拿错）
func _ensure_single_wave_manager_in_group() -> void:
	var tree = get_tree()
	if tree == null:
		return
	
	var nodes = tree.get_nodes_in_group("wave_manager")
	if nodes.size() <= 1:
		return
	
	var others: Array = []
	for n in nodes:
		if n != self and is_instance_valid(n):
			others.append(n)
	
	if others.is_empty():
		return
	
	var info := []
	for n in others:
		info.append("%s(%s)" % [str(n.get_path()), str(n.get_class())])
	push_warning("[WaveSystem V3] 检测到 wave_manager 组中存在多个节点，可能导致随机取错：%s" % ", ".join(info))
	
	# 仅移除“旧 WaveManager”脚本实例（尽量不影响其它系统）
	for n in others:
		if n is WaveManager:
			n.remove_from_group("wave_manager")
			push_warning("[WaveSystem V3] 已将旧 WaveManager 从 wave_manager 组移除：%s" % str(n.get_path()))

## Multi模式：处理墓碑刷新
func _handle_multi_mode_graves() -> void:
	# 检查是否是multi模式
	if GameMain.current_mode_id != "multi":
		return
	
	# 安全检查
	var tree = get_tree()
	if tree == null:
		return
	
	# 查找MultiGravesManager
	var graves_manager = tree.get_first_node_in_group("multi_graves_manager")
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

## 转换波次配置（从JSON格式到内部格式）- 支持新的Phase格式
func _convert_wave_config(wave_data: Dictionary) -> Dictionary:
	var config = {
		"wave_number": wave_data.wave,
	}
	
	# 检测是否是新格式（有spawn_phases）
	if wave_data.has("spawn_phases"):
		# 新格式：多阶段刷怪
		var base_config = wave_data.get("base_config", {})
		config["hp_growth"] = base_config.get("hp_growth", 0.0)
		config["damage_growth"] = base_config.get("damage_growth", 0.0)
		config["min_alive_enemies"] = base_config.get("min_alive_enemies", DEFAULT_MIN_ALIVE_ENEMIES)
		config["max_alive_enemies"] = base_config.get("max_alive_enemies", DEFAULT_MAX_ALIVE_ENEMIES)
		
		# 转换spawn_phases
		var phases = []
		for phase_data in wave_data.spawn_phases:
			# JSON 可能带来 float/string 等非预期类型，这里统一做健壮化转换
			var spawn_per_time = int(phase_data.get("spawn_per_time", 1))
			if spawn_per_time <= 0:
				spawn_per_time = 1
			
			var spawn_interval = float(phase_data.get("spawn_interval", 2.0))
			if spawn_interval < 0.0:
				spawn_interval = 0.0
			
			var total_count = int(phase_data.get("total_count", 10))
			if total_count < 0:
				total_count = 0
			
			var enemy_types_raw = phase_data.get("enemy_types", {"creeper": 1.0})
			var enemy_types: Dictionary = enemy_types_raw if (enemy_types_raw is Dictionary) else {"creeper": 1.0}
			if enemy_types.is_empty():
				enemy_types = {"creeper": 1.0}
			
			var phase = {
				"spawn_per_time": spawn_per_time,
				"spawn_interval": spawn_interval,
				"total_count": total_count,
				"enemy_types": enemy_types
			}
			phases.append(phase)
		config["spawn_phases"] = phases
		
		# 计算总敌人数
		var total: int = 0
		for phase in phases:
			total += int(phase.total_count)
		
		# 处理BOSS配置（独立字段，在所有phase刷完后立即刷新）
		var boss_cfg = wave_data.get("boss_config", {})
		var boss_count: int = int(boss_cfg.get("count", 0))
		if boss_count < 0:
			boss_count = 0
		var boss_id = boss_cfg.get("enemy_id", "")
		config["boss_config"] = {
			"count": boss_count,
			"enemy_id": boss_id
		}
		total += boss_count
		
		config["total_enemies"] = total
		
		# special_spawns保持不变
		if wave_data.has("special_spawns"):
			config["special_spawns"] = wave_data.special_spawns
		
		config["is_phase_format"] = true
	else:
		# 旧格式：兼容处理，转换为单phase格式
		config["hp_growth"] = wave_data.get("hp_growth", 0.0)
		config["damage_growth"] = wave_data.get("damage_growth", 0.0)
		config["min_alive_enemies"] = DEFAULT_MIN_ALIVE_ENEMIES
		config["max_alive_enemies"] = DEFAULT_MAX_ALIVE_ENEMIES
		
		# 处理敌人配比
		var total_count = wave_data.get("total_count", 10)
		var enemy_ratios = wave_data.get("enemies", {})
		var spawn_interval = wave_data.get("spawn_interval", 0.4)
		
		# 转换为单phase
		var phase = {
			"spawn_per_time": 1,
			"spawn_interval": spawn_interval,
			"total_count": total_count,
			"enemy_types": enemy_ratios
		}
		config["spawn_phases"] = [phase]
		
		# 处理BOSS配置 - 作为额外的phase
		var boss_config = wave_data.get("boss_config", {})
		var boss_count = boss_config.get("count", 1)
		var boss_id = boss_config.get("enemy_id", "last_enemy")
		if boss_count > 0:
			var boss_phase = {
				"spawn_per_time": 1,
				"spawn_interval": spawn_interval,
				"total_count": boss_count,
				"enemy_types": {boss_id: 1.0}
			}
			config["spawn_phases"].append(boss_phase)
		
		# 计算总敌人数
		config["total_enemies"] = total_count + boss_count
		
		# special_spawns保持不变
		if wave_data.has("special_spawns"):
			config["special_spawns"] = wave_data.special_spawns
		
		config["is_phase_format"] = false
	
	return config

## 创建后备配置（当JSON加载失败时）
func _create_fallback_config() -> void:
	for wave in range(20):
		var wave_number = wave + 1
		var config = {
			"wave_number": wave_number,
			"hp_growth": wave * 0.05,
			"damage_growth": wave * 0.05,
			"min_alive_enemies": 3,
			"max_alive_enemies": 15,
			"spawn_phases": [
				{
					"spawn_per_time": 2,
					"spawn_interval": 2.0,
					"total_count": 10 + wave * 2,
					"enemy_types": {
						"creeper": 0.6,
						"creeper_fast": 0.3,
						"jug2": 0.1
					}
				}
			],
			"total_enemies": 10 + wave * 2,
			"is_phase_format": true
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
	
	# 同步更新GameMain.current_session.current_wave
	if GameMain.current_session:
		GameMain.current_session.current_wave = current_wave
	
	# 设置总敌人数
	total_enemies_this_wave = config.get("total_enemies", 0)
	spawned_enemies_this_wave = 0
	killed_enemies_this_wave = 0
	failed_spawns_this_wave = 0
	
	# 重置Phase状态
	current_phase_index = 0
	phase_spawned_count = 0
	global_spawn_index = 0
	current_phase_enemy_list.clear()
	all_phases_complete = false
	
	_change_state(WaveState.SPAWNING)
	wave_started.emit(current_wave)
	
	print("\n[WaveSystem V3] ========== 第 ", current_wave, " 波开始 ==========")
	print("[WaveSystem V3] 目标敌人数：", total_enemies_this_wave)
	print("[WaveSystem V3] HP成长率：", config.get("hp_growth", 0.0) * 100, "%")
	print("[WaveSystem V3] 伤害成长率：", config.get("damage_growth", 0.0) * 100, "%")
	print("[WaveSystem V3] Phase数量：", config.spawn_phases.size())
	print("[WaveSystem V3] min/max活跃：", config.get("min_alive_enemies", 3), "/", config.get("max_alive_enemies", 15))
	
	# Multi模式：刷新墓碑
	_handle_multi_mode_graves()
	
	# 延迟刷怪（给玩家2秒准备时间）
	print("[WaveSystem V3] 延迟2秒开始刷怪...")
	var timer_tree = get_tree()
	if timer_tree:
		# 暂停（死亡UI等）期间应完全停止刷怪推进
		await timer_tree.create_timer(2.0, false).timeout
	
	# 再次检查状态，确保没有在等待期间发生变化（如游戏结束）
	if current_state != WaveState.SPAWNING:
		print("[WaveSystem V3] 状态已变更，取消刷怪")
		return
	
	# 开始Phase刷怪流程
	if enemy_spawner and enemy_spawner.has_method("spawn_wave_phases"):
		enemy_spawner.spawn_wave_phases(config, self)
	else:
		push_error("[WaveSystem V3] 敌人生成器未设置或没有spawn_wave_phases方法")

## 敌人生成成功的回调（由生成器调用）
func on_enemy_spawned(enemy: Node) -> void:
	if current_state != WaveState.SPAWNING and current_state != WaveState.FIGHTING:
		push_warning("[WaveSystem V3] 不在生成/战斗状态，忽略敌人生成")
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
	
	# 发射敌人生成信号（用于 BOSS 血条等 UI）
	if enemy is Enemy:
		enemy_spawned.emit(enemy as Enemy)

## 敌人生成失败的回调（由生成器调用；失败也算一次生成尝试）
func on_enemy_spawn_failed(enemy_id: String = "") -> void:
	if current_state != WaveState.SPAWNING and current_state != WaveState.FIGHTING:
		return
	
	spawned_enemies_this_wave += 1
	failed_spawns_this_wave += 1
	
	# 失败视为"已击杀"（否则UI和流程可能卡死）
	killed_enemies_this_wave += 1
	enemy_killed.emit(current_wave, killed_enemies_this_wave, total_enemies_this_wave)
	
	push_warning("[WaveSystem V3] 敌人生成失败计入进度：%s (%d/%d)" % [enemy_id, spawned_enemies_this_wave, total_enemies_this_wave])

## 所有Phase刷怪完成的回调（由生成器调用）
func on_all_phases_complete() -> void:
	all_phases_complete = true
	print("[WaveSystem V3] ========== 所有Phase刷怪完成 ==========")
	
	# 转换到战斗状态
	if current_state == WaveState.SPAWNING:
		_change_state(WaveState.FIGHTING)
	
	# 检查是否波次完成（场上可能已经没有敌人了）
	_check_wave_complete()

## 获取当前活跃敌人数量
func get_active_enemy_count() -> int:
	_cleanup_invalid_enemies()
	return active_enemies.size()

## 敌人死亡回调
func _on_enemy_died(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 敌人被移除（queue_free）
func _on_enemy_removed(enemy_ref: Node) -> void:
	_remove_enemy(enemy_ref)

## 从追踪列表中移除敌人
func _remove_enemy(enemy_ref: Node) -> void:
	# 安全检查：确保节点仍在树中
	if not is_inside_tree():
		return
	
	if not is_instance_valid(enemy_ref):
		return
	
	var index = active_enemies.find(enemy_ref)
	if index != -1:
		active_enemies.remove_at(index)
		killed_enemies_this_wave += 1  # 增加击杀计数
		
		# 发出击杀信号（供UI等监听）
		enemy_killed.emit(current_wave, killed_enemies_this_wave, total_enemies_this_wave)
		
		# 检查是否波次完成
		_check_wave_complete()

## 检查波次是否完成
func _check_wave_complete() -> void:
	# 安全检查：确保节点仍在树中
	if not is_inside_tree():
		return
	
	# 只在战斗状态且所有phase都刷完的情况下检查
	if current_state != WaveState.FIGHTING:
		return
	
	if not all_phases_complete:
		return
	
	# 清理无效引用
	_cleanup_invalid_enemies()
	
	# 检查是否所有敌人都被清除
	if active_enemies.is_empty():
		print("[WaveSystem V3] ========== 第 ", current_wave, " 波完成！==========")
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
	killed_enemies_this_wave = 0
	failed_spawns_this_wave = 0
	
	# 重置Phase状态
	current_phase_index = 0
	phase_spawned_count = 0
	global_spawn_index = 0
	current_phase_enemy_list.clear()
	all_phases_complete = false

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
		"active_valid": _count_valid_enemies(),
		"current_phase": current_phase_index,
		"all_phases_complete": all_phases_complete
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
	all_phases_complete = true
	active_enemies.clear()
	_check_wave_complete()
