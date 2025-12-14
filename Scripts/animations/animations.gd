extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

'''
options.box 动画父级
options.ani_name 动画名称
options.position 动画生成坐标
options.scale 动画缩放等级
'''

func run_animation(options):
	if !options.has("box"):
		options.box = GameMain.duplicate_node
	var all_ani = self.duplicate()
	options.box.add_child(all_ani)
	all_ani.show()
	all_ani.scale = options.scale if options.has("scale") else Vector2(1,1)
	all_ani.position = options.position
	all_ani.get_node("all_animation").play(options.ani_name)
	pass

## 从指定场景播放序列帧动画
## 
## @param options 选项字典
##   - animation_scene: PackedScene 动画场景（已加载）
##   - ani_name: String 动画名称
##   - position: Vector2 特效位置
##   - scale: Vector2 缩放（可选）
##   - z_index: int 层级（可选，默认不设置）
func run_animation_from_scene(options: Dictionary) -> void:
	if not options.has("animation_scene") or not options.has("ani_name"):
		push_error("[Animations] run_animation_from_scene 缺少 animation_scene 或 ani_name")
		return
	
	var animation_scene = options["animation_scene"]
	var ani_name = options["ani_name"]
	
	if animation_scene == null:
		push_error("[Animations] animation_scene 为空")
		return
	
	# 实例化场景
	var instance = animation_scene.instantiate()
	if instance == null:
		return
	
	var position = options.get("position", Vector2.ZERO)
	var scale_val = options.get("scale", Vector2(1, 1))
	
	instance.global_position = position
	instance.scale = scale_val if scale_val is Vector2 else Vector2(scale_val, scale_val)
	
	# 设置层级（如果指定）
	if options.has("z_index"):
		instance.z_index = options["z_index"]
	
	# 添加到场景树
	var box = options.get("box", GameMain.duplicate_node)
	box.add_child(instance)
	instance.show()
	
	# 播放动画 - 自动查找 AnimatedSprite2D 节点
	var animated_sprite = _find_animated_sprite(instance)
	if animated_sprite:
		print("[Animations] 找到 AnimatedSprite2D 节点，播放动画: %s" % ani_name)
		
		# 检查动画是否存在
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(ani_name):
			animated_sprite.play(ani_name)
			
			# 连接动画完成信号，自动清理（如果动画不是循环的）
			if not animated_sprite.sprite_frames.get_animation_loop(ani_name):
				if not animated_sprite.animation_finished.is_connected(_on_animation_finished.bind(instance)):
					animated_sprite.animation_finished.connect(_on_animation_finished.bind(instance))
			else:
				# 如果是循环动画，需要根据动画时长延迟清理
				var frame_count = animated_sprite.sprite_frames.get_frame_count(ani_name)
				var anim_speed = animated_sprite.sprite_frames.get_animation_speed(ani_name)
				var duration = frame_count / anim_speed if anim_speed > 0 else 2.0
				_auto_cleanup_animation(instance, duration)
		else:
			push_warning("[Animations] 动画不存在: %s" % ani_name)
			instance.queue_free()
	else:
		push_warning("[Animations] 未找到 AnimatedSprite2D 节点")
		instance.queue_free()

## 播放粒子特效
## 
## @param options 选项字典
##   - particle_scene: PackedScene 粒子场景（已加载）
##   - position: Vector2 特效位置
##   - scale: float 缩放（可选）
func run_particle_effect(options: Dictionary) -> void:
	if not options.has("particle_scene"):
		push_error("[Animations] run_particle_effect 缺少 particle_scene")
		return
	
	var particle_scene = options["particle_scene"]
	if particle_scene == null:
		push_error("[Animations] particle_scene 为空")
		return
	
	var instance = particle_scene.instantiate()
	if instance == null:
		return
	
	var position = options.get("position", Vector2.ZERO)
	var scale_val = options.get("scale", 1.0)
	
	instance.global_position = position
	instance.scale = Vector2(scale_val, scale_val)
	
	# 添加到场景树
	var box = options.get("box", GameMain.duplicate_node)
	box.add_child(instance)
	
	# 启动所有粒子发射器
	var particle_found = false
	# 首先检查根节点本身是否是粒子发射器
	if instance is CPUParticles2D or instance is GPUParticles2D:
		instance.emitting = true
		particle_found = true
		print("[Animations] 启动根节点粒子发射器: %s, 位置: %s" % [instance.name, position])
	
	# 然后检查子节点
	for child in instance.get_children():
		if child is CPUParticles2D or child is GPUParticles2D:
			child.emitting = true
			particle_found = true
			print("[Animations] 启动子节点粒子发射器: %s" % child.name)
	
	if not particle_found:
		push_warning("[Animations] 未找到粒子发射器节点！")
	
	# 自动清理
	_auto_cleanup_particle(instance)

