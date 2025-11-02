extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 播放标题BGM（如果还未播放）
	BGMManager.play_bgm("title")
	print("[Cutscene1] 确保标题BGM播放中")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_btn_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
	pass # Replace with function body.
