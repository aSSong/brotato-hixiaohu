extends Node
class_name CombatEffectManager

## 战斗特效管理器（对象池优化版）
## 
## 统一管理所有战斗相关的视觉特效（粒子、序列帧动画等）
## 支持组合特效（同时播放序列帧动画和粒子特效）
## 所有特效资源在初始化时预加载，避免运行时卡顿
## 使用对象池复用特效实例，减少实例化开销
## 
## 使用示例：
##   CombatEffectManager.play_explosion("陨石", position)
##   CombatEffectManager.play_enemy_death(position)
##   CombatEffectManager.play_effect_group([...], position)  # 组合特效

## 特效类型枚举
enum EffectType {
	EXPLOSION,      # 爆炸
	HIT,            # 击中
	DEATH,          # 死亡
	CAST,           # 释放
	BULLET_HIT,     # 子弹击中
	ENEMY_HURT,     # 敌人受伤
}

## 调试输出开关（默认关闭，避免后期频繁特效导致 print 刷屏卡顿）
const DEBUG_LOG: bool = false
static func _dprint(msg) -> void:
	if DEBUG_LOG and OS.is_debug_build():
		print(msg)

## 预加载的特效场景字典（粒子和序列帧场景）
static var effect_scenes: Dictionary = {}

## 特效配置字典
## 结构：{ "武器名_类型": { "particles": [...], "animations": [...] } }
## animations 可以是：
##   - 字符串数组：["ani_name"] - 使用默认的 animations.tscn
##   - 字典数组：[{"scene_path": "...", "ani_name": "...", "scale": 1.0}] - 使用指定场景
static var effect_configs: Dictionary = {}

## 默认序列帧场景路径
const DEFAULT_ANIMATION_SCENE = "res://scenes/animations/animations.tscn"

## ========== 对象池系统 ==========

## 特效对象池（按场景路径分类）
## 结构：{ "scene_path": [instance1, instance2, ...] }
static var _effect_pools: Dictionary = {}

## 对象池元数据 key（用于防止异步误回收）
const _POOL_META_TOKEN: String = "__pool_token"
const _POOL_META_IN_USE: String = "__pool_in_use"

## 每种特效的池大小限制
const POOL_SIZE_PER_EFFECT: int = 100

## 活跃特效计数（用于调试）
static var _active_effect_count: int = 0

## 标记实例为“借出中”，并 bump token（每次借出都会变化）
static func _mark_in_use(instance: Node) -> int:
	if not is_instance_valid(instance):
		return 0
	var token: int = 0
	if instance.has_meta(_POOL_META_TOKEN):
		token = int(instance.get_meta(_POOL_META_TOKEN))
	token += 1
	instance.set_meta(_POOL_META_TOKEN, token)
	instance.set_meta(_POOL_META_IN_USE, true)
	return token

