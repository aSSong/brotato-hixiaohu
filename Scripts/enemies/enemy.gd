extends CharacterBody2D
class_name Enemy

var dir = null
var speed = 300
var target = null
var enemyHP = 50  # 当前血量
var max_enemyHP = 50

@export var death_particles_scene: PackedScene  # 在 Inspector 拖入粒子场景

@export var shake_on_death: bool = true
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

## 敌人数据
var enemy_data: EnemyData = null

var attack_cooldown: float = 0.0
var attack_interval: float = 1.0  # 攻击间隔（秒）
var attack_damage: int = 5  # 每次攻击造成的伤害

## 击退相关
var knockback_velocity: Vector2 = Vector2.ZERO  # 击退速度
var knockback_decay: float = 0.9  # 击退衰减系数（每帧衰减10%）

## 停止距离（敌人会在这个距离外停下，避免贴脸）
var stop_distance: float = 100.0  # 可以设置为略大于攻击范围

## 是否为本波最后一个敌人（用于掉落masterKey）
var is_last_enemy_in_wave: bool = false

## 当前波次号（用于判断掉落类型）
var current_wave_number: int = 1

## 是否已经死亡（防止重复掉落）
var is_dead: bool = false

## 是否无敌（倒数期间）
var is_invincible: bool = false

## 技能行为列表
var behaviors: Array[EnemyBehavior] = []

## Buff系统（用于处理DoT等效果）
var buff_system: BuffSystem = null

## 是否正在flash（受伤时的白色闪烁）
var is_flashing: bool = false

## 信号：敌人死亡
signal enemy_killed(enemy_ref: Enemy)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 注意：不再手动加入enemy组，V3系统会直接追踪实例
	
	target = get_tree().get_first_node_in_group("player")
	
	# 初始化Buff系统（用于处理DoT伤害）
	buff_system = BuffSystem.new()
	buff_system.name = "BuffSystem"
	add_child(buff_system)
	buff_system.buff_tick.connect(_on_buff_tick)
	buff_system.buff_applied.connect(_on_buff_applied)
	buff_system.buff_expired.connect(_on_buff_expired)
	
	# 如果已经设置了敌人数据，应用它
	if enemy_data != null:
		_apply_enemy_data()
	pass # Replace with function body.

## 处理Buff Tick（DoT伤害）
func _on_buff_tick(buff_id: String, tick_data: Dictionary) -> void:
	SpecialEffects.apply_dot_damage(self, tick_data)

## Buff应用时的处理（应用shader效果）
func _on_buff_applied(buff_id: String) -> void:
	_apply_status_shader(buff_id)

## Buff过期时的处理（移除shader效果）
func _on_buff_expired(buff_id: String) -> void:
	_remove_status_shader(buff_id)

## 应用状态shader效果
func _apply_status_shader(buff_id: String) -> void:
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var sprite = $AnimatedSprite2D
	var color_config = SpecialEffects.get_status_color_config(buff_id)
	
	# 使用统一配置的颜色和透明度
	sprite.material.set_shader_parameter("flash_color", color_config["shader_color"])
	sprite.material.set_shader_parameter("flash_opacity", color_config["shader_opacity"])

## 移除状态shader效果
func _remove_status_shader(buff_id: String) -> void:
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	# 检查是否还有其他状态效果，按优先级应用
	# 优先级：freeze > slow > burn > bleed > poison
	if buff_system:
		var priority_order = ["freeze", "slow", "burn", "bleed", "poison"]
		for status_id in priority_order:
			if buff_system.has_buff(status_id):
				# 应用优先级最高的状态效果
				_apply_status_shader(status_id)
				return
	
	# 如果没有其他状态效果，恢复原状
	var sprite = $AnimatedSprite2D
	sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	sprite.material.set_shader_parameter("flash_opacity", 0.0)

## 检查是否有冰冻Buff（无法移动）
func is_frozen() -> bool:
	if not buff_system:
		return false
	return buff_system.has_buff("freeze")

## 获取减速倍数（从slow Buff）
func get_slow_multiplier() -> float:
	if not buff_system:
		return 1.0
	
	var slow_buff = buff_system.get_buff("slow")
	if not slow_buff or not slow_buff.special_effects.has("slow_multiplier"):
		return 1.0
	
	return slow_buff.special_effects.get("slow_multiplier", 1.0)

