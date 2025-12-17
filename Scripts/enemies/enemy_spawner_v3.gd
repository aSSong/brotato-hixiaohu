extends Node2D
class_name EnemySpawnerV3

## 新的敌人生成器 V3
## 职责：只负责生成敌人，不管理波次逻辑
## 
## 改进：使用预制场景系统，从 EnemyData.scene_path 加载敌人场景

## ========== 配置 ==========
## 默认敌人场景（兜底用，当 scene_path 为空时使用）
@export var fallback_enemy_scene: PackedScene

## 刷新预警图片
var spawn_indicator_texture: Texture2D = preload("res://assets/others/enemy_spawn_indicator_01.png")

var floor_layer: TileMapLayer = null
var player: Node = null
var wave_system: Node = null

## ========== 场景缓存 ==========
## 缓存已加载的敌人场景，避免重复加载
var scene_cache: Dictionary = {}

## ========== 预警配置 ==========
var spawn_indicator_delay: float = 0.5  # 默认预警延迟，会从模式配置覆盖

## ========== 生成参数 ==========
var min_distance_from_player: float = 300.0
var max_spawn_attempts: int = 30

## ========== 状态 ==========
var is_spawning: bool = false

func _ready() -> void:
	# 查找地图
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_error("[EnemySpawner V3] 找不到floor_layer")
	
	# 查找玩家
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[EnemySpawner V3] 找不到player")
	
	# 从当前模式获取预警延迟配置
	_load_spawn_indicator_delay()
	
	print("[EnemySpawner V3] 初始化完成，预警延迟: ", spawn_indicator_delay, " 秒")

## 从当前模式加载预警延迟配置
func _load_spawn_indicator_delay() -> void:
	var mode_id = GameMain.current_mode_id
	if mode_id and not mode_id.is_empty():
		var mode = ModeRegistry.get_mode(mode_id)
		if mode and "spawn_indicator_delay" in mode:
			spawn_indicator_delay = mode.spawn_indicator_delay
			print("[EnemySpawner V3] 从模式获取预警延迟: ", spawn_indicator_delay, " 秒 (模式: ", mode_id, ")")

## 设置波次系统
func set_wave_system(system: Node) -> void:
	wave_system = system
	print("[EnemySpawner V3] 连接到波次系统")

## 生成一波敌人
func spawn_wave(wave_config: Dictionary) -> void:
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
	
	print("[EnemySpawner V3] 开始生成第 ", wave_number, " 波")
	print("[EnemySpawner V3] 刷新间隔: ", spawn_interval, " | HP成长: ", hp_growth * 100, "% | 伤害成长: ", damage_growth * 100, "%")
	
	# 构建生成列表
	var spawn_list = _build_spawn_list(wave_config)
	
	# 开始异步生成（传入成长率）
	_spawn_enemies_async(spawn_list, wave_number, spawn_interval, hp_growth, damage_growth)

## 构建生成列表
func _build_spawn_list(config: Dictionary) -> Array:
	var list = []
	
	# 添加普通敌人
	if config.has("enemies"):
		for enemy_group in config.enemies:
			for i in range(enemy_group.count):
				list.append(enemy_group.id)
	
	# 打乱顺序，让不同类型的敌人随机混合出现
	list.shuffle()

	# 插入特殊刷怪（基于刷怪序列的位置 position）
	# JSON格式示例: { "position": 143, "enemy_id": "last_enemy" }
	if config.has("special_spawns"):
		var spawns = config.special_spawns
		if spawns is Array and spawns.size() > 0:
			# 按position升序插入，避免插入导致后续索引偏移不受控
			spawns.sort_custom(func(a, b):
				return int(a.get("position", 0)) < int(b.get("position", 0))
			)
			for spawn in spawns:
				if not (spawn is Dictionary):
					continue
				var enemy_id = str(spawn.get("enemy_id", ""))
				if enemy_id.is_empty():
					continue
				var pos = int(spawn.get("position", list.size()))
				pos = clamp(pos, 0, list.size())
				list.insert(pos, enemy_id)
			print("[EnemySpawner V3] 已插入 special_spawns: ", spawns.size())
	
	# 添加最后的敌人（BOSS放在最后，不参与打乱）
	if config.has("last_enemy"):
		for i in range(config.last_enemy.count):
			list.append(config.last_enemy.id)
	
	print("[EnemySpawner V3] 生成列表：", list.size(), " 个敌人（含special_spawns/last_enemy）")
	return list

