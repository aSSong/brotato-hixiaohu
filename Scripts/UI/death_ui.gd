extends CanvasLayer
class_name DeathUI

## 死亡UI
## 显示死亡界面，提供放弃和复活选项

@onready var death_panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel
@onready var revive_button: Button = $Panel/VBoxContainer/ButtonContainer/ReviveButton
@onready var give_up_button: Button = $Panel/VBoxContainer/ButtonContainer/GiveUpButton
@onready var cost_label: Label = $Panel/VBoxContainer/CostLabel

## 信号
signal revive_requested  # 请求复活
signal give_up_requested  # 请求放弃

var revive_cost: int = 0
var can_afford: bool = false

func _ready() -> void:
	# 连接按钮信号
	revive_button.pressed.connect(_on_revive_pressed)
	give_up_button.pressed.connect(_on_give_up_pressed)
	
	# 默认隐藏
	hide()

## 显示死亡界面
func show_death_screen(revive_count: int, current_gold: int) -> void:
	# 计算复活费用
	revive_cost = 5 * (revive_count + 1)
	can_afford = current_gold >= revive_cost
	
	# 更新动态文本（钥匙数量和按钮状态）
	cost_label.text = "复活费用：%d 钥匙" % revive_cost
	
	# 更新复活按钮状态
	if can_afford:
		revive_button.disabled = false
		revive_button.text = "复活 (-%d钥匙)" % revive_cost
	else:
		revive_button.disabled = true
		revive_button.text = "钥匙不足"
	
	# 显示界面
	show()
	
	print("[DeathUI] 显示死亡界面 | 复活次数:", revive_count, " 费用:", revive_cost, " 当前钥匙:", current_gold)

## 复活按钮按下
func _on_revive_pressed() -> void:
	if can_afford:
		print("[DeathUI] 玩家选择复活")
		revive_requested.emit()
		hide()

## 放弃按钮按下
func _on_give_up_pressed() -> void:
	print("[DeathUI] 玩家选择放弃")
	give_up_requested.emit()
	hide()

## 隐藏界面
func hide_death_screen() -> void:
	hide()