## 标记实例为“已归还”（用于抑制重复归还）
static func _mark_returned(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	instance.set_meta(_POOL_META_IN_USE, false)

static func _is_in_use(instance: Node) -> bool:
	if not is_instance_valid(instance):
		return false
	return bool(instance.get_meta(_POOL_META_IN_USE, false))

static func _get_token(instance: Node) -> int:
	if not is_instance_valid(instance):
		return 0
	if instance.has_meta(_POOL_META_TOKEN):
		return int(instance.get_meta(_POOL_META_TOKEN))
	return 0

## 从对象池获取实例
static func _get_from_pool(scene_path: String) -> Node:
	# 检查池中是否有可用实例
	if _effect_pools.has(scene_path) and _effect_pools[scene_path].size() > 0:
		var pool_array: Array = _effect_pools[scene_path]
		while pool_array.size() > 0:
			var instance = pool_array.pop_back()
			if is_instance_valid(instance):
				_active_effect_count += 1
				_mark_in_use(instance)
				return instance
	
	# 池中没有，创建新实例
	if not effect_scenes.has(scene_path):
		return null
	
	var scene = effect_scenes[scene_path]
	if scene == null:
		return null
	
	var instance = scene.instantiate()
	if instance:
		_active_effect_count += 1
		_mark_in_use(instance)
	return instance

## 归还实例到对象池
static func _return_to_pool(scene_path: String, instance: Node) -> void:
	if not is_instance_valid(instance):
		return

	# 防止重复归还（例如：旧的 timer/信号回调误触发）
	if not _is_in_use(instance):
		return

	_mark_returned(instance)
	_active_effect_count -= 1
	
	# 初始化池（如果不存在）
	if not _effect_pools.has(scene_path):
		_effect_pools[scene_path] = []
	
	var pool_array: Array = _effect_pools[scene_path]
	
	# 检查池是否已满
	if pool_array.size() >= POOL_SIZE_PER_EFFECT:
		instance.queue_free()
		return
	
	# 重置实例状态
	_reset_effect_instance(instance)
	
	# 从父节点移除（但不销毁）
	if instance.get_parent():
		instance.get_parent().remove_child(instance)
	
	pool_array.append(instance)

## 重置特效实例状态（用于复用）
static func _reset_effect_instance(instance: Node) -> void:
	instance.visible = false
	
	if instance is Node2D:
		instance.scale = Vector2.ONE
		instance.rotation = 0.0

	# 递归重置：粒子/序列帧/动画播放器（避免复用残留）
	_reset_effect_instance_recursive(instance)


static func _reset_effect_instance_recursive(node: Node) -> void:
	# 停止粒子发射
	if node is CPUParticles2D:
		node.emitting = false
		node.restart()
	elif node is GPUParticles2D:
		node.emitting = false
		node.restart()
	elif node is AnimatedSprite2D:
		node.stop()
	elif node is AnimationPlayer:
		node.stop()

	for child in node.get_children():
		_reset_effect_instance_recursive(child)

## 启动粒子发射
static func _start_particle_emitting(instance: Node) -> void:
	# 复用安全：先 restart 清场再 emitting，避免残留粒子“串位置”
	if instance is CPUParticles2D:
		instance.restart()
		instance.emitting = true
	elif instance is GPUParticles2D:
		instance.restart()
		instance.emitting = true
	
	for child in instance.get_children():
		if child is CPUParticles2D:
			child.restart()
			child.emitting = true
		elif child is GPUParticles2D:
			child.restart()
			child.emitting = true

## 获取粒子最大生命周期
static func _get_particle_lifetime(instance: Node) -> float:
	var max_lifetime = 0.0

	# 计算单个粒子的“最坏情况”生命周期：lifetime * (1 + lifetime_randomness)
	# 注意：GPUParticles2D 的 lifetime_randomness 在 ParticleProcessMaterial 上
	var effective := _get_particle_effective_lifetime(instance)
	if effective > max_lifetime:
		max_lifetime = effective
	
	for child in instance.get_children():
		effective = _get_particle_effective_lifetime(child)
		if effective > max_lifetime:
			max_lifetime = effective
	
	return max_lifetime if max_lifetime > 0 else 2.0


static func _get_particle_effective_lifetime(node: Node) -> float:
	var base: float = 0.0
	var randomness: float = 0.0
	if node is CPUParticles2D:
		base = float(node.lifetime)
		randomness = float(node.lifetime_randomness)
	elif node is GPUParticles2D:
		base = float(node.lifetime)
		var pm = node.process_material
		if pm is ParticleProcessMaterial:
			randomness = float(pm.lifetime_randomness)
	# randomness 通常为 0~1，取最坏情况
	randomness = clampf(randomness, 0.0, 1.0)
	if base <= 0.0:
		return 0.0
	return base * (1.0 + randomness)

## 计划归还到对象池（粒子播放完毕后）
static func _schedule_return_to_pool(scene_path: String, instance: Node, delay: float) -> void:
	if not is_instance_valid(instance):
		return

	var token: int = _get_token(instance)
	var tree = instance.get_tree()
	if not tree:
		# 没有 tree：直接回收，避免 active_count 泄露
		_return_to_pool(scene_path, instance)
		return

	await tree.create_timer(delay, false).timeout

	# 防止异步误回收：token 必须一致且仍处于 in_use
	if not is_instance_valid(instance):
		return
	if _get_token(instance) != token:
		return
	if not _is_in_use(instance):
		return

	_return_to_pool(scene_path, instance)

## 获取对象池统计（调试用）
static func get_pool_stats() -> Dictionary:
	var stats = {
		"active_count": _active_effect_count,
		"pools": {}
	}
	for scene_path in _effect_pools:
		stats["pools"][scene_path] = _effect_pools[scene_path].size()
	return stats

## 清空所有对象池（场景切换时调用）
static func clear_all_pools() -> void:
	for scene_path in _effect_pools:
		var pool_array: Array = _effect_pools[scene_path]
		for instance in pool_array:
			if is_instance_valid(instance):
				instance.queue_free()
		pool_array.clear()
	_effect_pools.clear()
	_active_effect_count = 0
	_dprint("[CombatEffectManager] 对象池已清空")

## ========== 初始化 ==========

## 初始化管理器（预加载所有特效）
static func initialize() -> void:
	if not effect_scenes.is_empty():
		return  # 已经初始化过了
	
	_dprint("[CombatEffectManager] 开始预加载战斗特效...")
	
	# 配置特效映射
	_setup_effect_configs()
	
	# 预加载所有粒子特效场景和序列帧场景
	for config_key in effect_configs.keys():
		var config = effect_configs[config_key]
		
		# 预加载粒子特效
		var particles = config.get("particles", [])
		for particle_path in particles:
			if particle_path == "":
				continue
			
			if not ResourceLoader.exists(particle_path):
				push_warning("[CombatEffectManager] 特效文件不存在: %s" % particle_path)
				continue
			
			if not effect_scenes.has(particle_path):
				var scene = load(particle_path)
				if scene:
					effect_scenes[particle_path] = scene
					_dprint("[CombatEffectManager] ✓ 预加载粒子: %s" % particle_path)
				else:
					push_error("[CombatEffectManager] ✗ 加载失败: %s" % particle_path)
		
		# 预加载序列帧场景
		var animations = config.get("animations", [])
		for anim_config in animations:
			var scene_path = ""
			
			# 支持两种格式：字符串（使用默认场景）或字典（指定场景）
			if anim_config is String:
				scene_path = DEFAULT_ANIMATION_SCENE
			elif anim_config is Dictionary:
				scene_path = anim_config.get("scene_path", DEFAULT_ANIMATION_SCENE)
			
			if scene_path == "" or scene_path == DEFAULT_ANIMATION_SCENE:
				# 默认场景已经在 GameMain 中加载，跳过
				continue
			
			if not ResourceLoader.exists(scene_path):
				push_warning("[CombatEffectManager] 序列帧场景文件不存在: %s" % scene_path)
				continue
			
			if not effect_scenes.has(scene_path):
				var scene = load(scene_path)
				if scene:
					effect_scenes[scene_path] = scene
					_dprint("[CombatEffectManager] ✓ 预加载序列帧: %s" % scene_path)
				else:
					push_error("[CombatEffectManager] ✗ 加载失败: %s" % scene_path)
	
	_dprint("[CombatEffectManager] 预加载完成，共 %d 个特效场景" % effect_scenes.size())

## 设置特效配置
static func _setup_effect_configs() -> void:
	# 武器爆炸特效（粒子）
	effect_configs["奥爆术_爆炸"] = {
		"animations": [
			{
				"scene_path": "res://scenes/effects/explosion_sprites.tscn",
				"ani_name": "Meteor_explode",
				"scale": 1.5
			},
			{
				"scene_path": "res://scenes/effects/explosion_sprites.tscn",
				"ani_name": "mt_fog",
				"scale": 1.5
			}
		]
	}
	effect_configs["火球_爆炸"] = {
		#"particles": ["res://scenes/effects/fireball_explosion.tscn"],
		"animations": [{
			 "scene_path": "res://scenes/effects/explosion_sprites.tscn",
			 "ani_name": "fire_explode",
			 "scale": 1.3  # 自定义scale
		 }]
	}
	effect_configs["冰棒_爆炸"] = {
		"animations": [{
			 "scene_path": "res://scenes/effects/explosion_sprites.tscn",
			 "ani_name": "ice_explode",
			 "scale": 1.0  # 自定义scale
		 }]
	}
	
	# 敌人特效（序列帧动画 - 使用默认场景）
	effect_configs["敌人_死亡"] = {
		"particles": ["res://FX/gpu_particles_2d_enemy_dead.tscn"],
		#"animations": ["enemies_dead"]  # 简单格式：使用默认 animations.tscn
	}
	effect_configs["敌人_受伤"] = {
		"particles": [],
		#"animations": ["enemies_hurt"]  # 简单格式：使用默认 animations.tscn
	}
	effect_configs["敌人_自爆"] = {
		#"particles": ["res://FX/gpu_particles_2d_enemy_dead.tscn"],
		#"animations": [{
			#"scene_path": "res://scenes/effects/explosion_sprites.tscn",
			#"ani_name": "fire_explode",
			#"scale": 1.5
		#}]
	}

## ========== 公共接口 ==========

## 播放爆炸特效
## 
## @param weapon_name 武器名称（"陨石"、"火球"、"冰刺"）
## @param position 爆炸位置
## @param scale 缩放倍数（可选）
static func play_explosion(weapon_name: String, position: Vector2, scale: float = 1.0) -> void:
	var config_key = weapon_name + "_爆炸"
	if not effect_configs.has(config_key):
		push_warning("[CombatEffectManager] 未找到爆炸特效: %s" % weapon_name)
		return
	
	var config = effect_configs[config_key]
	_play_effect_config(config, position, scale)

## 播放敌人死亡特效
static func play_enemy_death(position: Vector2, scale: float = 1.0) -> void:
	var config_key = "敌人_死亡"
	if not effect_configs.has(config_key):
		push_warning("[CombatEffectManager] 未找到敌人死亡特效配置")
		return
	
	_dprint("[CombatEffectManager] 播放敌人死亡特效，位置: %s" % position)
	var config = effect_configs[config_key]
	_play_effect_config(config, position, scale)

## 播放敌人自爆特效
static func play_enemy_explosion(position: Vector2, scale: float = 1.0) -> void:
	var config_key = "敌人_自爆"
	if not effect_configs.has(config_key):
		push_warning("[CombatEffectManager] 未找到敌人自爆特效配置")
		return
	
	_dprint("[CombatEffectManager] 播放敌人自爆特效，位置: %s" % position)
	var config = effect_configs[config_key]
	_play_effect_config(config, position, scale)

## 播放敌人受伤特效
static func play_enemy_hurt(position: Vector2, scale: float = 1.0) -> void:
	var config_key = "敌人_受伤"
	if not effect_configs.has(config_key):
		push_warning("[CombatEffectManager] 未找到敌人受伤特效配置")
		return
	
	var config = effect_configs[config_key]
	_play_effect_config(config, position, scale)

## 播放击中特效（预留接口）
static func play_hit_effect(_effect_type: EffectType, _position: Vector2, _scale: float = 1.0) -> void:
	# 未来实现
	# 占位：显式使用参数，避免在“warnings treated as errors”配置下报错
	if DEBUG_LOG and OS.is_debug_build():
		_dprint("[CombatEffectManager] play_hit_effect placeholder: %s %s %s" % [str(_effect_type), str(_position), str(_scale)])
	pass

## ========== 武器特效（场景+动画名模式） ==========

## 播放枪口特效（绑定到父节点，跟随移动）- 使用对象池
## 
## @param scene_path 特效场景路径
## @param ani_name 动画名称
## @param parent_node 父节点（特效会作为其子节点，跟随移动）
## @param local_position 相对于父节点的本地位置
## @param rotation_val 特效旋转角度（弧度，全局方向）
## @param scale_val 缩放倍数
static func play_muzzle_flash(scene_path: String, ani_name: String, parent_node: Node2D, local_position: Vector2 = Vector2.ZERO, rotation_val: float = 0.0, scale_val: float = 1.0) -> void:
	if scene_path == "" or ani_name == "":
		return
	
	if not parent_node or not is_instance_valid(parent_node):
		push_error("[CombatEffectManager] 枪口特效的父节点无效")
		return
	
	# 确保场景已预加载
	if not effect_scenes.has(scene_path):
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				effect_scenes[scene_path] = scene
			else:
				push_error("[CombatEffectManager] 无法加载枪口特效场景: %s" % scene_path)
				return
		else:
			push_error("[CombatEffectManager] 枪口特效场景不存在: %s" % scene_path)
			return
	
	# 从对象池获取实例
	var instance = _get_from_pool(scene_path)
	if instance == null:
		push_warning("[CombatEffectManager] 无法获取枪口特效实例: %s" % scene_path)
		return

	var token: int = _get_token(instance)
	
	# 设置属性
	parent_node.add_child(instance)
	instance.position = local_position  # 使用本地坐标
	instance.rotation = rotation_val - parent_node.global_rotation  # 补偿父节点的旋转
	instance.scale = Vector2(scale_val, scale_val)
	instance.visible = true
	
	# 查找并播放动画
	var animated_sprite = _find_animated_sprite_in_node(instance)
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(ani_name):
			animated_sprite.play(ani_name)
			# 连接动画完成信号，归还到池
			if not animated_sprite.sprite_frames.get_animation_loop(ani_name):
				# 非循环动画，完成后归还
				animated_sprite.animation_finished.connect(
					func():
						# 防止复用后旧回调误归还
						if not is_instance_valid(instance):
							return
						if _get_token(instance) != token:
							return
						_return_to_pool(scene_path, instance),
					CONNECT_ONE_SHOT
				)
			else:
				# 循环动画，延迟归还
				var frame_count = animated_sprite.sprite_frames.get_frame_count(ani_name)
				var anim_speed = animated_sprite.sprite_frames.get_animation_speed(ani_name)
				var duration = frame_count / anim_speed if anim_speed > 0 else 0.5
				_schedule_return_to_pool(scene_path, instance, duration)
		else:
			push_warning("[CombatEffectManager] 枪口动画不存在: %s" % ani_name)
			_return_to_pool(scene_path, instance)
	else:
		push_warning("[CombatEffectManager] 未找到 AnimatedSprite2D")
		_return_to_pool(scene_path, instance)

## 击中特效默认层级（比敌人高，敌人通常在 z_index = 0 ~ 10）
const HIT_EFFECT_Z_INDEX = 50

## 播放子弹击中特效 - 使用对象池
## 
## @param scene_path 特效场景路径
## @param ani_name 动画名称
## @param position 特效位置
## @param scale_val 缩放倍数
static func play_bullet_hit(scene_path: String, ani_name: String, position: Vector2, scale_val: float = 1.0) -> void:
	if scene_path == "" or ani_name == "":
		return
	
	if not GameMain or not GameMain.duplicate_node:
		push_error("[CombatEffectManager] GameMain 或 duplicate_node 未初始化")
		return
	
	# 确保场景已预加载
	if not effect_scenes.has(scene_path):
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				effect_scenes[scene_path] = scene
			else:
				push_error("[CombatEffectManager] 无法加载击中特效场景: %s" % scene_path)
				return
		else:
			push_error("[CombatEffectManager] 击中特效场景不存在: %s" % scene_path)
			return
	
	# 从对象池获取实例
	var instance = _get_from_pool(scene_path)
	if instance == null:
		push_warning("[CombatEffectManager] 无法获取击中特效实例: %s" % scene_path)
		return

	var token: int = _get_token(instance)
	
	# 确保从旧父节点移除（避免父节点不一致的问题）
	if instance.get_parent():
		instance.get_parent().remove_child(instance)
	
	# 添加到正确的场景节点
	GameMain.duplicate_node.add_child(instance)
	
	# 设置属性（必须在添加到场景之后）
	instance.global_position = position
	instance.scale = Vector2(scale_val, scale_val)
	instance.z_index = HIT_EFFECT_Z_INDEX
	instance.visible = true
	
	# 查找并播放动画
	var animated_sprite = _find_animated_sprite_in_node(instance)
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(ani_name):
			animated_sprite.play(ani_name)
			# 连接动画完成信号，归还到池
			if not animated_sprite.sprite_frames.get_animation_loop(ani_name):
				animated_sprite.animation_finished.connect(
					func():
						if not is_instance_valid(instance):
							return
						if _get_token(instance) != token:
							return
						_return_to_pool(scene_path, instance),
					CONNECT_ONE_SHOT
				)
			else:
				# 循环动画，延迟归还
				var frame_count = animated_sprite.sprite_frames.get_frame_count(ani_name)
				var anim_speed = animated_sprite.sprite_frames.get_animation_speed(ani_name)
				var duration = frame_count / anim_speed if anim_speed > 0 else 0.5
				_schedule_return_to_pool(scene_path, instance, duration)
		else:
			push_warning("[CombatEffectManager] 击中动画不存在: %s" % ani_name)
			_return_to_pool(scene_path, instance)
	else:
		# 可能是粒子特效
		_start_particle_emitting(instance)
		var max_lifetime = _get_particle_lifetime(instance)
		var cleanup_delay = max_lifetime + 0.3
		_schedule_return_to_pool(scene_path, instance, cleanup_delay)

## 延迟清理节点（兼容旧代码）
static func _delayed_cleanup(instance: Node, delay: float) -> void:
	if not is_instance_valid(instance):
		return
	var tree = instance.get_tree()
	if tree:
		await tree.create_timer(delay).timeout
		if is_instance_valid(instance):
			instance.queue_free()

## 播放特效组（组合特效）
## 
## 同时播放多个特效（序列帧 + 粒子）
## 
## @param effects 特效配置数组，每个元素是一个特效配置字典
## @param position 特效位置
## @param scale_val 缩放倍数
static func play_effect_group(effects: Array, position: Vector2, scale_val: float = 1.0) -> void:
	if not GameMain or not GameMain.animation_scene_obj:
		push_error("[CombatEffectManager] GameMain 或 animation_scene_obj 未初始化")
		return
	
	# 构建特效组数组
	var effect_group = []
	
	for effect_config in effects:
		if not effect_config is Dictionary:
			continue
		
		# 处理粒子特效
		var particles = effect_config.get("particles", [])
		for particle_path in particles:
			if particle_path == "":
				continue
			
			if not effect_scenes.has(particle_path):
				push_warning("[CombatEffectManager] 特效未预加载: %s" % particle_path)
				continue
			
			var scene = effect_scenes[particle_path]
			if scene:
				effect_group.append({
					"particle_scene": scene
				})
		
		# 处理序列帧动画
		var animations = effect_config.get("animations", [])
		for anim_config in animations:
			if anim_config is String:
				# 简单格式：使用默认场景
				effect_group.append({
					"ani_name": anim_config,
					"scene_path": DEFAULT_ANIMATION_SCENE
				})
			elif anim_config is Dictionary:
				# 完整格式：需要加载场景
				var anim_dict = anim_config.duplicate()
				var scene_path = anim_dict.get("scene_path", DEFAULT_ANIMATION_SCENE)
				
				# 如果不是默认场景，需要加载场景对象
				if scene_path != DEFAULT_ANIMATION_SCENE and effect_scenes.has(scene_path):
					anim_dict["animation_scene"] = effect_scenes[scene_path]
				
				effect_group.append(anim_dict)
	
	# 使用 animations.gd 的 run_effect_group 方法
	if GameMain.animation_scene_obj.has_method("run_effect_group"):
		GameMain.animation_scene_obj.run_effect_group({
			"effects": effect_group,
			"position": position,
			"scale": scale_val
		})
	else:
		# 降级方案：分别播放
		for effect in effect_group:
			if effect.has("particle_scene"):
				GameMain.animation_scene_obj.run_particle_effect({
					"particle_scene": effect["particle_scene"],
					"position": position,
					"scale": scale_val
				})
			elif effect.has("ani_name"):
				var scene_path = effect.get("scene_path", DEFAULT_ANIMATION_SCENE)
				var anim_scale = effect.get("scale", scale_val)
				
				if scene_path == DEFAULT_ANIMATION_SCENE:
					GameMain.animation_scene_obj.run_animation({
						"ani_name": effect["ani_name"],
						"position": position,
						"scale": Vector2(anim_scale, anim_scale)
					})
				else:
					# 使用指定场景
					if effect.has("animation_scene"):
						# 场景已经加载并传递
						if GameMain.animation_scene_obj.has_method("run_animation_from_scene"):
							GameMain.animation_scene_obj.run_animation_from_scene({
								"animation_scene": effect["animation_scene"],
								"ani_name": effect["ani_name"],
								"position": position,
								"scale": Vector2(anim_scale, anim_scale)
							})
					elif effect_scenes.has(scene_path):
						# 从预加载的场景字典获取
						var anim_scene = effect_scenes[scene_path]
						if GameMain.animation_scene_obj.has_method("run_animation_from_scene"):
							GameMain.animation_scene_obj.run_animation_from_scene({
								"animation_scene": anim_scene,
								"ani_name": effect["ani_name"],
								"position": position,
								"scale": Vector2(anim_scale, anim_scale)
							})

## 查找 AnimatedSprite2D 节点（递归查找）
static func _find_animated_sprite_in_node(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	
	for child in node.get_children():
		var result = _find_animated_sprite_in_node(child)
		if result:
			return result
	
	return null

## 内部方法：播放特效配置（使用对象池）
static func _play_effect_config(config: Dictionary, position: Vector2, scale_val: float) -> void:
	if not GameMain or not GameMain.duplicate_node:
		push_error("[CombatEffectManager] GameMain 或 duplicate_node 未初始化")
		return
	
	# 播放粒子特效（使用对象池）
	var particles = config.get("particles", [])
	for particle_path in particles:
		if particle_path == "":
			continue
		
		_dprint("[CombatEffectManager] 尝试播放粒子特效: %s" % particle_path)
		
		# 从对象池获取实例
		var instance = _get_from_pool(particle_path)
		if instance == null:
			push_warning("[CombatEffectManager] 无法获取粒子实例: %s" % particle_path)
			continue
		
		# 确保从旧父节点移除（避免父节点不一致的问题）
		if instance.get_parent():
			instance.get_parent().remove_child(instance)
		
		# 添加到正确的场景节点
		GameMain.duplicate_node.add_child(instance)
		
		# 设置位置和缩放（必须在添加到场景之后）
		instance.global_position = position
		instance.scale = Vector2(scale_val, scale_val)
		instance.visible = true
		
		# 启动粒子发射
		_start_particle_emitting(instance)
		
		# 延迟归还到池（粒子播放完毕后）
		var max_lifetime = _get_particle_lifetime(instance)
		var cleanup_delay = max_lifetime + 0.3  # 额外延迟确保完全播放完
		_schedule_return_to_pool(particle_path, instance, cleanup_delay)
	
	# 播放序列帧动画
	var animations = config.get("animations", [])
	for anim_config in animations:
		var scene_path = DEFAULT_ANIMATION_SCENE
		var ani_name = ""
		var anim_scale = scale_val  # 默认使用全局scale
		
		# 支持两种格式：字符串（使用默认场景）或字典（指定场景和scale）
		if anim_config is String:
			# 简单格式：["enemies_dead"] - 使用默认场景
			ani_name = anim_config
			scene_path = DEFAULT_ANIMATION_SCENE
		elif anim_config is Dictionary:
			# 完整格式：{"scene_path": "...", "ani_name": "...", "scale": 1.5}
			scene_path = anim_config.get("scene_path", DEFAULT_ANIMATION_SCENE)
			ani_name = anim_config.get("ani_name", "")
			anim_scale = anim_config.get("scale", scale_val)  # 如果指定了scale，使用指定的
		
		if ani_name == "":
			continue
		
		# 使用 animations.gd 的播放方法（默认场景不使用对象池，由 animations.gd 管理）
		if scene_path == DEFAULT_ANIMATION_SCENE:
			if GameMain.animation_scene_obj:
				GameMain.animation_scene_obj.run_animation({
					"ani_name": ani_name,
					"position": position,
					"scale": Vector2(anim_scale, anim_scale)
				})
		else:
			# 使用指定的场景（使用对象池）
			var instance = _get_from_pool(scene_path)
			if instance == null:
				push_warning("[CombatEffectManager] 无法获取序列帧实例: %s" % scene_path)
				continue
			
			# 确保从旧父节点移除（避免父节点不一致的问题）
			if instance.get_parent():
				instance.get_parent().remove_child(instance)
			
			# 添加到正确的场景节点
			GameMain.duplicate_node.add_child(instance)
			
			# 设置位置和缩放（必须在添加到场景之后）
			instance.global_position = position
			instance.scale = Vector2(anim_scale, anim_scale)
			instance.visible = true
			
			# 查找并播放动画
			var animated_sprite = _find_animated_sprite_in_node(instance)
			if animated_sprite:
				if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(ani_name):
					_dprint("[CombatEffectManager] 播放序列帧动画: %s, 场景: %s" % [ani_name, scene_path])
					animated_sprite.play(ani_name)
					var token: int = _get_token(instance)
					# 连接动画完成信号，归还到池
					if not animated_sprite.sprite_frames.get_animation_loop(ani_name):
						animated_sprite.animation_finished.connect(
							func():
								if not is_instance_valid(instance):
									return
								if _get_token(instance) != token:
									return
								_return_to_pool(scene_path, instance),
							CONNECT_ONE_SHOT
						)
					else:
						# 循环动画，延迟归还
						var frame_count = animated_sprite.sprite_frames.get_frame_count(ani_name)
						var anim_speed = animated_sprite.sprite_frames.get_animation_speed(ani_name)
						var duration = frame_count / anim_speed if anim_speed > 0 else 0.5
						_schedule_return_to_pool(scene_path, instance, duration)
				else:
					push_warning("[CombatEffectManager] 动画不存在: %s" % ani_name)
					_return_to_pool(scene_path, instance)
			else:
				push_warning("[CombatEffectManager] 未找到 AnimatedSprite2D 节点")
				_return_to_pool(scene_path, instance)
