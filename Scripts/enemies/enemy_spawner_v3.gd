extends Node2D
class_name EnemySpawnerV3

## 新的敌人生成器 V3 - Phase优化版
## 职责：负责生成敌人，支持多阶段刷怪和批量生成
## 
## 改进：
## 1. 使用预制场景系统，从 EnemyData.scene_path 加载敌人场景
## 2. 支持多阶段(Phase)刷怪
## 3. 支持批量刷怪(spawn_per_time)
## 4. 支持min/max活跃怪物数量控制

## ========== 配置 ==========
## 默认敌人场景（兜底用，当 scene_path 为空时使用）
@export var fallback_enemy_scene: PackedScene

## 刷新预警图片
var spawn_indicator_texture: Texture2D = preload("res://assets/others/enemy_spawn_indicator_01.png")

var floor_layer: TileMapLayer = null
var player: Node = null
var wave_system: WaveSystemV3 = null

## ========== 性能优化：缓存 floor_layer.get_used_cells() ==========
## 地图通常不变，反复 get_used_cells() 会产生大量分配；这里缓存一次并复用
var _cached_used_cells: Array[Vector2i] = []
var _used_cells_cache_valid: bool = false

## 调试输出开关（默认关闭，避免后期刷屏导致卡顿）
const DEBUG_LOG: bool = false
func _dprint(msg) -> void:
	if DEBUG_LOG and OS.is_debug_build():
		print(msg)

## ========== 场景缓存 ==========
## 缓存已加载的敌人场景，避免重复加载
var scene_cache: Dictionary = {}

## ========== 预警配置 ==========
var spawn_indicator_delay: float = 0.5  # 默认预警延迟，会从模式配置覆盖

## ========== 生成参数 ==========
## 刷怪距离范围（相对于玩家）
const SPAWN_MIN_DISTANCE: float = 500.0   # 最小距离：敌人不会在玩家 500 像素内刷新
const SPAWN_MAX_DISTANCE: float = 1200.0  # 最大距离：敌人不会在玩家 1200 像素外刷新

## 生成瞬间二次安全距离：
## 预警期间玩家可能冲到刷新点附近；若生成瞬间距离过近（Boss与special_spawns除外）则直接跳过该怪并计入已刷+已杀。
const SPAWN_CANCEL_DISTANCE_NEAR_PLAYER: float = 100.0

var max_spawn_attempts: int = 30

## ========== 状态 ==========
var is_spawning: bool = false

## ========== Phase刷怪状态 ==========
var current_wave_config: Dictionary = {}
var current_phase_index: int = 0
var global_spawn_index: int = 0  # 整个wave的累计刷怪序号
var phase_enemy_lists: Array = []  # 每个phase的敌人列表
var _stop_spawning: bool = false  # 用于中断刷怪循环

# special_spawns 对应的全局索引（这些怪物不受“过近取消生成”规则影响）
var _special_spawn_global_indices: Dictionary = {}

func _ready() -> void:
	# 查找地图
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_error("[EnemySpawner V3] 找不到floor_layer")
	else:
		_refresh_used_cells_cache()
	
	# 查找玩家
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[EnemySpawner V3] 找不到player")
	
	# 从当前模式获取预警延迟配置
	_load_spawn_indicator_delay()
	
	_dprint("[EnemySpawner V3] 初始化完成，预警延迟: %s 秒" % str(spawn_indicator_delay))

## 刷新地面格子缓存（地图变化时可手动调用）
func _refresh_used_cells_cache() -> void:
	if not floor_layer:
		_cached_used_cells = []
		_used_cells_cache_valid = false
		return
	var cells: Array[Vector2i] = floor_layer.get_used_cells()
	_cached_used_cells = cells
	_used_cells_cache_valid = not _cached_used_cells.is_empty()
	_dprint("[EnemySpawner V3] used_cells 已缓存: %d" % _cached_used_cells.size())

