extends CharacterBody2D
class_name EnemyOnline

## 联网模式专用敌人脚本
## 使用 MultiplayerSpawner + MultiplayerSynchronizer 进行同步

var dir = null
var speed = 300
var target = null
var enemyHP = 50  # 当前血量（通过 MultiplayerSynchronizer 同步）
var max_enemyHP = 50  # 最大血量（通过 MultiplayerSynchronizer 同步）

@export var shake_on_death: bool = true
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

## 敌人数据
var enemy_data: EnemyData = null
var enemy_spawner: Node = null
var enemy_id: String = ""  # 敌人类型ID（通过 MultiplayerSynchronizer 同步）

var attack_cooldown: float = 0.0
var attack_interval: float = 1.0
var attack_damage: int = 5

## 击退相关
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 0.9

## 停止距离
var stop_distance: float = 100.0

## 是否为本波最后一个敌人（通过 MultiplayerSynchronizer 同步）
var is_last_enemy_in_wave: bool = false

## 当前波次号（通过 MultiplayerSynchronizer 同步）
var current_wave_number: int = 1

## 是否已经死亡（通过 MultiplayerSynchronizer 同步）
var is_dead: bool = false

## 是否无敌
var is_invincible: bool = false

## 技能行为列表
var behaviors: Array[EnemyBehavior] = []

## Buff系统
var buff_system: BuffSystem = null

## 是否正在flash
var is_flashing: bool = false

## 信号：敌人死亡
signal enemy_killed(enemy_ref: EnemyOnline)

## 目标刷新
var target_refresh_interval: float = 1.0
var _target_refresh_timer: float = 0.0


func _ready() -> void:
	# 初始化Buff系统
	buff_system = BuffSystem.new()
	buff_system.name = "BuffSystem"
	add_child(buff_system)
	buff_system.buff_tick.connect(_on_buff_tick)
	buff_system.buff_applied.connect(_on_buff_applied)
	buff_system.buff_expired.connect(_on_buff_expired)
	
	# 服务器端：数据已经设置好，直接应用
	if NetworkManager.is_server():
		if enemy_data != null:
			_apply_enemy_data()
		# 查找目标玩家
		target = _find_nearest_player()
	else:
		# 客户端：延迟加载敌人数据（等待 MultiplayerSynchronizer 同步）
		call_deferred("_client_init")


## 客户端延迟初始化
func _client_init() -> void:
	# 等待一帧确保同步数据到达
	await get_tree().process_frame
	
	# 根据同步的 enemy_id 加载敌人数据
	if enemy_id != "" and enemy_data == null:
		_apply_enemy_data_by_id()


## 处理Buff Tick
func _on_buff_tick(buff_id: String, tick_data: Dictionary) -> void:
	SpecialEffects.apply_dot_damage(self, tick_data)


## Buff应用时的处理
func _on_buff_applied(buff_id: String) -> void:
	_apply_status_shader(buff_id)


## Buff过期时的处理
func _on_buff_expired(buff_id: String) -> void:
	_remove_status_shader(buff_id)


## 应用状态shader效果
func _apply_status_shader(buff_id: String) -> void:
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var sprite = $AnimatedSprite2D
	var color_config = SpecialEffects.get_status_color_config(buff_id)
	sprite.material.set_shader_parameter("flash_color", color_config["shader_color"])
	sprite.material.set_shader_parameter("flash_opacity", color_config["shader_opacity"])


## 移除状态shader效果
func _remove_status_shader(buff_id: String) -> void:
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	if buff_system:
		var priority_order = ["freeze", "slow", "burn", "bleed", "poison"]
		for status_id in priority_order:
			if buff_system.has_buff(status_id):
				_apply_status_shader(status_id)
				return
	
	var sprite = $AnimatedSprite2D
	sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	sprite.material.set_shader_parameter("flash_opacity", 0.0)


## 检查是否冰冻
func is_frozen() -> bool:
	if not buff_system:
		return false
	return buff_system.has_buff("freeze")


