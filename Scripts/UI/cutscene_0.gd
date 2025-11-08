extends Control

func _ready() -> void:
	# 播放标题BGM（如果还未播放）
	BGMManager.play_bgm("title")
	print("[Cutscene0] 确保标题BGM播放中")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"default":          # 动画名完全匹配
		get_tree().change_scene_to_file("res://scenes/UI/cutscene_1.tscn")


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/cutscene_1.tscn")
