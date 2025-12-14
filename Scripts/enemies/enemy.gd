extends CharacterBody2D
class_name Enemy

## 调试显示开关（全局静态变量，按 R键 切换）
static var debug_show_range: bool = false

var dir = null
var speed = 300
var target = null
var enemyHP = 50  # 当前血量
var max_enemyHP = 50

@export var shake_on_death: bool = true
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

## 敌人数据
var enemy_data: EnemyData = null

## 敌人 ID（用于识别敌人类型，如 "ent"、"monitor" 等）
var enemy_id: String = ""

var attack_cooldown: float = 0.0
var attack_interval: float = 1.0  # 攻击间隔（秒）
var attack_damage: int = 5  # 每次攻击造成的伤害

## 击退相关
var knockback_velocity: Vector2 = Vector2.ZERO  # 击退速度
var knockback_decay: float = 0.9  # 击退衰减系数（每帧衰减10%）
var knockback_resistance: float = 0.0  # 击退抗性（0-1，1表示完全免疫）

## 金币掉落数量
var gold_drop_count: int = 1

## 停止距离（敌人会在这个距离外停下，避免贴脸）
var stop_distance: float = 100.0  # 可以设置为略大于攻击范围

## 软分离配置（防止敌人完全重叠）
var separation_radius: float = 60.0  # 分离检测半径
var separation_strength: float = 120.0  # 分离力度

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

## ==================== 调试可视化 ====================

## 处理按键输入（R键 切换显示攻击范围）
func _unhandled_input(event: InputEvent) -> void:
	# 只在调试版本中启用
	if not OS.is_debug_build():
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		debug_show_range = !debug_show_range
		print("[Debug] 攻击范围显示: ", "开启" if debug_show_range else "关闭")
		# 通知所有敌人重绘
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy):
				enemy.queue_redraw()

## 绘制调试图形（攻击范围、追踪停止距离）
func _draw() -> void:
	# 只在调试版本中绘制
	if not OS.is_debug_build() or not debug_show_range:
		return
	
	var attack_range_value = enemy_data.attack_range if enemy_data else 80.0
	var min_chase_distance = attack_range_value - 20.0
	
	# 考虑节点缩放（绘制时需要反向补偿）
	var current_scale = scale.x if scale.x != 0 else 1.0
	var draw_attack_range = attack_range_value / current_scale
	var draw_chase_distance = min_chase_distance / current_scale
	
	# 绘制攻击范围（红色圆圈）
	draw_arc(Vector2.ZERO, draw_attack_range, 0, TAU, 32, Color.RED, 2.0)
	
	# 绘制停止追踪距离（黄色圆圈）
	draw_arc(Vector2.ZERO, draw_chase_distance, 0, TAU, 32, Color.YELLOW, 1.5)

## ==================== 生命周期函数 ====================

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
	
	# 播放默认走路动画
	play_animation("walk")

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

## 应用敌人数据（只应用数值属性，不处理动画）
func _apply_enemy_data() -> void:
	if enemy_data == null:
		return
	
	# 应用数值属性
	max_enemyHP = enemy_data.max_hp
	enemyHP = max_enemyHP
	attack_damage = enemy_data.attack_damage
	speed = enemy_data.move_speed
	attack_interval = enemy_data.attack_interval
	
	# 应用震动设置
	shake_on_death = enemy_data.shake_on_death
	shake_duration = enemy_data.shake_duration
	shake_amount = enemy_data.shake_amount
	
	# 应用击退抗性和掉落设置
	knockback_resistance = enemy_data.knockback_resistance
	gold_drop_count = enemy_data.gold_drop_count
	
	# 应用缩放（在场景原始scale基础上叠加）
	self.scale *= enemy_data.scale
	
	# 初始化技能行为
	_setup_skill_behavior()

## 播放指定动画（供 behavior 调用）
## 
## @param anim_key 逻辑动画名（walk/idle/attack/hurt/skill_prepare/skill_execute）
func play_animation(anim_key: String) -> void:
	if not $AnimatedSprite2D:
		return
	
	# 从 enemy_data 获取实际动画名
	var anim_name = anim_key  # 默认使用原名
	if enemy_data and enemy_data.animations.has(anim_key):
		var mapped_name = enemy_data.animations.get(anim_key, "")
		if mapped_name != "" and mapped_name != null:
			anim_name = mapped_name
		else:
			return  # 该敌人没有配置这个动画
	
	# 检查 SpriteFrames 是否有这个动画
	if $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation(anim_name):
		$AnimatedSprite2D.play(anim_name)

## 播放 AnimationPlayer 动画（技能动作）
## 
## @param anim_name AnimationPlayer 中的动画名
func play_skill_animation(anim_name: String) -> void:
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