## 播放特效组（组合特效）
## 
## 同时播放多个特效（序列帧 + 粒子）
## 
## @param options 选项字典
##   - effects: Array 特效配置数组
##   - position: Vector2 特效位置
##   - scale: float 缩放（可选）
func run_effect_group(options: Dictionary) -> void:
	if not options.has("effects"):
		push_error("[Animations] run_effect_group 缺少 effects")
		return
	
	var effects = options["effects"]
	var position = options.get("position", Vector2.ZERO)
	var scale_val = options.get("scale", 1.0)
	
	for effect in effects:
		if effect is Dictionary:
			# 判断是粒子还是序列帧
			if effect.has("particle_scene"):
				# 粒子特效
				var particle_options = effect.duplicate()
				particle_options["position"] = position
				particle_options["scale"] = scale_val
				run_particle_effect(particle_options)
			elif effect.has("ani_name"):
				# 序列帧动画
				var scene_path = effect.get("scene_path", "")
				var anim_scale = effect.get("scale", scale_val)
				
				if scene_path == "" or scene_path == "res://scenes/animations/animations.tscn":
					# 使用默认场景
					var animation_options = {
						"ani_name": effect["ani_name"],
						"position": position,
						"scale": Vector2(anim_scale, anim_scale)
					}
					run_animation(animation_options)
				else:
					# 使用指定场景（需要从 CombatEffectManager 获取场景）
					# 这里假设场景已经通过其他方式传递
					if effect.has("animation_scene"):
						var animation_options = {
							"animation_scene": effect["animation_scene"],
							"ani_name": effect["ani_name"],
							"position": position,
							"scale": Vector2(anim_scale, anim_scale)
						}
						run_animation_from_scene(animation_options)
					else:
						push_warning("[Animations] 指定了 scene_path 但未提供 animation_scene")

## 查找 AnimatedSprite2D 节点（递归查找）
func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node is AnimatedSprite2D:
		return node
	
	for child in node.get_children():
		var result = _find_animated_sprite(child)
		if result:
			return result
	
	return null

## 动画播放完成回调（用于自定义场景）
func _on_animation_finished(instance: Node) -> void:
	if is_instance_valid(instance):
		instance.queue_free()

## 自动清理动画（用于循环动画）
func _auto_cleanup_animation(instance: Node, duration: float) -> void:
	await Engine.get_main_loop().create_timer(duration).timeout
	if is_instance_valid(instance):
		instance.queue_free()

## 自动清理粒子特效
func _auto_cleanup_particle(instance: Node) -> void:
	var max_lifetime = 0.0
	
	# 首先检查根节点本身是否是粒子发射器
	if instance is CPUParticles2D:
		var total_time = instance.lifetime + instance.explosiveness
		if total_time > max_lifetime:
			max_lifetime = total_time
	elif instance is GPUParticles2D:
		if instance.lifetime > max_lifetime:
			max_lifetime = instance.lifetime
	
	# 然后检查子节点
	for child in instance.get_children():
		if child is CPUParticles2D:
			var total_time = child.lifetime + child.explosiveness
			if total_time > max_lifetime:
				max_lifetime = total_time
		elif child is GPUParticles2D:
			if child.lifetime > max_lifetime:
				max_lifetime = child.lifetime
	
	var cleanup_delay = max_lifetime + 0.5 if max_lifetime > 0 else 2.0
	await Engine.get_main_loop().create_timer(cleanup_delay).timeout
	if is_instance_valid(instance):
		instance.queue_free()

func _on_all_animation_animation_finished() -> void:
	self.queue_free()
	pass # Replace with function body.