## 获取减速倍数
func get_slow_multiplier() -> float:
	if not buff_system:
		return 1.0
	
	var slow_buff = buff_system.get_buff("slow")
	if not slow_buff or not slow_buff.special_effects.has("slow_multiplier"):
		return 1.0
	
	return slow_buff.special_effects.get("slow_multiplier", 1.0)


## 获取当前最高优先级的异常效果ID
func get_current_status_effect() -> String:
	if not buff_system:
		return ""
	
	var priority_order = ["freeze", "slow", "burn", "bleed", "poison"]
	for status_id in priority_order:
		if buff_system.has_buff(status_id):
			return status_id
	
	return ""


## 确保异常效果shader持续应用
func _ensure_status_shader_applied() -> void:
	if is_flashing:
		return
	
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var current_status = get_current_status_effect()
	if current_status != "":
		var color_config = SpecialEffects.get_status_color_config(current_status)
		var sprite = $AnimatedSprite2D
		var current_color = sprite.material.get_shader_parameter("flash_color")
		var current_opacity = sprite.material.get_shader_parameter("flash_opacity")
		
		if current_color != color_config["shader_color"] or abs(current_opacity - color_config["shader_opacity"]) > 0.01:
			_apply_status_shader(current_status)
	else:
		var sprite = $AnimatedSprite2D
		var current_opacity = sprite.material.get_shader_parameter("flash_opacity")
		if current_opacity > 0.01:
			sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
			sprite.material.set_shader_parameter("flash_opacity", 0.0)


## 初始化敌人（服务器端调用）
func initialize(data: EnemyData, spawner: Node = null) -> void:
	enemy_data = data
	enemy_spawner = spawner
	_apply_enemy_data()


## 根据 enemy_id 加载敌人数据（客户端用）
func _apply_enemy_data_by_id() -> void:
	if enemy_id == "":
		return
	
	enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if enemy_data == null:
		push_error("[EnemyOnline] 无法根据 enemy_id 加载敌人数据: %s" % enemy_id)
		return
	
	_apply_enemy_data()


## 应用敌人数据
func _apply_enemy_data() -> void:
	if enemy_data == null:
		return
	
	# 设置敌人类型ID
	enemy_id = enemy_data.id
	
	# 应用属性（服务器端设置，客户端从同步数据读取）
	if NetworkManager.is_server():
		max_enemyHP = enemy_data.max_hp
		enemyHP = max_enemyHP
	
	attack_damage = enemy_data.attack_damage
	speed = enemy_data.move_speed
	attack_interval = enemy_data.attack_interval
	
	# 应用外观
	self.scale = enemy_data.scale
	
	# 设置动画贴图
	if $AnimatedSprite2D and enemy_data.texture_path != "":
		var texture = load(enemy_data.texture_path)
		if texture:
			var sprite_frames = SpriteFrames.new()
			sprite_frames.set_animation_loop("default", true)
			
			for i in range(enemy_data.frame_count):
				var x = i * enemy_data.frame_width
				var y = 0
				
				var atlas_texture = AtlasTexture.new()
				atlas_texture.atlas = texture
				atlas_texture.region = Rect2(x, y, enemy_data.frame_width, enemy_data.frame_height)
				
				sprite_frames.add_frame("default", atlas_texture)
			
			sprite_frames.set_animation_speed("default", enemy_data.animation_speed)
			
			$AnimatedSprite2D.sprite_frames = sprite_frames
			$AnimatedSprite2D.play("default")
	
	# 应用震动设置
	shake_on_death = enemy_data.shake_on_death
	shake_duration = enemy_data.shake_duration
	shake_amount = enemy_data.shake_amount
	
	# 服务器端初始化技能行为
	if NetworkManager.is_server():
		_setup_skill_behavior()