## 从当前模式加载预警延迟配置
func _load_spawn_indicator_delay() -> void:
	var mode_id = GameMain.current_mode_id
	if mode_id and not mode_id.is_empty():
		var mode = ModeRegistry.get_mode(mode_id)
		# mode 是 BaseGameMode 对象，不要用 `"xxx" in mode`（那是给 Dictionary 用的）
		if mode:
			spawn_indicator_delay = float(mode.spawn_indicator_delay)
			_dprint("[EnemySpawner V3] 从模式获取预警延迟: %s 秒 (模式: %s)" % [str(spawn_indicator_delay), str(mode_id)])

## 设置波次系统
func set_wave_system(system: Node) -> void:
	wave_system = system as WaveSystemV3
	_dprint("[EnemySpawner V3] 连接到波次系统")

## ========== 新的Phase刷怪系统 ==========

## 开始多阶段刷怪
func spawn_wave_phases(wave_config: Dictionary, ws: WaveSystemV3) -> void:
	if is_spawning:
		push_warning("[EnemySpawner V3] 已在生成中，忽略")
		return
	
	wave_system = ws
	current_wave_config = wave_config
	_stop_spawning = false
	
	var wave_number = wave_config.wave_number
	var phases = wave_config.get("spawn_phases", [])
	var special_spawns = wave_config.get("special_spawns", [])
	
	print("[EnemySpawner V3] 开始Phase刷怪 - Wave %d, %d个Phase" % [wave_number, phases.size()])
	
	# 预构建所有phase的敌人列表
	phase_enemy_lists.clear()
	_special_spawn_global_indices.clear()
	for phase in phases:
		var enemy_list = _build_phase_enemy_list(phase)
		phase_enemy_lists.append(enemy_list)
	
	# 应用special_spawns到全局位置
	_apply_special_spawns(special_spawns)
	
	# 开始异步刷怪
	_spawn_all_phases_async(wave_config)

## 构建单个Phase的敌人列表（保证每种怪至少1只）
func _build_phase_enemy_list(phase_config: Dictionary) -> Array:
	var list = []
	var enemy_types = phase_config.get("enemy_types", {})
	var total = phase_config.get("total_count", 10)
	
	if enemy_types.is_empty():
		push_warning("[EnemySpawner V3] Phase没有配置enemy_types")
		return list
	
	total = int(total)
	if total <= 0:
		return list
	
	# 1) 如果 total_count 足够，先保证每种怪至少 1 只（但不允许超过 total_count）
	var keys: Array = enemy_types.keys()
	keys.sort() # 稳定顺序，避免 Dictionary 遍历顺序导致概率表现不稳定
	if total >= keys.size():
		for enemy_id in keys:
			list.append(enemy_id)
	else:
		# total_count 小于种类数时，不可能保证“每种至少 1 只”，否则会导致列表长度 > total_count，
		# 进而让 WaveSystem 的 total_enemies 与实际生成数量不一致，产生卡波/进度异常。
		push_warning("[EnemySpawner V3] Phase配置 total_count(%d) < 敌人种类数(%d)，将只生成 total_count 只（不保证每种至少1只）" % [total, keys.size()])
	
	# 2) 剩余按权重随机选择补齐到 total_count
	while list.size() < total:
		var enemy_id = _pick_by_probability(enemy_types)
		if enemy_id == "":
			break
		list.append(enemy_id)
	
	# 3. 打乱顺序
	list.shuffle()
	
	return list