## 获取当前最高优先级的异常效果ID
## 
## @return 异常效果ID，如果没有则返回空字符串
func get_current_status_effect() -> String:
	if not buff_system:
		return ""
	
	# 优先级：freeze > slow > burn > bleed > poison
	var priority_order = ["freeze", "slow", "burn", "bleed", "poison"]
	for status_id in priority_order:
		if buff_system.has_buff(status_id):
			return status_id
	
	return ""

## 确保异常效果的shader持续应用（在_process中调用）
func _ensure_status_shader_applied() -> void:
	# 如果正在flash（受伤时的白色闪烁），不处理，等待flash完成
	if is_flashing:
		return
	
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var current_status = get_current_status_effect()
	if current_status != "":
		# 检查当前shader是否匹配异常效果
		var color_config = SpecialEffects.get_status_color_config(current_status)
		var sprite = $AnimatedSprite2D
		var current_color = sprite.material.get_shader_parameter("flash_color")
		var current_opacity = sprite.material.get_shader_parameter("flash_opacity")
		
		# 如果shader不匹配，重新应用
		if current_color != color_config["shader_color"] or abs(current_opacity - color_config["shader_opacity"]) > 0.01:
			_apply_status_shader(current_status)
	else:
		# 没有异常效果，确保shader是正常状态
		var sprite = $AnimatedSprite2D
		var current_opacity = sprite.material.get_shader_parameter("flash_opacity")
		# 只有在有shader效果时才恢复（避免频繁设置）
		if current_opacity > 0.01:
			sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
			sprite.material.set_shader_parameter("flash_opacity", 0.0)

## 初始化敌人（从敌人数据）
func initialize(data: EnemyData) -> void:
	enemy_data = data
	_apply_enemy_data()

## 应用敌人数据
func _apply_enemy_data() -> void:
	if enemy_data == null:
		return
	
	# 应用属性
	max_enemyHP = enemy_data.max_hp
	enemyHP = max_enemyHP
	attack_damage = enemy_data.attack_damage
	speed = enemy_data.move_speed
	attack_interval = enemy_data.attack_interval
	
	# 应用外观
	self.scale = enemy_data.scale
	
	# 设置动画贴图（支持多帧）
	if $AnimatedSprite2D and enemy_data.texture_path != "":
		var texture = load(enemy_data.texture_path)
		if texture:
			# 创建SpriteFrames
			var sprite_frames = SpriteFrames.new()
			#sprite_frames.add_animation("default")
			sprite_frames.set_animation_loop("default", true)
			
			# 添加所有帧（单行横向排列）
			for i in range(enemy_data.frame_count):
				var x = i * enemy_data.frame_width
				var y = 0  # 单行，y始终为0
				
				# 创建AtlasTexture
				var atlas_texture = AtlasTexture.new()
				atlas_texture.atlas = texture
				atlas_texture.region = Rect2(x, y, enemy_data.frame_width, enemy_data.frame_height)
				
				sprite_frames.add_frame("default", atlas_texture)
			
			# 设置动画速度
			sprite_frames.set_animation_speed("default", enemy_data.animation_speed)
			
			$AnimatedSprite2D.sprite_frames = sprite_frames
			$AnimatedSprite2D.play("default")
			
			#print("[Enemy] 加载动画: ", enemy_data.enemy_name, " 帧数:", enemy_data.frame_count, " FPS:", enemy_data.animation_speed)
	
	# 应用震动设置
	shake_on_death = enemy_data.shake_on_death
	shake_duration = enemy_data.shake_duration
	shake_amount = enemy_data.shake_amount
	
	# 初始化技能行为
	_setup_skill_behavior()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 更新攻击冷却时间
	if attack_cooldown > 0:
		attack_cooldown -= delta
		
	# 更新击退速度（逐渐衰减）
	knockback_velocity *= knockback_decay
	# 如果击退速度很小，直接清零
	if knockback_velocity.length() < 10.0:
		knockback_velocity = Vector2.ZERO
	
	# 持续检查并应用异常效果的shader（确保在整个duration期间都保持）
	_ensure_status_shader_applied()
	
	# 更新技能行为
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.update_behavior(delta)
	
	# 检查是否有技能正在控制移动（如冲锋）
	var is_skill_controlling_movement = false
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			if charging.is_charging_now():
				is_skill_controlling_movement = true
				break
	
	# 如果没有技能控制移动，执行正常移动逻辑
	if not is_skill_controlling_movement and target:
		# 检查冰冻状态（无法移动）
		if is_frozen():
			velocity = Vector2.ZERO
			move_and_slide()
			return
		
		## 计算到玩家距离
		# 检查是否接触到玩家（造成伤害）
		# 使用碰撞检测更准确，但如果使用距离检测，确保距离合理
		var player_distance = global_position.distance_to(target.global_position)
		var attack_range_value = enemy_data.attack_range if enemy_data else 80.0
		
		# 设置停止距离（小于攻击范围，确保攻击生效）
		var min_distance = attack_range_value - 20.0  # 攻击范围 + 20像素缓冲
		
		if player_distance > min_distance:
			dir = (target.global_position - self.global_position).normalized()
			# 应用减速效果
			var current_speed = speed * get_slow_multiplier()
			# 基础移动速度 + 击退速度
			velocity = dir * current_speed + knockback_velocity
		else:
			# 距离足够近，停止移动
			velocity = Vector2.ZERO
		move_and_slide()
		
		# 朝向修正：图片默认向左，当玩家在右侧时翻转
		_update_facing_direction()
		
		# 检查是否在攻击范围内（造成伤害）
		if player_distance < attack_range_value:  # 接触距离
			_attack_player()
	pass

