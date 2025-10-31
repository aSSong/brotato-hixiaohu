extends CharacterBody2D
var dir = null
var speed = 300
var target = null
var enemyHP = 50  # 增加血量
var max_enemyHP = 50

@export var death_particles_scene: PackedScene  # 在 Inspector 拖入粒子场景

@export var shake_on_death: bool = true
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	pass # Replace with function body.


var attack_cooldown: float = 0.0
var attack_interval: float = 1.0  # 攻击间隔（秒）
var attack_damage: int = 5  # 每次攻击造成的伤害

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 更新攻击冷却时间
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if target:
		dir = (target.global_position - self.global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		
		# 检查是否接触到玩家（造成伤害）
		# 使用碰撞检测更准确，但如果使用距离检测，确保距离合理
		var player_distance = global_position.distance_to(target.global_position)
		if player_distance < 80.0:  # 接触距离（稍微增大一点确保能触发）
			_attack_player()
	pass

func _attack_player() -> void:
	if attack_cooldown > 0:
		return
	
	if target and target.has_method("player_hurt"):
		target.player_hurt(attack_damage)
		attack_cooldown = attack_interval
func enemy_hurt(hurt):
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
		enemy_dead()
	pass
func enemy_dead():
	#GameMain.duplicate_node.global_position = self.global_position
	
	GameMain.animation_scene_obj.run_animation({
		#"box":GameMain.duplicate_node,
		"ani_name":"enemies_dead",
		"position":self.global_position,
		"scale":Vector2(1,1)
	})
	
	GameMain.drop_item_scene_obj.gen_drop_item({
		#"box":GameMain.duplicate_node,
		"ani_name":"gold",
		#"position":Vector2.ZERO,
		"position": self.global_position,
		"scale":Vector2(4,4)
	})
	
	# 振屏
	if shake_on_death:
		CameraShake.shake(shake_duration, shake_amount)
	# 生成粒子特效
	if death_particles_scene != null:
		var particles = death_particles_scene.instantiate()
		particles.global_position = global_position
		# 添加到场景根节点,不随怪物一起消失
		get_tree().root.add_child(particles)
	
	self.queue_free()
	pass

func enemy_flash():
	$AnimatedSprite2D.material.set_shader_parameter("flash_opacity",1)
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material.set_shader_parameter("flash_opacity",0)
	pass