## 按概率选择敌人类型
func _pick_by_probability(enemy_types: Dictionary) -> String:
	if enemy_types.is_empty():
		return ""
	
	# 兼容两种常见写法：
	# - 0~1 的概率权重（和通常为 1）
	# - 0~100 的百分比权重（和通常为 100）
	# 统一按“权重总和”归一化抽取：roll ∈ [0, sum)
	var keys: Array = enemy_types.keys()
	keys.sort() # 稳定顺序，保证相同配置下抽样结果可复现（不依赖插入顺序）
	
	var sum := 0.0
	var weights: Dictionary = {}
	for enemy_id in keys:
		var w := float(enemy_types.get(enemy_id, 0.0))
		# 过滤无效权重（<=0 视为不参与抽取）
		if w > 0.0:
			weights[enemy_id] = w
			sum += w
	
	if sum <= 0.0 or weights.is_empty():
		push_warning("[EnemySpawner V3] enemy_types 权重总和<=0，使用随机兜底选择")
		# 兜底：从所有 key 中随机一个（包括可能权重为0的）
		return str(keys[randi() % keys.size()])
	
	var roll := randf() * sum
	var cumulative := 0.0
	for enemy_id in keys:
		if not weights.has(enemy_id):
			continue
		cumulative += float(weights[enemy_id])
		if roll < cumulative:
			return str(enemy_id)
	
	# 浮点误差兜底：返回最后一个有效项
	for i in range(keys.size() - 1, -1, -1):
		var k = keys[i]
		if weights.has(k):
			return str(k)
	return str(keys[0])

## 应用special_spawns到全局位置（替换对应位置的敌人）
func _apply_special_spawns(special_spawns: Array) -> void:
	if special_spawns.is_empty():
		return
	
	# 构建全局敌人列表的索引映射
	# phase_enemy_lists是二维数组，需要计算全局索引
	var global_index = 0
	var index_to_phase_local: Array = []  # [(phase_idx, local_idx), ...]
	
	for phase_idx in range(phase_enemy_lists.size()):
		for local_idx in range(phase_enemy_lists[phase_idx].size()):
			index_to_phase_local.append([phase_idx, local_idx])
			global_index += 1
	
	var total_enemies = global_index
	
	# 按position升序处理
	special_spawns.sort_custom(func(a, b):
		return int(a.get("position", 0)) < int(b.get("position", 0))
	)
	
	var replaced_count := 0
	var skipped_count := 0
	
	for spawn in special_spawns:
		if not (spawn is Dictionary):
			continue
		var enemy_id = str(spawn.get("enemy_id", ""))
		if enemy_id.is_empty():
			continue
		
		var pos = int(spawn.get("position", 0))
		if pos < 0 or pos >= total_enemies:
			push_warning("[EnemySpawner V3] special_spawns position越界：pos=%d total=%d enemy_id=%s" % [pos, total_enemies, enemy_id])
			continue
		
		# 默认100%刷新；支持 0~1 概率或 0~100 百分比
		var chance := 1.0
		if spawn.has("spawn_chance"):
			chance = float(spawn.get("spawn_chance", 1.0))
			if chance > 1.0 and chance <= 100.0:
				chance = chance / 100.0
			chance = clamp(chance, 0.0, 1.0)
		
		if randf() <= chance:
			var mapping = index_to_phase_local[pos]
			var phase_idx = mapping[0]
			var local_idx = mapping[1]
			phase_enemy_lists[phase_idx][local_idx] = enemy_id
			_special_spawn_global_indices[pos] = true
			replaced_count += 1
		else:
			skipped_count += 1
	
	_dprint("[EnemySpawner V3] special_spawns处理完成：替换=%d 跳过=%d 总配置=%d" % [replaced_count, skipped_count, special_spawns.size()])

