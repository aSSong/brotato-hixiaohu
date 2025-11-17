extends Control
class_name BaseSkillUI

## 技能UI基类 - 统一的CD显示逻辑
## 用于 Dash 和职业技能的CD显示

@onready var icon: TextureRect = $Icon
@onready var cd_mask: ColorRect = $CDMask
@onready var cd_text: Label = $CDText
@onready var name_label: Label = $NameLabel
@onready var key_label: Label = $KeyLabel

var update_timer: Timer

func _ready():
	# 初始隐藏CD相关元素
	if cd_mask:
		cd_mask.visible = false
	if cd_text:
		cd_text.visible = false
	
	# 创建更新定时器（0.1秒更新一次，避免每帧更新）
	update_timer = Timer.new()
	update_timer.name = "UpdateTimer"
	update_timer.wait_time = 0.1
	update_timer.autostart = true
	update_timer.timeout.connect(_update_cd_display)
	add_child(update_timer)

## 子类必须重写：获取CD剩余时间
func _get_remaining_cd() -> float:
	return 0.0  # 子类重写此方法

## 更新CD显示
func _update_cd_display():
	var remaining = _get_remaining_cd()
	
	if remaining > 0:
		# 显示CD遮罩和倒计时数字
		if cd_mask:
			cd_mask.visible = true
		if cd_text:
			cd_text.visible = true
			cd_text.text = str(ceili(remaining))  # 向上取整显示
	else:
		# 隐藏CD相关元素
		if cd_mask:
			cd_mask.visible = false
		if cd_text:
			cd_text.visible = false

