extends CharacterBody2D

var dir = Vector2.ZERO
var speed = 2000
var hurt = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity = dir * speed
	move_and_slide()
	pass


func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	#if
	#print("Collided with: ", body.name, " (type: ", body.get_class(), ")")
	#if body is TileMapLayer:
		#var coords = body.get_coords_for_body_rid(body_rid)
		#var tile_date = body.get_cell_tile_data(coords)
		#if tile_date != null :
			#var isWall = tile_date.get_custom_data("isWall")
			##if isWall and isWall != null :
			#if isWall :
	self.queue_free()
		
	pass # Replace with function body.
