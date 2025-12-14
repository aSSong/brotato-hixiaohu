extends Control


func _on_cut_1_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_playback_1.tscn")


func _on_cut_2_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_playback_2.tscn")


func _on_stuffbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/creators.tscn")


func _on_filesbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_playback_1.tscn")


func _on_backbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")
