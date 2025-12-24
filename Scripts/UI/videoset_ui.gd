extends CanvasLayer

## 视频&性能设置界面
## 控制震屏效果和子弹拖尾效果

@onready var shake_button: CheckButton = $panel/VBoxContainer/shakeButton
@onready var trail_button: CheckButton = $panel/VBoxContainer/trailButton
@onready var close_button: TextureButton = $panel/close

func _ready() -> void:
	# 根据存档设置初始化按钮状态
	shake_button.button_pressed = SaveManager.get_shake_enabled()
	trail_button.button_pressed = SaveManager.get_trail_enabled()
	
	# 连接信号
	shake_button.toggled.connect(_on_shake_button_toggled)
	trail_button.toggled.connect(_on_trail_button_toggled)
	close_button.pressed.connect(_on_close_pressed)
	
	print("[VideosetUI] 视频设置界面已打开，震屏: %s, 拖尾: %s" % [shake_button.button_pressed, trail_button.button_pressed])

## 震屏效果开关切换
func _on_shake_button_toggled(toggled_on: bool) -> void:
	SaveManager.set_shake_enabled(toggled_on)
	print("[VideosetUI] 震屏效果设置: %s" % toggled_on)

## 子弹拖尾效果开关切换
func _on_trail_button_toggled(toggled_on: bool) -> void:
	SaveManager.set_trail_enabled(toggled_on)
	print("[VideosetUI] 子弹拖尾效果设置: %s" % toggled_on)

## 关闭按钮点击
func _on_close_pressed() -> void:
	print("[VideosetUI] 关闭视频设置界面")
	queue_free()

