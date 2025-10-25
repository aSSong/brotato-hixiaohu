extends Node2D
@onready var weaponAni: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_pos: Marker2D = $shoot_pos
@onready var timer: Timer = $Timer
@onready var bullet  = preload("res://scenes/bullets/bullet.tscn")


var bullet_shoot_time = 0.5
var bullet_speed = 2000
var bullet_hurt = 1

const weapon_level ={
	level_1 = "#b0c3d9",
	level_2 = "#4b69ff",
	level_3 = "#d32ce6",
	level_4 = "#8847ff",
	level_5 = "#eb4b4b",
}

var attack_enemies = []

func _ready() -> void:
	var ran = RandomNumberGenerator.new()
	#var metarialTemp = weaponAni.material.duplicate()
	#weaponAni.material = metarialTemp
	weaponAni.material.set_shader_parameter("color",Color(weapon_level['level_'+str(ran.randi_range(1,5))]))
	pass
func _process(delta: float) -> void:
	if attack_enemies.size() != 0 :
		self.look_at(attack_enemies[0].position)
	else:
		rotation_degrees = 0

func _on_timer_timeout() -> void:
	if attack_enemies.is_empty(): return
	var b = bullet.instantiate()
	get_tree().root.add_child(b)
	b.start(
		shoot_pos.global_position,
		(attack_enemies[0].global_position - shoot_pos.global_position).normalized(),
		bullet_speed,
		bullet_hurt
	)
	pass # Replace with function body.


func _on_area_2d_body_entered(body) -> void:
	if body.is_in_group("enemy") and !attack_enemies.has(body):
		attack_enemies.append(body)
	sort_enemy()
	pass # Replace with function body.


func _on_area_2d_body_exited(body) -> void:
	if body.is_in_group("enemy") and attack_enemies.has(body):
		#attack_enemies.remove_at(attack_enemies.find(body))
		attack_enemies.erase(body)
	sort_enemy()
	pass # Replace with function body.

func sort_enemy():
	if attack_enemies.size() !=0:
		attack_enemies.sort_custom(
			func(x,y):
				return x.global_position.distance_to(self.global_position) < y.global_position.distance_to(self.global_position)
		)
	
	pass