## 异步生成敌人列表
func _spawn_enemies_async(spawn_list: Array, wave_number: int, spawn_interval: float, hp_growth: float, damage_growth: float) -> void:
	is_spawning = true
	
	var index = 0
	for enemy_id in spawn_list:
		var is_last = (index == spawn_list.size() - 1)
		
		# 带预警的敌人生成（传入成长率）
		var enemy = await _spawn_enemy_with_indicator(enemy_id, is_last, wave_number, hp_growth, damage_growth)
		
		# 通知波次系统
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		else:
			push_warning("[EnemySpawner V3] 敌人生成失败：", enemy_id)
			# 失败也要推进波次生成进度，避免波次系统卡在 SPAWNING
			if wave_system and wave_system.has_method("on_enemy_spawn_failed"):
				wave_system.on_enemy_spawn_failed(enemy_id)
		
		# 等待间隔（受游戏暂停影响）
		# 第二个参数为false表示当游戏暂停时，计时器也暂停
		await get_tree().create_timer(spawn_interval, false).timeout
		index += 1
	
	is_spawning = false
	print("[EnemySpawner V3] 生成完成")

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
	# 先找一个有效的生成位置
	var spawn_pos = _find_spawn_position()
	if spawn_pos == Vector2.INF:
		push_warning("[EnemySpawner V3] 无法找到合适位置：", enemy_id)
		return null
	
	# 显示预警图片
	var indicator = _create_spawn_indicator(spawn_pos)
	
	# 等待预警延迟
	await get_tree().create_timer(spawn_indicator_delay, false).timeout
	
	# 移除预警图片
	if is_instance_valid(indicator):
		indicator.queue_free()
	
	# 在该位置生成敌人
	var enemy = _spawn_single_enemy_at_position(enemy_id, spawn_pos, is_last_in_wave, wave_number, hp_growth, damage_growth)
	return enemy

## 查找生成位置
func _find_spawn_position() -> Vector2:
	if not floor_layer:
		return Vector2.INF
	
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		return Vector2.INF
	
	# 尝试多次找合适的位置
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		# 检查距离玩家是否足够远
		if _is_far_enough_from_player(world_pos):
			return world_pos
	
	return Vector2.INF