func _process(delta: float) -> void:
	# 客户端：只处理视觉效果
	if not NetworkManager.is_server():
		_ensure_status_shader_applied()
		_update_facing_direction()
		return
	
	# ========== 以下仅服务器执行 ==========
	
	# 定期刷新目标
	_target_refresh_timer += delta
	if _target_refresh_timer >= target_refresh_interval:
		_target_refresh_timer = 0.0
		target = _find_nearest_player()
	
	# 更新攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# 更新击退速度
	knockback_velocity *= knockback_decay
	if knockback_velocity.length() < 10.0:
		knockback_velocity = Vector2.ZERO
	
	# 持续检查shader
	_ensure_status_shader_applied()
	
	# 更新技能行为
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.update_behavior(delta)
	
	# 检查是否有技能正在控制移动
	var is_skill_controlling_movement = false
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ChargingBehavior:
			var charging = behavior as ChargingBehavior
			if charging.is_charging_now():
				is_skill_controlling_movement = true
				break
	
	# 正常移动逻辑
	if not is_skill_controlling_movement and target:
		if is_frozen():
			velocity = Vector2.ZERO
			move_and_slide()
			return
		
		var player_distance = global_position.distance_to(target.global_position)
		var attack_range_value = enemy_data.attack_range if enemy_data else 80.0
		var min_distance = attack_range_value - 20.0
		
		if player_distance > min_distance:
			dir = (target.global_position - self.global_position).normalized()
			var current_speed = speed * get_slow_multiplier()
			velocity = dir * current_speed + knockback_velocity
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		
		_update_facing_direction()
		
		if player_distance < attack_range_value:
			_attack_player()


## 查找最近的玩家
func _find_nearest_player() -> Node:
	var players = NetworkPlayerManager.players
	if players.is_empty():
		return null
	
	var nearest_player: Node = null
	var nearest_distance: float = INF
	
	for peer_id in players.keys():
		var player = players[peer_id]
		if player and is_instance_valid(player):
			# 跳过 boss 角色
			if player.get("player_role_id") == "boss":
				continue
			
			# 检查玩家是否存活
			if player.get("now_hp") != null and player.now_hp <= 0:
				continue
			
			var distance = global_position.distance_to(player.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_player = player
	
	return nearest_player


## 更新朝向
func _update_facing_direction() -> void:
	if not target or not $AnimatedSprite2D:
		return
	
	var direction_to_player = target.global_position.x - global_position.x
	
	if direction_to_player > 0:
		$AnimatedSprite2D.flip_h = true
	else:
		$AnimatedSprite2D.flip_h = false


## 攻击玩家（仅服务器）
func _attack_player() -> void:
	if attack_cooldown > 0:
		return
	
	if target and target.has_method("player_hurt"):
		# 跳过 boss 角色
		if target.get("player_role_id") == "boss":
			return
		
		target.player_hurt(attack_damage)
		attack_cooldown = attack_interval


## 敌人受伤（外部调用入口）
func enemy_hurt(hurt: int, is_critical: bool = false, attacker_peer_id: int = 0):
	# 只有服务器处理伤害
	if not NetworkManager.is_server():
		return
	
	if enemy_spawner and enemy_spawner.has_method("notify_enemy_hurt"):
		enemy_spawner.notify_enemy_hurt(self, hurt, is_critical, attacker_peer_id)
	
	# 直接应用伤害（服务器端）
	_apply_damage(hurt, is_critical, attacker_peer_id)


## 应用伤害（服务器端）
func _apply_damage(hurt: int, is_critical: bool = false, attacker_peer_id: int = 0):
	if is_dead:
		return
	
	if is_invincible:
		return
	
	# 检查自爆技能
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.trigger_condition == ExplodingBehavior.ExplodeTrigger.LOW_HP:
				var current_hp_percentage = float(self.enemyHP) / float(self.max_enemyHP)
				var new_hp = self.enemyHP - hurt
				var new_hp_percentage = float(new_hp) / float(self.max_enemyHP)
				
				if current_hp_percentage <= exploding.low_hp_threshold or new_hp_percentage <= exploding.low_hp_threshold:
					if exploding.state == ExplodingBehavior.ExplodeState.IDLE:
						exploding._start_countdown()
					self.enemyHP = max(1, new_hp)
					return
	
	self.enemyHP -= hurt
	
	if hurt <= 0:
		return
	
	# 显示伤害跳字（服务器本地）
	_show_damage_text(hurt, is_critical)
	
	enemy_flash()
	CombatEffectManager.play_enemy_hurt(global_position)
	
	if self.enemyHP <= 0:
		enemy_dead()


## 显示伤害数字
func _show_damage_text(damage: int, is_critical: bool) -> void:
	var text_color = Color(1.0, 1.0, 1.0, 1.0)
	if is_critical:
		text_color = Color(0.2, 0.8, 0.8, 1.0)
	
	var text_content = "-" + str(damage)
	if is_critical:
		text_content = "暴击 -" + str(damage)
	
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),
		text_content,
		text_color,
		is_critical
	)


