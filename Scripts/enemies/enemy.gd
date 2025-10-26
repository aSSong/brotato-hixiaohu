extends CharacterBody2D
var dir = null
var speed = 300
var target = null
var enemyHP = 3

@export var death_particles_scene: PackedScene  # 在 Inspector 拖入粒子场景

@export var shake_on_death: bool = true
@export var shake_duration: float = 0.2
@export var shake_amount: float = 8.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target:
		dir = (target.global_position - self.global_position).normalized()
		velocity = dir * speed
		move_and_slide()
	pass
func enemy_hurt(hurt):
	self.enemyHP -= hurt
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