## 更新敌人朝向
func _update_facing_direction() -> void:
	if not target or not $AnimatedSprite2D:
		return
	
	# 计算玩家相对于敌人的位置
	var direction_to_player = target.global_position.x - global_position.x
	
	# 图片默认向左（flip_h = false）
	# 当玩家在右侧时（direction_to_player > 0），翻转图片
	if direction_to_player > 0:
		$AnimatedSprite2D.flip_h = true  # 翻转，朝右
	else:
		$AnimatedSprite2D.flip_h = false  # 不翻转，朝左（默认）

func _attack_player() -> void:
	if attack_cooldown > 0:
		return
	
	if target and target.has_method("player_hurt"):
		target.player_hurt(attack_damage)
		attack_cooldown = attack_interval
func enemy_hurt(hurt, is_critical: bool = false):
	# 如果已经死亡，忽略后续伤害
	if is_dead:
		return
	
	# 如果无敌（如自爆倒数期间），忽略伤害
	if is_invincible:
		return
	
	# 检查是否有自爆技能，如果这次伤害会导致HP降到阈值以下，先触发自爆
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.trigger_condition == ExplodingBehavior.ExplodeTrigger.LOW_HP:
				# 检查当前HP是否已经低于阈值，或者这次伤害会导致HP降到阈值以下
				var current_hp_percentage = float(self.enemyHP) / float(self.max_enemyHP)
				var new_hp = self.enemyHP - hurt
				var new_hp_percentage = float(new_hp) / float(self.max_enemyHP)
				
				# 如果当前HP已经低于阈值，或者这次伤害会导致HP降到阈值以下
				if current_hp_percentage <= exploding.low_hp_threshold or new_hp_percentage <= exploding.low_hp_threshold:
					# 先触发自爆（如果还没开始倒数）
					if exploding.state == ExplodingBehavior.ExplodeState.IDLE:
						exploding._start_countdown()
					# 设置HP为1，确保不会立即死亡（但允许触发自爆）
					self.enemyHP = max(1, new_hp)
					return
	
	#print("[Enemy] 受伤 | HP:", self.enemyHP, " 伤害:", hurt, " 位置:", global_position)
	self.enemyHP -= hurt
	
	# 确定伤害数字颜色
	var text_color = Color(1.0, 1.0, 1.0, 1.0)  # 伤害数字
	if is_critical:
		text_color = Color(0.2, 0.8, 0.8, 1.0)  # 表示暴击
	
	# 忽略0伤害
	if hurt <= 0:
		return

	# 显示伤害跳字
	var text_content = "-" + str(hurt)
	if is_critical:
		text_content = "暴击 -" + str(hurt)
		
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),  # 在敌人上方显示
		text_content,
		text_color,
		is_critical
	)
	
	enemy_flash()
	# 使用统一的特效管理器
	CombatEffectManager.play_enemy_hurt(global_position)
	if self.enemyHP <= 0:
		#print("[Enemy] 死亡 | 位置:", global_position)
		enemy_dead()
	pass