## 异步执行所有Phase的刷怪
func _spawn_all_phases_async(wave_config: Dictionary) -> void:
	is_spawning = true
	current_phase_index = 0
	global_spawn_index = 0
	
	var wave_number = wave_config.wave_number
	var hp_growth = wave_config.get("hp_growth", 0.0)
	var damage_growth = wave_config.get("damage_growth", 0.0)
	var min_alive = wave_config.get("min_alive_enemies", WaveSystemV3.DEFAULT_MIN_ALIVE_ENEMIES)
	var max_alive = wave_config.get("max_alive_enemies", WaveSystemV3.DEFAULT_MAX_ALIVE_ENEMIES)
	var phases = wave_config.get("spawn_phases", [])
	
	# 是否存在Boss（用于“最后一只怪”判定，避免在有Boss时把Phase最后一只小怪当成last）
	var boss_cfg = wave_config.get("boss_config", {})
	var boss_count = int(boss_cfg.get("count", 0))
	var boss_id = str(boss_cfg.get("enemy_id", ""))
	var has_boss: bool = boss_count > 0 and boss_id != ""
	
	for phase_idx in range(phases.size()):
		if _stop_spawning:
			break
		
		current_phase_index = phase_idx
		var phase = phases[phase_idx]
		var enemy_list = phase_enemy_lists[phase_idx]
		
		print("[EnemySpawner V3] 开始Phase %d/%d, 敌人数: %d" % [phase_idx + 1, phases.size(), enemy_list.size()])
		
		# 执行当前Phase的刷怪
		await _spawn_phase_async(
			enemy_list,
			phase,
			wave_number,
			hp_growth,
			damage_growth,
			min_alive,
			max_alive,
			has_boss
		)
		
		if _stop_spawning:
			break
		
		# Phase之间的过渡：等待场上怪物数量降到min_alive以下
		if phase_idx < phases.size() - 1:
			print("[EnemySpawner V3] Phase %d 刷完，等待场上怪物数 <= %d" % [phase_idx + 1, min_alive])
			await _wait_for_enemy_count_below(min_alive)
			print("[EnemySpawner V3] 条件满足，开始下一Phase")
	
	# 所有Phase刷完后，立即刷新Boss
	if not _stop_spawning:
		await _spawn_boss_async(wave_config, wave_number, hp_growth, damage_growth)
	
	is_spawning = false
	print("[EnemySpawner V3] 所有Phase和Boss刷怪完成")
	
	# 通知波次系统
	if wave_system and wave_system.has_method("on_all_phases_complete"):
		wave_system.on_all_phases_complete()

## 刷新Boss（在所有Phase完成后立即刷新）
func _spawn_boss_async(wave_config: Dictionary, wave_number: int, hp_growth: float, damage_growth: float) -> void:
	var boss_cfg = wave_config.get("boss_config", {})
	var boss_count = boss_cfg.get("count", 0)
	var boss_id = boss_cfg.get("enemy_id", "")
	
	if boss_count <= 0 or boss_id == "":
		return
	
	print("[EnemySpawner V3] 刷新Boss: %s x%d" % [boss_id, boss_count])
	
	for i in range(boss_count):
		if _stop_spawning:
			break
		
		# 刷新单个Boss
		var enemy = await _spawn_enemy_with_indicator(boss_id, i == boss_count - 1, wave_number, hp_growth, damage_growth)
		
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		elif wave_system and wave_system.has_method("on_enemy_spawn_failed"):
			wave_system.on_enemy_spawn_failed(boss_id)
		
		# Boss之间短暂间隔
		if i < boss_count - 1:
			var tree = get_tree()
			if tree:
				# 暂停（死亡UI等）期间应完全停止刷怪推进
				await tree.create_timer(0.5, false).timeout

