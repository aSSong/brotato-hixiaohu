extends Control
class_name VictoryUI

## 胜利UI
## 当玩家达到目标时显示

@onready var title_label: Label = $MainPanel/VBoxContainer/TitleLabel
@onready var message_label: Label = $MainPanel/VBoxContainer/MessageLabel
@onready var gold_label: Label = $MainPanel/VBoxContainer/GoldLabel
@onready var return_button: Button = $MainPanel/VBoxContainer/ReturnButton

func _ready() -> void:
	# 确保状态正确
	if GameState.current_state != GameState.State.GAME_VICTORY:
		GameState.change_state(GameState.State.GAME_VICTORY)
	
	# 显示获得的钥匙数量（动态内容）
	if gold_label:
		gold_label.text = "收集钥匙: %d" % GameMain.gold
	
	# 连接返回按钮
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

## 返回主菜单
func _on_return_button_pressed() -> void:
	var start_menu_scene = load("res://scenes/UI/main_title.tscn")
	if start_menu_scene:
		get_tree().change_scene_to_packed(start_menu_scene)
		# 重置游戏数据
		GameMain.reset_game()