## 获取敌人场景（带缓存）
func _get_enemy_scene(enemy_data: EnemyData) -> PackedScene:
	# 如果 scene_path 为空，使用兜底场景
	var scene_path = enemy_data.scene_path
	if scene_path == "" or scene_path == null:
		if fallback_enemy_scene:
			return fallback_enemy_scene
		else:
			push_error("[EnemySpawner V3] 敌人没有 scene_path 且没有设置 fallback_enemy_scene")
			return null
	
	# 检查缓存
	if scene_cache.has(scene_path):
		return scene_cache[scene_path]
	
	# 加载场景
	if not ResourceLoader.exists(scene_path):
		push_error("[EnemySpawner V3] 场景文件不存在: %s" % scene_path)
		return fallback_enemy_scene
	
	var scene = load(scene_path) as PackedScene
	if scene:
		scene_cache[scene_path] = scene
		print("[EnemySpawner V3] ✓ 缓存敌人场景: %s" % scene_path)
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
	# 获取敌人数据
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("[EnemySpawner V3] 敌人数据不存在：", enemy_id)
		return null
	
	# 获取敌人场景（从预制场景或兜底场景）
	var enemy_scene = _get_enemy_scene(enemy_data)
	if not enemy_scene:
		push_error("[EnemySpawner V3] 无法获取敌人场景：", enemy_id)
		return null
	
	var enemy := enemy_scene.instantiate()
	
	# 设置位置
	enemy.global_position = spawn_pos
	
	# 初始化敌人数据（只应用数值属性，动画已在预制场景中配置）
	enemy.enemy_data = enemy_data
	
	# 设置敌人 ID（用于 BOSS 血条等功能）
	enemy.enemy_id = enemy_id
	
	# 设置波次号（用于掉落判断）
	enemy.current_wave_number = wave_number
	
	# 标记是否为最后一个敌人（掉落钥匙）
	enemy.is_last_enemy_in_wave = is_last_in_wave
	
	# 添加到场景树（这会触发_ready()，应用 enemy_data）
	add_child(enemy)
	
	# 在_ready()执行完后，应用成长率（必须在add_child之后）
	# 公式：(基础值 + 成长点数 × (波次-1)) × (1 + 成长率)
	var hp_multiplier = 1.0 + hp_growth
	var damage_multiplier = 1.0 + damage_growth
	
	# 获取敌人专属的成长点数（乘以波次-1，第1波不加成）
	var wave_factor = max(0, wave_number - 1)
	var hp_growth_points = enemy_data.hp_growth_per_wave if enemy_data else 0.0
	var damage_growth_points = enemy_data.damage_growth_per_wave if enemy_data else 0.0
	var hp_bonus = hp_growth_points * wave_factor
	var damage_bonus = damage_growth_points * wave_factor
	
	# HP成长：(基础值 + 成长点数 × (波次-1)) × (1 + 成长率)
	enemy.max_enemyHP = int((enemy.max_enemyHP + hp_bonus) * hp_multiplier)
	enemy.enemyHP = enemy.max_enemyHP
	
	# 应用伤害成长（触碰伤害）
	if "attack_damage" in enemy:
		enemy.attack_damage = int((enemy.attack_damage + damage_bonus) * damage_multiplier)
	
	# 应用技能伤害成长（传递累积后的成长点数）
	_apply_skill_damage_growth(enemy, damage_multiplier, damage_bonus)
	
	print("[EnemySpawner V3] 生成敌人：", enemy_id, " 波次:", wave_number, 
		  " HP:", enemy.max_enemyHP, "(基础+", hp_bonus, ")×", hp_multiplier,
		  " 伤害:", enemy.attack_damage, "(基础+", damage_bonus, ")×", damage_multiplier)
	return enemy

## 检查位置是否足够远
func _is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return true
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= min_distance_from_player

## 应用技能伤害成长
## 公式：(基础值 + 成长点数) * (1 + 成长率)
func _apply_skill_damage_growth(enemy: Node, damage_multiplier: float, damage_growth_points: float = 0.0) -> void:
	if not "behaviors" in enemy:
		return
	
	for behavior in enemy.behaviors:
		if not is_instance_valid(behavior):
			continue
		
		# 冲锋技能：额外伤害成长
		if behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			charging.extra_damage = int((charging.extra_damage + damage_growth_points) * damage_multiplier)
		
		# 射击技能：子弹伤害成长
		elif behavior is ShootingBehavior:
			var shooting = behavior as ShootingBehavior
			shooting.bullet_damage = int((shooting.bullet_damage + damage_growth_points) * damage_multiplier)
		
		# 自爆技能：爆炸伤害成长
		elif behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.explosion_damage = int((exploding.explosion_damage + damage_growth_points) * damage_multiplier)
		
		# Boss射击技能：子弹伤害成长
		elif behavior is BossShootingBehavior:
			var boss_shooting = behavior as BossShootingBehavior
			boss_shooting.bullet_damage = int((boss_shooting.bullet_damage + damage_growth_points) * damage_multiplier)

## 清理所有敌人（调试用）
func clear_all_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()
	print("[EnemySpawner V3] 清理所有敌人")

## 清除场景缓存（用于热重载）
func clear_scene_cache() -> void:
	scene_cache.clear()
	print("[EnemySpawner V3] 场景缓存已清除")