## 执行单个Phase的刷怪
func _spawn_phase_async(
	enemy_list: Array,
	phase_config: Dictionary,
	wave_number: int,
	hp_growth: float,
	damage_growth: float,
	min_alive: int,
	max_alive: int,
	has_boss: bool
) -> void:
	var spawn_per_time = phase_config.get("spawn_per_time", 1)
	var spawn_interval = phase_config.get("spawn_interval", 2.0)
	
	var list_index = 0
	var total_in_phase = enemy_list.size()
	
	while list_index < total_in_phase:
		if _stop_spawning:
			break
		
		# 检查max限制 - 达到或超过max时暂停刷怪
		var current_active = wave_system.get_active_enemy_count() if wave_system else 0
		if current_active >= max_alive:
			_dprint("[EnemySpawner V3] 达到max限制(%d)，等待击杀..." % max_alive)
			# 等待敌人被击杀
			await _wait_for_enemy_count_below(max_alive)
			if _stop_spawning:
				break
			continue
		
		# 计算本次刷怪数量
		var remaining = total_in_phase - list_index
		var batch_size = min(spawn_per_time, remaining)
		
		# 确保不超过max
		var space_available = max_alive - current_active
		batch_size = min(batch_size, space_available)
		
		if batch_size <= 0:
			await get_tree().create_timer(0.1, false).timeout
			continue
		
		# 收集本批次要刷的敌人
		var batch_enemies = []
		for i in range(batch_size):
			batch_enemies.append(enemy_list[list_index + i])
		
		# 计算是否是最后一批（用于掉落判断）
		# 注意：如果本波还有 Boss，则最后一只应由 Boss 承担，Phase 小怪不能算 last（否则会提前掉 masterkey）
		var is_last_batch = (not has_boss) and (list_index + batch_size >= total_in_phase) and (current_phase_index >= phase_enemy_lists.size() - 1)
		
		# 批量刷怪（带预警）
		await _spawn_batch_with_indicators(batch_enemies, wave_number, hp_growth, damage_growth, is_last_batch)
		
		list_index += batch_size
		global_spawn_index += batch_size
		
		if _stop_spawning:
			break
		
		# 检查min - 低于min则跳过interval等待，立即继续刷怪
		current_active = wave_system.get_active_enemy_count() if wave_system else 0
		if current_active > min_alive and list_index < total_in_phase:
			await get_tree().create_timer(spawn_interval, false).timeout

## 批量刷怪（带预警图标）
func _spawn_batch_with_indicators(
	enemy_ids: Array,
	wave_number: int,
	hp_growth: float,
	damage_growth: float,
	is_last_batch: bool
) -> void:
	# 为每个敌人找位置并显示预警
	var spawn_data = []  # [{pos, indicator, enemy_id}, ...]
	
	for i in range(enemy_ids.size()):
		var enemy_id = enemy_ids[i]
		var planned_global_index: int = int(global_spawn_index) + int(i)
		var is_special := _special_spawn_global_indices.has(planned_global_index)
		var spawn_pos = _find_spawn_position()
		if spawn_pos == Vector2.INF:
			push_warning("[EnemySpawner V3] 无法找到合适位置：", enemy_id)
			# 生成失败也要通知
			if wave_system and wave_system.has_method("on_enemy_spawn_failed"):
				wave_system.on_enemy_spawn_failed(enemy_id)
			continue
		
		var indicator = _create_spawn_indicator(spawn_pos)
		spawn_data.append({
			"pos": spawn_pos,
			"indicator": indicator,
			"enemy_id": enemy_id,
			"is_last": is_last_batch and (i == enemy_ids.size() - 1),
			"is_special": is_special
		})
	
	# 等待预警延迟
	if spawn_data.size() > 0:
		await get_tree().create_timer(spawn_indicator_delay, false).timeout
	
	# 移除预警并生成敌人
	for data in spawn_data:
		if is_instance_valid(data.indicator):
			data.indicator.queue_free()
		
		# 生成瞬间二次安全检查：普通怪（非 special）如果离玩家太近则直接跳过
		if (not bool(data.get("is_special", false))) and _should_cancel_spawn_due_to_player_proximity(data.pos):
			if wave_system and wave_system.has_method("on_enemy_spawn_skipped"):
				wave_system.on_enemy_spawn_skipped(str(data.enemy_id), "too_close_to_player")
			elif wave_system and wave_system.has_method("on_enemy_spawn_failed"):
				# 兼容兜底：若没有 skipped 接口，至少计入进度避免卡死
				wave_system.on_enemy_spawn_failed(str(data.enemy_id))
			continue
		
		var enemy = _spawn_single_enemy_at_position(
			data.enemy_id,
			data.pos,
			data.is_last,
			wave_number,
			hp_growth,
			damage_growth
		)
		
		# 通知波次系统
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		elif wave_system and wave_system.has_method("on_enemy_spawn_failed"):
			wave_system.on_enemy_spawn_failed(data.enemy_id)

