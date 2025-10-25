extends CharacterBody2D
@onready var playerAni: AnimatedSprite2D = %AnimatedSprite2D

var dir = Vector2.ZERO
var speed = 400
var flip =false
var canMove = true
var stop = false

func _ready() -> void:
	choosePlayer("player2")
	pass

func choosePlayer(type):
	var player_path = "res://assets/player/"
	
	playerAni.sprite_frames.clear_all()
	
	var sprite_frame_custom = SpriteFrames.new()
	sprite_frame_custom.add_animation("default")
	sprite_frame_custom.set_animation_loop("default",true)
	var texture_size = Vector2(960,240)
	var sprite_size = Vector2(240,240)
	var full_texture : Texture = load(player_path + type + "-sheet.png")
	
	var num_columns = int(texture_size.x / sprite_size.x )
	var num_row = int(texture_size.y / sprite_size.y )
	
	for x in range(num_columns):
		for y in range(num_row):
			var frame = AtlasTexture.new()
			frame.atlas = full_texture
			frame.region = Rect2(Vector2(x,y) * sprite_size,sprite_size)
			sprite_frame_custom.add_frame("default",frame)
	playerAni.sprite_frames = sprite_frame_custom
	playerAni.play("default")
	pass

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var self_pos = position
	
	if mouse_pos.x > self_pos.x:
		flip = false
	else:
		flip = true
	
	playerAni.flip_h = flip
	
	dir = (mouse_pos - self_pos).normalized()
	
	if canMove and !stop:
		velocity = dir * speed
		#移动
		move_and_slide()	
	pass
	
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		canMove = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.is_pressed():
		canMove = true
		
	


func _on_stop_mouse_entered() -> void:
	stop = true
	

func _on_stop_mouse_exited() -> void:
	stop = false


func _on_drop_item_area_area_entered(area: Area2D) -> void:
	print("进入区域")
	if area.is_in_group("drop_item"):
		area.canMoving = true
		print("开始移动")
	pass # Replace with function body.


func _on_stop_area_entered(area: Area2D) -> void:
	if area.is_in_group("drop_item"):
		area.queue_free()
	pass # Replace with function body.