## 显示受伤效果（客户端用）
func show_hurt_effect(damage: int, is_critical: bool = false) -> void:
	_show_damage_text(damage, is_critical)
	enemy_flash()
	CombatEffectManager.play_enemy_hurt(global_position)


## 敌人死亡
func enemy_dead():
	if not NetworkManager.is_server():
		return
	
	if enemy_spawner and enemy_spawner.has_method("notify_enemy_dead"):
		enemy_spawner.notify_enemy_dead(self)
	
	_apply_death()


## 应用死亡（服务器端）
func _apply_death():
	if is_dead:
		return
	
	# 检查自爆倒数状态
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			if exploding.is_in_countdown():
				return
	
	is_dead = true
	
	# 通知自爆技能
	for behavior in behaviors:
		if is_instance_valid(behavior) and behavior is ExplodingBehavior:
			var exploding = behavior as ExplodingBehavior
			exploding.on_enemy_death()
	
	CombatEffectManager.play_enemy_death(global_position)
	
	# 掉落物品
	var item_name = "gold"
	if is_last_enemy_in_wave:
		if current_wave_number % 2 == 1:
			item_name = "masterkey"
	
	NetworkPlayerManager.spawn_drop(item_name, self.global_position)
	
	enemy_killed.emit(self)
	
	if shake_on_death:
		CameraShake.shake(shake_duration, shake_amount)
	
	self.queue_free()


## 显示死亡效果（客户端用）
func show_death_effect() -> void:
	CombatEffectManager.play_enemy_death(global_position)


## 受伤闪烁
func enemy_flash():
	if not $AnimatedSprite2D or not $AnimatedSprite2D.material:
		return
	
	var sprite = $AnimatedSprite2D
	
	var current_status = get_current_status_effect()
	var status_color = Color(1.0, 1.0, 1.0, 1.0)
	var status_opacity = 0.0
	
	if current_status != "":
		var color_config = SpecialEffects.get_status_color_config(current_status)
		status_color = color_config["shader_color"]
		status_opacity = color_config["shader_opacity"]
	
	is_flashing = true
	
	sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	sprite.material.set_shader_parameter("flash_opacity", 1.0)
	
	await get_tree().create_timer(0.1).timeout
	
	if current_status != "":
		sprite.material.set_shader_parameter("flash_color", status_color)
		sprite.material.set_shader_parameter("flash_opacity", status_opacity)
	else:
		sprite.material.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
		sprite.material.set_shader_parameter("flash_opacity", 0.0)
	
	is_flashing = false


## 设置无敌状态
func set_invincible(value: bool) -> void:
	is_invincible = value


## 设置技能行为（服务器端）
func _setup_skill_behavior() -> void:
	if enemy_data == null:
		return
	
	for behavior in behaviors:
		if is_instance_valid(behavior):
			behavior.queue_free()
	behaviors.clear()
	
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
		
		EnemyData.EnemySkillType.NONE:
			pass
