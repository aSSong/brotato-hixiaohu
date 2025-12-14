extends Node2D
class_name EnemySpawnerV3

## 新的敌人生成器 V3
## 职责：只负责生成敌人，不管理波次逻辑
## 
## 改进：使用预制场景系统，从 EnemyData.scene_path 加载敌人场景

## ========== 配置 ==========
## 默认敌人场景（兜底用，当 scene_path 为空时使用）
@export var fallback_enemy_scene: PackedScene

var floor_layer: TileMapLayer = null
var player: Node = null
var wave_system: Node = null

## ========== 场景缓存 ==========
## 缓存已加载的敌人场景，避免重复加载
var scene_cache: Dictionary = {}

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
	
	print("[EnemySpawner V3] 初始化完成")

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
	
	# 添加最后的敌人（BOSS放在最后，不参与打乱）
	if config.has("last_enemy"):
		for i in range(config.last_enemy.count):
			list.append(config.last_enemy.id)
	
	print("[EnemySpawner V3] 生成列表：", list.size(), " 个敌人")
	return list

## 异步生成敌人列表
func _spawn_enemies_async(spawn_list: Array, wave_number: int, spawn_interval: float, hp_growth: float, damage_growth: float) -> void:
	is_spawning = true
	
	var index = 0
	for enemy_id in spawn_list:
		var is_last = (index == spawn_list.size() - 1)
		
		# 生成敌人（传入成长率）
		var enemy = _spawn_single_enemy(enemy_id, is_last, wave_number, hp_growth, damage_growth)
		
		# 通知波次系统
		if enemy and wave_system:
			wave_system.on_enemy_spawned(enemy)
		else:
			push_warning("[EnemySpawner V3] 敌人生成失败：", enemy_id)
		
		# 等待间隔（受游戏暂停影响）
		# 第二个参数为false表示当游戏暂停时，计时器也暂停
		await get_tree().create_timer(spawn_interval, false).timeout
		index += 1
	
	is_spawning = false
	print("[EnemySpawner V3] 生成完成")

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

## 生成单个敌人
func _spawn_single_enemy(enemy_id: String, is_last_in_wave: bool = false, wave_number: int = 1, hp_growth: float = 0.0, damage_growth: float = 0.0) -> Node:
	if not floor_layer:
		push_error("[EnemySpawner V3] floor_layer未设置")
		return null
	
	var used := floor_layer.get_used_cells()
	if used.is_empty():
		push_error("[EnemySpawner V3] 地图没有可用格子")
		return null
	
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
	
	# 尝试多次找合适的位置
	for attempt in max_spawn_attempts:
		var cell := used[randi() % used.size()]
		var world_pos := floor_layer.map_to_local(cell) * 6
		
		# 检查距离玩家是否足够远
		if _is_far_enough_from_player(world_pos):
			var enemy := enemy_scene.instantiate()
			
			# 设置位置
			enemy.global_position = world_pos
			
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
			# HP成长：基础值 * (1 + 成长率)
			var hp_multiplier = 1.0 + hp_growth
			var damage_multiplier = 1.0 + damage_growth
			
			enemy.max_enemyHP = int(enemy.max_enemyHP * hp_multiplier)
			enemy.enemyHP = enemy.max_enemyHP
			
			# 应用伤害成长（触碰伤害）
			if "attack_damage" in enemy:
				enemy.attack_damage = int(enemy.attack_damage * damage_multiplier)
			
			# 应用技能伤害成长
			_apply_skill_damage_growth(enemy, damage_multiplier)
			
			print("[EnemySpawner V3] 生成敌人：", enemy_id, " 波次:", wave_number, 
				  " HP倍数:", hp_multiplier, " 实际HP:", enemy.max_enemyHP,
				  " 伤害倍数:", damage_multiplier)
			return enemy
	
	# 尝试多次后仍失败
	push_warning("[EnemySpawner V3] 无法找到合适位置（尝试", max_spawn_attempts, "次）：", enemy_id)
	return null

## 检查位置是否足够远
func _is_far_enough_from_player(spawn_pos: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return true
	
	var distance := spawn_pos.distance_to(player.global_position)
	return distance >= min_distance_from_player

## 应用技能伤害成长
func _apply_skill_damage_growth(enemy: Node, damage_multiplier: float) -> void:
	if not "behaviors" in enemy:
		return
	
	for behavior in enemy.behaviors:
		if not is_instance_valid(behavior):
			continue
		
		# 冲锋技能：额外伤害成长
		if behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			charging.extra_damage = int(charging.extra_damage * damage_multiplier)
		
		# 射击技能：子弹伤害成长
		elif behavior is ShootingBehavior:
			var shooting = behavior as ShootingBehavior
			shooting.bullet_damage = int(shooting.bullet_damage * damage_multiplier)
		
		# 自爆技能：爆炸伤害成长
		elif behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.explosion_damage = int(exploding.explosion_damage * damage_multiplier)

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
