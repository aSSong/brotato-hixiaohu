extends Node
class_name CombatEffectManager

## 战斗特效管理器
## 
## 统一管理所有战斗相关的视觉特效（粒子、序列帧动画等）
## 支持组合特效（同时播放序列帧动画和粒子特效）
## 所有特效资源在初始化时预加载，避免运行时卡顿
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
	
	# 预留扩展接口示例（未来可以添加）
	# effect_configs["陨石_击中"] = {
	#     "particles": ["res://scenes/effects/meteor_hit_particle.tscn"],
	#     "animations": [{
	#         "scene_path": "res://scenes/animations/meteor_hit.tscn",
	#         "ani_name": "hit",
	#         "scale": 2.0  # 自定义scale
	#     }]
	# }
	# 
	# 组合特效示例（同时播放粒子和序列帧）
	# effect_configs["陨石_爆炸_组合"] = {
	#     "particles": ["res://scenes/effects/meteor_explosion.tscn"],
	#     "animations": [{
	#         "scene_path": "res://scenes/animations/meteor_explosion.tscn",
	#         "ani_name": "explode",
	#         "scale": 1.5
	#     }]
	# }

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
@warning_ignore("unused_parameter")
static func play_hit_effect(_effect_type: EffectType, _position: Vector2, _scale: float = 1.0) -> void:
	# 未来实现
	pass

## ========== 武器特效（场景+动画名模式） ==========

## 播放枪口特效（绑定到父节点，跟随移动）
## 
## @param scene_path 特效场景路径
## @param ani_name 动画名称
## @param parent_node 父节点（特效会作为其子节点，跟随移动）
## @param local_position 相对于父节点的本地位置
## @param rotation 特效旋转角度（弧度，全局方向）
## @param scale 缩放倍数
static func play_muzzle_flash(scene_path: String, ani_name: String, parent_node: Node2D, local_position: Vector2 = Vector2.ZERO, rotation: float = 0.0, scale: float = 1.0) -> void:
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
	
	var anim_scene = effect_scenes[scene_path]
	if anim_scene == null:
		return
	
	# 创建特效实例并作为父节点的子节点
	var instance = anim_scene.instantiate()
	if instance:
		parent_node.add_child(instance)
		instance.position = local_position  # 使用本地坐标
		instance.rotation = rotation - parent_node.global_rotation  # 补偿父节点的旋转
		instance.scale = Vector2(scale, scale)
		instance.show()
		
		# 查找并播放动画
		var animated_sprite = _find_animated_sprite_in_node(instance)
		if animated_sprite:
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(ani_name):
				animated_sprite.play(ani_name)
				# 连接动画完成信号
				if not animated_sprite.sprite_frames.get_animation_loop(ani_name):
					animated_sprite.animation_finished.connect(func(): instance.queue_free())
				else:
					# 循环动画，延迟清理
					var frame_count = animated_sprite.sprite_frames.get_frame_count(ani_name)
					var anim_speed = animated_sprite.sprite_frames.get_animation_speed(ani_name)
					var duration = frame_count / anim_speed if anim_speed > 0 else 0.5
					_delayed_cleanup(instance, duration)
			else:
				push_warning("[CombatEffectManager] 枪口动画不存在: %s" % ani_name)
				instance.queue_free()
		else:
			push_warning("[CombatEffectManager] 未找到 AnimatedSprite2D")
			instance.queue_free()

## 击中特效默认层级（比敌人高，敌人通常在 z_index = 0 ~ 10）
const HIT_EFFECT_Z_INDEX = 50

## 播放子弹击中特效
## 
## @param scene_path 特效场景路径
## @param ani_name 动画名称
## @param position 特效位置
## @param scale 缩放倍数
static func play_bullet_hit(scene_path: String, ani_name: String, position: Vector2, scale: float = 1.0) -> void:
	if scene_path == "" or ani_name == "":
		return
	
	if not GameMain or not GameMain.animation_scene_obj:
		push_error("[CombatEffectManager] GameMain 或 animation_scene_obj 未初始化")
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
	
	var anim_scene = effect_scenes[scene_path]
	if anim_scene == null:
		return
	
	# 使用 run_animation_from_scene 播放，设置较高的 z_index
	if GameMain.animation_scene_obj.has_method("run_animation_from_scene"):
		GameMain.animation_scene_obj.run_animation_from_scene({
			"animation_scene": anim_scene,
			"ani_name": ani_name,
			"position": position,
			"scale": Vector2(scale, scale),
			"z_index": HIT_EFFECT_Z_INDEX  # 设置层级，确保在敌人上方
		})