## 停止 AnimationPlayer 动画
func stop_skill_animation() -> void:
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.stop()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 调试模式下持续重绘（仅调试版本）
	if OS.is_debug_build() and debug_show_range:
		queue_redraw()
	
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
	
	# 检查是否有技能正在控制移动（如冲锋、Boss射击）
	var is_skill_controlling_movement = false
	for behavior in behaviors:
		if is_instance_valid(behavior):
			if behavior is ChargingBehavior:
				var charging = behavior as ChargingBehavior
				if charging.is_charging_now():
					is_skill_controlling_movement = true
					break
			elif behavior is BossShootingBehavior:
				var boss_shooting = behavior as BossShootingBehavior
				if boss_shooting.is_skill_active():
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
		
		# 计算分离力（防止敌人重叠）
		var separation = _calculate_separation_force()
		
		if player_distance > min_distance:
			dir = (target.global_position - self.global_position).normalized()
			# 应用减速效果
			var current_speed = speed * get_slow_multiplier()
			# 基础移动速度 + 击退速度 + 分离力
			velocity = dir * current_speed + knockback_velocity + separation
		else:
			# 距离足够近，停止追踪但仍应用分离力
			velocity = separation
		move_and_slide()
		
		# 朝向修正：图片默认向左，当玩家在右侧时翻转
		_update_facing_direction()
		
		# 检查是否在攻击范围内（造成伤害）
		if player_distance < attack_range_value:  # 接触距离
			_attack_player()

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

## 计算软分离力（防止敌人完全重叠）
func _calculate_separation_force() -> Vector2:
	var separation_force = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	for other in enemies:
		if other == self or not is_instance_valid(other):
			continue
		var to_other = other.global_position - global_position
		var distance = to_other.length()
		if distance < separation_radius and distance > 0.1:
			var strength = (separation_radius - distance) / separation_radius
			separation_force += -to_other.normalized() * strength * separation_strength
	
	return separation_force

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
	
	# 保险：只要触发伤害，最小值为1
	# 如果原始伤害 > 0，确保最终伤害至少为1
	if hurt > 0:
		hurt = max(1, hurt)
	else:
		# 如果伤害 <= 0，直接返回（不造成伤害）
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
	
	self.enemyHP -= hurt
	
	# 确定伤害数字颜色
	var text_color = Color(1.0, 1.0, 1.0, 1.0)  # 伤害数字
	if is_critical:
		text_color = Color(0.2, 0.8, 0.8, 1.0)  # 表示暴击

	# 显示伤害跳字
	var text_content = str(hurt)
	if is_critical:
		text_content = "暴击 " + str(hurt)
		
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
		enemy_dead()

func enemy_dead():
	# 防止重复调用
	if is_dead:
		return
	
	# 检查是否在自爆倒数状态（如果是，不立即死亡）
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.is_in_countdown():
				# 在倒数状态，不立即死亡，等待爆炸
				return
	
	is_dead = true
	
	# 通知技能行为敌人死亡（用于自爆技能的ON_DEATH触发）
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.on_enemy_death()
	
	# 使用统一的特效管理器
	CombatEffectManager.play_enemy_death(global_position)
	
	# 判断掉落物品类型
	if is_last_enemy_in_wave:
		# 掉落 masterkey（只掉一个，不受 gold_drop_count 影响）
		GameMain.drop_item_scene_obj.gen_drop_item({
			"ani_name": "masterkey",
			"position": self.global_position,
			"scale": Vector2(4, 4)
		})
	else:
		# 掉落 gold，根据 gold_drop_count 掉落多个
		for i in range(gold_drop_count):
			# 添加随机偏移，防止多个金币重叠
			var offset = Vector2.ZERO
			if gold_drop_count > 1:
				var angle = randf() * TAU  # 0 到 2π 的随机角度
				var distance = randf_range(15.0, 35.0)  # 随机距离
				offset = Vector2(cos(angle), sin(angle)) * distance
			
			GameMain.drop_item_scene_obj.gen_drop_item({
				"ani_name": "gold",
				"position": self.global_position + offset,
				"scale": Vector2(4, 4)
			})
	
	# 发送敌人死亡信号（在queue_free之前）
	enemy_killed.emit(self)
	
	# 振屏
	if shake_on_death:
		CameraShake.shake(shake_duration, shake_amount)
	
	self.queue_free()

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

## 应用击退（考虑击退抗性）
## @param knockback_force 击退力向量
func apply_knockback(knockback_force: Vector2) -> void:
	# 根据击退抗性减少击退力
	var resistance_multiplier = 1.0 - knockback_resistance
	knockback_velocity += knockback_force * resistance_multiplier

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
		
		EnemyData.EnemySkillType.SHOOTING:
			var shooting = ShootingBehavior.new()
			add_child(shooting)
			shooting.initialize(self, enemy_data.skill_config)
			behaviors.append(shooting)
		
		EnemyData.EnemySkillType.EXPLODING:
			var exploding = ExplodingBehavior.new()
			add_child(exploding)
			exploding.initialize(self, enemy_data.skill_config)
			behaviors.append(exploding)
		
		EnemyData.EnemySkillType.BOSS_SHOOTING:
			var boss_shooting = BossShootingBehavior.new()
			add_child(boss_shooting)
			boss_shooting.initialize(self, enemy_data.skill_config)
			behaviors.append(boss_shooting)
		
		EnemyData.EnemySkillType.NONE:
			pass  # 无技能
