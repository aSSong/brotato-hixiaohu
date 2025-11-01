extends CanvasLayer
class_name GraveRescueUI

## 救援界面UI
## 显示Ghost信息，提供救援、超度、取消选项

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var class_label: Label = $Panel/VBoxContainer/ClassLabel
@onready var weapons_label: Label = $Panel/VBoxContainer/WeaponsLabel
@onready var death_label: Label = $Panel/VBoxContainer/DeathLabel
@onready var cost_label: Label = $Panel/VBoxContainer/CostLabel
@onready var rescue_button: Button = $Panel/VBoxContainer/ButtonContainer/RescueButton
@onready var transcend_button: Button = $Panel/VBoxContainer/ButtonContainer/TranscendButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonContainer/CancelButton

## 信号
signal rescue_requested  # 请求救援
signal transcend_requested  # 请求超度
signal cancelled  # 取消

var ghost_data: GhostData = null

func _ready() -> void:
	# 连接按钮信号
	rescue_button.pressed.connect(_on_rescue_pressed)
	transcend_button.pressed.connect(_on_transcend_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# 默认隐藏
	hide()

## 显示救援界面
func show_rescue_dialog(data: GhostData) -> void:
	ghost_data = data
	
	if not ghost_data:
		push_error("[GraveRescueUI] Ghost数据为空")
		return
	
	# 更新UI文本
	title_label.text = "复活队友？"
	class_label.text = "职业：" + ghost_data.get_class_name()
	weapons_label.text = "武器：" + ghost_data.get_weapons_description()
	death_label.text = "死亡次数：第 " + str(ghost_data.death_count) + " 次"
	
	# 检查是否有足够的masterkey
	var current_keys = GameMain.master_key
	cost_label.text = "费用：1个 Master Key (当前：" + str(current_keys) + "个)"
	
	# 更新按钮状态
	if current_keys >= 1:
		rescue_button.disabled = false
		rescue_button.text = "同意救援"
	else:
		rescue_button.disabled = true
		rescue_button.text = "Master Key不足"
	
	transcend_button.text = "超度"
	cancel_button.text = "取消"
	
	# 显示界面
	show()
	
	print("[GraveRescueUI] 显示救援界面")

## 救援按钮按下
func _on_rescue_pressed() -> void:
	if GameMain.master_key >= 1:
		print("[GraveRescueUI] 玩家选择救援")
		rescue_requested.emit()
		hide()

## 超度按钮按下
func _on_transcend_pressed() -> void:
	print("[GraveRescueUI] 玩家选择超度")
	transcend_requested.emit()
	hide()

## 取消按钮按下
func _on_cancel_pressed() -> void:
	print("[GraveRescueUI] 玩家取消")
	cancelled.emit()
	hide()

## 隐藏界面
func hide_dialog() -> void:
	hide()