func enemy_dead():
	# 防止重复调用
	if is_dead:
		#print("[Enemy] 已经死亡，忽略重复调用 | 位置:", global_position)
		return
	
	# 检查是否在自爆倒数状态（如果是，不立即死亡）
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.is_in_countdown():
				# 在倒数状态，不立即死亡，等待爆炸
				#print("[Enemy] 在自爆倒数状态，延迟死亡")
				return
	
	is_dead = true
	#print("[Enemy] enemy_dead() 被调用 | 位置:", global_position)
	
	# 通知技能行为敌人死亡（用于自爆技能的ON_DEATH触发）
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.on_enemy_death()
	
	# 使用统一的特效管理器
	CombatEffectManager.play_enemy_death(global_position)
	
	# 判断掉落物品类型
	var item_name = "gold"  # 默认掉落金币
	
	if is_last_enemy_in_wave:
		# 最后一只敌人：单数波掉Master Key，双数波掉Gold
		if current_wave_number % 2 == 1:  # 单数波次
			item_name = "masterkey"
		else:  # 双数波次
			item_name = "gold"
	
	#print("[Enemy] 准备掉落物品 | 类型:", item_name, " 波次:", current_wave_number, " 位置:", self.global_position)
	GameMain.drop_item_scene_obj.gen_drop_item({
		#"box":GameMain.duplicate_node,
		"ani_name": item_name,
		#"position":Vector2.ZERO,
		"position": self.global_position,
		"scale":Vector2(4,4)
	})
	#print("[Enemy] 掉落物品完成")
	
	# 发送敌人死亡信号（在queue_free之前）
	enemy_killed.emit(self)
	
	# 振屏
	if shake_on_death:
		CameraShake.shake(shake_duration, shake_amount)
	# 生成粒子特效
	if death_particles_scene != null:
		var particles = death_particles_scene.instantiate()
		particles.global_position = global_position
		# 添加到场景根节点,不随怪物一起消失
		get_tree().root.add_child(particles)
	
	#print("[Enemy] 准备 queue_free | 位置:", global_position)
	self.queue_free()
	pass

func enemy_flash():
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var sprite = $AnimatedSprite2D
	
	# 保存当前异常效果的shader颜色（如果有）
	var current_status = get_current_status_effect()
	var status_color = Color(1.0, 1.0, 1.0, 1.0)
	var status_opacity = 0.0
	
	if current_status != "":
		var color_config = SpecialEffects.get_status_color_config(current_status)
		status_color = color_config["shader_color"]
		status_opacity = color_config["shader_opacity"]
	
	# 标记正在flash
	is_flashing = true
	
	# 白色flash效果（受伤时）
	sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	sprite.material.set_shader_parameter("flash_opacity", 1.0)
	
	# 等待0.1秒
	await get_tree().create_timer(0.1).timeout
	
	# 恢复异常效果的shader（如果有），否则恢复原状
	if current_status != "":
		sprite.material.set_shader_parameter("flash_color", status_color)
		sprite.material.set_shader_parameter("flash_opacity", status_opacity)
	else:
		sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
		sprite.material.set_shader_parameter("flash_opacity", 0.0)
	
	# 取消flash标记
	is_flashing = false

## 设置无敌状态
func set_invincible(value: bool) -> void:
	is_invincible = value
	#print("[Enemy] 无敌状态:", value)

## 设置技能行为
func _setup_skill_behavior() -> void:
	if enemy_data == null:
		return
	
	# 清理旧的技能行为
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.queue_free()
	behaviors.clear()
	
	# 根据技能类型创建技能行为
	match enemy_data.skill_type:
		EnemyData.EnemySkillType.CHARGING:
			var charging = ChargingBehavior.new()
			add_child(charging)
			charging.initialize(self, enemy_data.skill_config)
			behaviors.append(charging)
			#print("[Enemy] 添加冲锋技能行为")
		
		EnemyData.EnemySkillType.SHOOTING:
			var shooting = ShootingBehavior.new()
			add_child(shooting)
			shooting.initialize(self, enemy_data.skill_config)
			behaviors.append(shooting)
			#print("[Enemy] 添加射击技能行为")
		
		EnemyData.EnemySkillType.EXPLODING:
			var exploding = ExplodingBehavior.new()
			add_child(exploding)
			exploding.initialize(self, enemy_data.skill_config)
			behaviors.append(exploding)
			#print("[Enemy] 添加自爆技能行为")
		
		EnemyData.EnemySkillType.NONE:
			pass  # 无技能
