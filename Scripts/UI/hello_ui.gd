extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	anim_name = "start"
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")
	pass # Replace with function body.