## 延迟清理节点
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
## @param scale 缩放倍数
static func play_effect_group(effects: Array, position: Vector2, scale: float = 1.0) -> void:
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
			"scale": scale
		})
	else:
		# 降级方案：分别播放
		for effect in effect_group:
			if effect.has("particle_scene"):
				GameMain.animation_scene_obj.run_particle_effect({
					"particle_scene": effect["particle_scene"],
					"position": position,
					"scale": scale
				})
			elif effect.has("ani_name"):
				var scene_path = effect.get("scene_path", DEFAULT_ANIMATION_SCENE)
				var anim_scale = effect.get("scale", scale)
				
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

## 内部方法：播放特效配置
static func _play_effect_config(config: Dictionary, position: Vector2, scale: float) -> void:
	if not GameMain or not GameMain.animation_scene_obj:
		push_error("[CombatEffectManager] GameMain 或 animation_scene_obj 未初始化")
		return
	
	# 播放粒子特效
	var particles = config.get("particles", [])
	# print("[CombatEffectManager] 粒子特效配置数量: %d" % particles.size())
	for particle_path in particles:
		if particle_path == "":
			continue
		
		_dprint("[CombatEffectManager] 尝试播放粒子特效: %s" % particle_path)
		# 从预加载的场景字典获取
		if not effect_scenes.has(particle_path):
			push_warning("[CombatEffectManager] 特效未预加载: %s" % particle_path)
			continue
		
		var scene = effect_scenes[particle_path]
		if scene == null:
			push_error("[CombatEffectManager] 特效场景为空: %s" % particle_path)
			continue
		
		_dprint("[CombatEffectManager] 找到粒子场景，准备播放")
		# 使用 animations.gd 的粒子特效方法
		if GameMain.animation_scene_obj.has_method("run_particle_effect"):
			GameMain.animation_scene_obj.run_particle_effect({
				"particle_scene": scene,
				"position": position,
				"scale": scale
			})
		else:
			push_error("[CombatEffectManager] animation_scene_obj 没有 run_particle_effect 方法")
	
	# 播放序列帧动画
	var animations = config.get("animations", [])
	for anim_config in animations:
		var scene_path = DEFAULT_ANIMATION_SCENE
		var ani_name = ""
		var anim_scale = scale  # 默认使用全局scale
		
		# 支持两种格式：字符串（使用默认场景）或字典（指定场景和scale）
		if anim_config is String:
			# 简单格式：["enemies_dead"] - 使用默认场景
			ani_name = anim_config
			scene_path = DEFAULT_ANIMATION_SCENE
		elif anim_config is Dictionary:
			# 完整格式：{"scene_path": "...", "ani_name": "...", "scale": 1.5}
			scene_path = anim_config.get("scene_path", DEFAULT_ANIMATION_SCENE)
			ani_name = anim_config.get("ani_name", "")
			anim_scale = anim_config.get("scale", scale)  # 如果指定了scale，使用指定的
		
		if ani_name == "":
			continue
		
		# 使用 animations.gd 的播放方法
		if scene_path == DEFAULT_ANIMATION_SCENE:
			# 使用默认场景（GameMain.animation_scene_obj）
			GameMain.animation_scene_obj.run_animation({
				"ani_name": ani_name,
				"position": position,
				"scale": Vector2(anim_scale, anim_scale)
			})
		else:
			# 使用指定的场景
			if not effect_scenes.has(scene_path):
				push_warning("[CombatEffectManager] 序列帧场景未预加载: %s" % scene_path)
				continue
			
			var anim_scene = effect_scenes[scene_path]
			if anim_scene == null:
				push_error("[CombatEffectManager] 序列帧场景为空: %s" % scene_path)
				continue
			
			# 使用支持自定义场景的播放方法
			if GameMain.animation_scene_obj.has_method("run_animation_from_scene"):
				_dprint("[CombatEffectManager] 播放序列帧动画: %s, 场景: %s, 位置: %s" % [ani_name, scene_path, position])
				GameMain.animation_scene_obj.run_animation_from_scene({
					"animation_scene": anim_scene,
					"ani_name": ani_name,
					"position": position,
					"scale": Vector2(anim_scale, anim_scale)
				})
			else:
				# 降级方案：实例化场景并播放
				_dprint("[CombatEffectManager] 使用降级方案播放序列帧动画: %s" % ani_name)
				var anim_instance = anim_scene.instantiate()
				if anim_instance:
					anim_instance.global_position = position
					anim_instance.scale = Vector2(anim_scale, anim_scale)
					GameMain.duplicate_node.add_child(anim_instance)
					anim_instance.show()
					
					# 自动查找 AnimatedSprite2D 节点
					var animated_sprite = _find_animated_sprite_in_node(anim_instance)
					if animated_sprite:
						#_dprint("[CombatEffectManager] 找到 AnimatedSprite2D 节点，播放动画: %s" % ani_name)
						animated_sprite.play(ani_name)
					else:
						push_warning("[CombatEffectManager] 未找到 AnimatedSprite2D 节点")
