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

## 信号：敌人死亡
signal enemy_killed(enemy_ref: Enemy)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 注意：不再手动加入enemy组，V3系统会直接追踪实例
	
	target = get_tree().get_first_node_in_group("player")
	# 如果已经设置了敌人数据，应用它
	if enemy_data != null:
		_apply_enemy_data()
	pass # Replace with function body.

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
			sprite_frames.add_animation("default")
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
			
			print("[Enemy] 加载动画: ", enemy_data.enemy_name, " 帧数:", enemy_data.frame_count, " FPS:", enemy_data.animation_speed)
	
	# 应用震动设置
	shake_on_death = enemy_data.shake_on_death
	shake_duration = enemy_data.shake_duration
	shake_amount = enemy_data.shake_amount


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
	
	if target:
		## 计算到玩家距离
		# 检查是否接触到玩家（造成伤害）
		# 使用碰撞检测更准确，但如果使用距离检测，确保距离合理
		var player_distance = global_position.distance_to(target.global_position)
		var attack_range_value = enemy_data.attack_range if enemy_data else 80.0
		
		# 设置停止距离（小于攻击范围，确保攻击生效）
		var min_distance = attack_range_value - 20.0  # 攻击范围 + 20像素缓冲
		
		if player_distance > min_distance:
			dir = (target.global_position - self.global_position).normalized()
			#velocity = dir * speed
			# 基础移动速度 + 击退速度
			velocity = dir * speed + knockback_velocity
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
func enemy_hurt(hurt):
	# 如果已经死亡，忽略后续伤害
	if is_dead:
		return
	
	print("[Enemy] 受伤 | HP:", self.enemyHP, " 伤害:", hurt, " 位置:", global_position)
	self.enemyHP -= hurt
	
	# 显示伤害跳字
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),  # 在敌人上方显示
		"-" + str(hurt),
		Color(1.0, 0.3, 0.3)  # 红色伤害数字
	)
	
	enemy_flash()
	GameMain.animation_scene_obj.run_animation({
		"box":self,
		"ani_name":"enemies_hurt",
		"position":Vector2(0,0),
		"scale":Vector2(1,1)
	})
	if self.enemyHP <= 0:
		print("[Enemy] 死亡 | 位置:", global_position)
		enemy_dead()
	pass
func enemy_dead():
	# 防止重复调用
	if is_dead:
		print("[Enemy] 已经死亡，忽略重复调用 | 位置:", global_position)
		return
	
	is_dead = true
	print("[Enemy] enemy_dead() 被调用 | 位置:", global_position)
	
	#GameMain.duplicate_node.global_position = self.global_position
	
	GameMain.animation_scene_obj.run_animation({
		#"box":GameMain.duplicate_node,
		"ani_name":"enemies_dead",
		"position":self.global_position,
		"scale":Vector2(1,1)
	})
	
	# 判断掉落物品类型
	var item_name = "gold"  # 默认掉落金币
	
	if is_last_enemy_in_wave:
		# 最后一只敌人：单数波掉Master Key，双数波掉Gold
		if current_wave_number % 2 == 1:  # 单数波次
			item_name = "masterkey"
		else:  # 双数波次
			item_name = "gold"
	
	print("[Enemy] 准备掉落物品 | 类型:", item_name, " 波次:", current_wave_number, " 位置:", self.global_position)
	GameMain.drop_item_scene_obj.gen_drop_item({
		#"box":GameMain.duplicate_node,
		"ani_name": item_name,
		#"position":Vector2.ZERO,
		"position": self.global_position,
		"scale":Vector2(4,4)
	})
	print("[Enemy] 掉落物品完成")
	
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
	
	print("[Enemy] 准备 queue_free | 位置:", global_position)
	self.queue_free()
	pass

func enemy_flash():
	$AnimatedSprite2D.material.set_shader_parameter("flash_opacity",1)
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material.set_shader_parameter("flash_opacity",0)
	pass