## 生成瞬间是否应取消（玩家距离过近）
func _should_cancel_spawn_due_to_player_proximity(spawn_pos: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return false
	return spawn_pos.distance_to(player.global_position) < SPAWN_CANCEL_DISTANCE_NEAR_PLAYER

## 等待场上敌人数量低于指定值
func _wait_for_enemy_count_below(threshold: int) -> void:
	while not _stop_spawning:
		var current = wave_system.get_active_enemy_count() if wave_system else 0
		if current < threshold:
			break
		# 短暂等待后重新检查
		await get_tree().create_timer(0.2, false).timeout

## ========== 兼容旧接口 ==========

## 生成一波敌人（旧接口，保持兼容）
func spawn_wave(wave_config: Dictionary) -> void:
	# 如果是新格式，使用新方法
	if wave_config.get("is_phase_format", false) or wave_config.has("spawn_phases"):
		if wave_system:
			spawn_wave_phases(wave_config, wave_system)
		else:
			push_error("[EnemySpawner V3] 使用新格式但wave_system未设置")
		return
	
	# 旧格式处理
	if is_spawning:
		push_warning("[EnemySpawner V3] 已在生成中，忽略")
		return
	
	if not wave_system:
		push_error("[EnemySpawner V3] 波次系统未设置")
		return
	
	var wave_number = wave_config.wave_number
	var spawn_interval = wave_config.get("spawn_interval", 0.4)
	var hp_growth = wave_config.get("hp_growth", 0.0)
	var damage_growth = wave_config.get("damage_growth", 0.0)
	
	_dprint("[EnemySpawner V3] 开始生成第 %d 波" % int(wave_number))
	_dprint("[EnemySpawner V3] 刷新间隔:%s | HP成长:%s%% | 伤害成长:%s%%" % [str(spawn_interval), str(hp_growth * 100.0), str(damage_growth * 100.0)])
	
	# 构建生成列表
	var spawn_list = _build_spawn_list(wave_config)
	
	# 开始异步生成（传入成长率）
	_spawn_enemies_async(spawn_list, wave_number, spawn_interval, hp_growth, damage_growth)

## 构建生成列表（旧格式）
func _build_spawn_list(config: Dictionary) -> Array:
	var list = []
	
	# 添加普通敌人
	if config.has("enemies"):
		for enemy_group in config.enemies:
			for i in range(enemy_group.count):
				list.append(enemy_group.id)
	
	# 打乱顺序，让不同类型的敌人随机混合出现
	list.shuffle()

	# 特殊刷怪（基于刷怪序列的位置 position）
	if config.has("special_spawns"):
		var spawns = config.special_spawns
		if spawns is Array and spawns.size() > 0:
			var replaced_count := 0
			var skipped_count := 0
			
			spawns.sort_custom(func(a, b):
				return int(a.get("position", 0)) < int(b.get("position", 0))
			)
			for spawn in spawns:
				if not (spawn is Dictionary):
					continue
				var enemy_id = str(spawn.get("enemy_id", ""))
				if enemy_id.is_empty():
					continue
				
				if list.is_empty():
					break
				
				var chance := 1.0
				if spawn.has("spawn_chance"):
					chance = float(spawn.get("spawn_chance", 1.0))
					if chance > 1.0 and chance <= 100.0:
						chance = chance / 100.0
					chance = clamp(chance, 0.0, 1.0)
				
				var pos = int(spawn.get("position", list.size() - 1))
				pos = clamp(pos, 0, list.size() - 1)
				
				if randf() <= chance:
					list[pos] = enemy_id
					replaced_count += 1
				else:
					skipped_count += 1
			
			_dprint("[EnemySpawner V3] special_spawns处理完成：替换=%d 跳过=%d 总配置=%d" % [replaced_count, skipped_count, spawns.size()])
	
	# 添加最后的敌人（BOSS放在最后，不参与打乱）
	if config.has("last_enemy"):
		for i in range(config.last_enemy.count):
			list.append(config.last_enemy.id)
	
	_dprint("[EnemySpawner V3] 生成列表：%d 个敌人（含last_enemy；special_spawns为替换不增量）" % list.size())
	return list

## 异步生成敌人列表（旧格式）
func _spawn_enemies_async(spawn_list: Array, wave_number: int, spawn_interval: float, hp_growth: float, damage_growth: float) -> void:
	is_spawning = true
	
	var index = 0
	for enemy_id in spawn_list:
		var is_last = (index == spawn_list.size() - 1)
		
		var enemy = await _spawn_enemy_with_indicator(enemy_id, is_last, wave_number, hp_growth, damage_growth)
		
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		else:
			push_warning("[EnemySpawner V3] 敌人生成失败：", enemy_id)
			if wave_system and wave_system.has_method("on_enemy_spawn_failed"):
				wave_system.on_enemy_spawn_failed(enemy_id)
		
		await get_tree().create_timer(spawn_interval, false).timeout
		index += 1
	
	is_spawning = false
	_dprint("[EnemySpawner V3] 生成完成")
	
	# 通知波次系统所有刷怪完成
	if wave_system and wave_system.has_method("on_all_phases_complete"):
		wave_system.on_all_phases_complete()

## ========== 基础刷怪方法 ==========

## 创建预警图片
func _create_spawn_indicator(pos: Vector2) -> Sprite2D:
	var indicator = Sprite2D.new()
	indicator.texture = spawn_indicator_texture
	indicator.global_position = pos
	indicator.z_index = 10  # 确保显示在地面上方
	indicator.modulate = Color(1, 1, 1, 0.8)  # 稍微透明
	add_child(indicator)
	return indicator

## 带预警的敌人生成
func _spawn_enemy_with_indicator(enemy_id: String, is_last_in_wave: bool, wave_number: int, hp_growth: float, damage_growth: float) -> Node:
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector2.INF:
		push_warning("[EnemySpawner V3] 无法找到合适位置：", enemy_id)
		return null
	
	var indicator = _create_spawn_indicator(spawn_pos)
	
	await get_tree().create_timer(spawn_indicator_delay, false).timeout
	
	if is_instance_valid(indicator):
		indicator.queue_free()
	
	var enemy = _spawn_single_enemy_at_position(enemy_id, spawn_pos, is_last_in_wave, wave_number, hp_growth, damage_growth)
	return enemy

## 查找生成位置
func _find_spawn_position() -> Vector2:
	if not floor_layer:
		return Vector2.INF

	if not _used_cells_cache_valid:
		_refresh_used_cells_cache()
	if not _used_cells_cache_valid:
		return Vector2.INF
	
	for attempt in max_spawn_attempts:
		var cell: Vector2i = _cached_used_cells[randi() % _cached_used_cells.size()]
		var world_pos: Vector2 = floor_layer.map_to_local(cell) * 6.0
		
		if _is_valid_spawn_distance(world_pos):
			return world_pos
	
	return Vector2.INF

## 获取敌人场景（带缓存）
func _get_enemy_scene(enemy_data: EnemyData) -> PackedScene:
	var scene_path = enemy_data.scene_path
	if scene_path == "" or scene_path == null:
		if fallback_enemy_scene:
			return fallback_enemy_scene
		else:
			push_error("[EnemySpawner V3] 敌人没有 scene_path 且没有设置 fallback_enemy_scene")
			return null
	
	if scene_cache.has(scene_path):
		return scene_cache[scene_path]
	
	if not ResourceLoader.exists(scene_path):
		push_error("[EnemySpawner V3] 场景文件不存在: %s" % scene_path)
		return fallback_enemy_scene
	
	var scene = load(scene_path) as PackedScene
	if scene:
		scene_cache[scene_path] = scene
		_dprint("[EnemySpawner V3] ✓ 缓存敌人场景: %s" % scene_path)
	else:
		push_error("[EnemySpawner V3] ✗ 无法加载场景: %s" % scene_path)
		return fallback_enemy_scene
	
	return scene

## 生成单个敌人（兼容旧接口，自动查找位置）
func _spawn_single_enemy(enemy_id: String, is_last_in_wave: bool = false, wave_number: int = 1, hp_growth: float = 0.0, damage_growth: float = 0.0) -> Node:
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector2.INF:
		push_warning("[EnemySpawner V3] 无法找到合适位置：", enemy_id)
		return null
	return _spawn_single_enemy_at_position(enemy_id, spawn_pos, is_last_in_wave, wave_number, hp_growth, damage_growth)

## 在指定位置生成单个敌人
func _spawn_single_enemy_at_position(enemy_id: String, spawn_pos: Vector2, is_last_in_wave: bool = false, wave_number: int = 1, hp_growth: float = 0.0, damage_growth: float = 0.0) -> Node:
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("[EnemySpawner V3] 敌人数据不存在：", enemy_id)
		return null
	
	var enemy_scene = _get_enemy_scene(enemy_data)
	if not enemy_scene:
		push_error("[EnemySpawner V3] 无法获取敌人场景：", enemy_id)
		return null
	
	var enemy := enemy_scene.instantiate()
	
	enemy.global_position = spawn_pos
	enemy.enemy_data = enemy_data
	enemy.enemy_id = enemy_id
	enemy.current_wave_number = wave_number
	enemy.is_last_enemy_in_wave = is_last_in_wave
	
	add_child(enemy)
	
	var hp_multiplier = 1.0 + hp_growth
	var damage_multiplier = 1.0 + damage_growth
	
	var wave_factor = max(0, wave_number - 1)
	var hp_growth_points = enemy_data.hp_growth_per_wave if enemy_data else 0.0
	var damage_growth_points = enemy_data.damage_growth_per_wave if enemy_data else 0.0
	var hp_bonus = hp_growth_points * wave_factor
	var damage_bonus = damage_growth_points * wave_factor
	
	enemy.max_enemyHP = int((enemy.max_enemyHP + hp_bonus) * hp_multiplier)
	enemy.enemyHP = enemy.max_enemyHP
	
	if "attack_damage" in enemy:
		enemy.attack_damage = int((enemy.attack_damage + damage_bonus) * damage_multiplier)
	
	_apply_skill_damage_growth(enemy, damage_multiplier, damage_bonus)
	
	_dprint("[EnemySpawner V3] 生成敌人：%s 波次:%d HP:%d 伤害:%d" % [str(enemy_id), int(wave_number), int(enemy.max_enemyHP), int(enemy.attack_damage)])
	return enemy

## 检查位置是否在有效刷怪范围内（最小距离 ~ 最大距离）
func _is_valid_spawn_distance(spawn_pos: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return true
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= SPAWN_MIN_DISTANCE and distance <= SPAWN_MAX_DISTANCE

## 应用技能伤害成长
func _apply_skill_damage_growth(enemy: Node, damage_multiplier: float, damage_growth_points: float = 0.0) -> void:
	if not "behaviors" in enemy:
		return
	
	for behavior in enemy.behaviors:
		if not is_instance_valid(behavior):
			continue
		
		if behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			charging.extra_damage = int((charging.extra_damage + damage_growth_points) * damage_multiplier)
		
		elif behavior is ShootingBehavior:
			var shooting = behavior as ShootingBehavior
			shooting.bullet_damage = int((shooting.bullet_damage + damage_growth_points) * damage_multiplier)
		
		elif behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.explosion_damage = int((exploding.explosion_damage + damage_growth_points) * damage_multiplier)
		
		elif behavior is BossShootingBehavior:
			var boss_shooting = behavior as BossShootingBehavior
			boss_shooting.bullet_damage = int((boss_shooting.bullet_damage + damage_growth_points) * damage_multiplier)

## 清理所有敌人（调试用）
func clear_all_enemies() -> void:
	_stop_spawning = true
	for child in get_children():
		if child is Enemy:
			child.queue_free()
	_dprint("[EnemySpawner V3] 清理所有敌人")

## 清除场景缓存（用于热重载）
func clear_scene_cache() -> void:
	scene_cache.clear()
	_dprint("[EnemySpawner V3] 场景缓存已清除")

## 停止刷怪
func stop_spawning() -> void:
	_stop_spawning = true
	is_spawning = false
