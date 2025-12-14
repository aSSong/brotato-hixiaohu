extends Control


func _input(event: InputEvent) -> void:
	# ESC键或鼠标左键点击结束播放
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			_skip_video()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_skip_video()


func _skip_video() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")


func _on_video_stream_player_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/settings_ui.tscn")
