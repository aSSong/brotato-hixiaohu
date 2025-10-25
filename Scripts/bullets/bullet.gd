extends Area2D

@export var speed := 400.0      # 子弹速度
@export var life_time := 3.0    # 最长存活时间（秒）
@export var damage := 10        # 伤害值
var hurt := 1
var dir: Vector2
var _velocity := Vector2.ZERO

func start(pos: Vector2, _dir: Vector2, _speed: float, _hurt: int) -> void:
	global_position = pos
	dir = _dir
	speed = _speed
	hurt = _hurt
	_velocity = dir * speed
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta


func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	#print("Collided with: ", body.name, " (type: ", body.get_class(), ")")
	if body.is_in_group("enemy"):
		body.enemyHP -= 1
		#print("enemyHP: ", body.enemyHP)
		if body.enemyHP <= 0 :
			body.queue_free()
	
		#if body is TileMapLayer:
		#var tile_data := body.get_cell_tile_data(0, body.local_to_map(body.to_local(global_position)))
		#if tile_data and tile_data.get_custom_data("is_wall"):
			#queue_free()
	## 如果还有静态物体（StaticBody2D）做的箱子、柱子，也可一起判断
	#elif body is StaticBody2D:
		#queue_free()
	queue_free()
	pass # Replace with function body.
