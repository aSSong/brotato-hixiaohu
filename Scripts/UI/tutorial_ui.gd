extends CanvasLayer

## 新手教程UI
## 显示操作指南，玩家确认后开始游戏

## 信号：教程关闭时触发
signal tutorial_closed

## UI节点引用
@onready var bg: TextureRect = $bg
@onready var confirm_button: TextureButton = $bg/TextureButton
@onready var dont_show_checkbox: CheckBox = $bg/TextureButton/CheckBox

func _ready() -> void:
	# 设置为暂停时可处理
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 设置 CanvasLayer 层级，确保显示在最上层
	layer = 100
	
	# 连接确认按钮信号
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	print("[TutorialUI] 教程界面已初始化")

## 确认按钮点击回调
func _on_confirm_pressed() -> void:
	print("[TutorialUI] 玩家点击确认")
	
	# 检查是否勾选了"不再提示"
	if dont_show_checkbox and dont_show_checkbox.button_pressed:
		print("[TutorialUI] 玩家勾选了「不再提示」，保存设置")
		SaveManager.set_tutorial_shown(true)
	
	# 发出教程关闭信号
	tutorial_closed.emit()
	
	# 关闭教程界面
	queue_free()

## 显示教程界面
func show_tutorial() -> void:
	visible = true
	print("[TutorialUI] 显示教程界面")

## 隐藏教程界面
func hide_tutorial() -> void:
	visible = false
