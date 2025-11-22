extends CanvasLayer
class_name ESCMenu

## ESC暂停菜单
## 提供继续游戏和返回主菜单功能

## 信号
signal resume_requested
signal main_menu_requested

## 节点引用
@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/ResumeButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var background: ColorRect = $Background

func _ready() -> void:
	# 设置为暂停时也能处理（关键！）
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 设置层级，确保遮挡死亡UI（死亡UI默认为1）
	layer = 100
	
	# 初始隐藏
	hide()
	
	print("[ESC Menu] 菜单已初始化")

## 显示菜单
func show_menu() -> void:
	print("[ESC Menu] 准备打开菜单")
	
	# 暂停游戏 - 由 GameState 管理
	# get_tree().paused = true
	
	# 显示菜单
	show()
	visible = true
	
	# 聚焦到继续按钮
	if resume_button:
		resume_button.grab_focus()
	
	# 播放淡入动画
	_play_show_animation()
	
	print("[ESC Menu] 菜单已打开，游戏已暂停")

## 隐藏菜单
func hide_menu() -> void:
	print("[ESC Menu] 准备关闭菜单")
	
	# 播放淡出动画
	await _play_hide_animation()
	
	# 隐藏菜单
	hide()
	
	# 恢复游戏 - 由 GameState 管理
	# get_tree().paused = false
	
	print("[ESC Menu] 菜单已关闭")

## 播放显示动画
func _play_show_animation() -> void:
	if background:
		# 背景淡入
		background.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(background, "modulate:a", 0.7, 0.2)

## 播放隐藏动画
func _play_hide_animation() -> void:
	if background:
		# 背景淡出
		var tween = create_tween()
		tween.tween_property(background, "modulate:a", 0.0, 0.15)
		await tween.finished

## 继续游戏按钮
func _on_resume_pressed() -> void:
	print("[ESC Menu] 玩家选择继续游戏")
	hide_menu()
	resume_requested.emit()

## 返回主菜单按钮
func _on_main_menu_pressed() -> void:
	print("[ESC Menu] 玩家选择返回主菜单")
	
	# 显示确认对话框（可选）
	if await _show_confirmation():
		_return_to_main_menu()
	else:
		print("[ESC Menu] 玩家取消返回主菜单")

## 显示确认对话框
func _show_confirmation() -> bool:
	# 简化版：直接返回true
	# 如果需要确认对话框，可以在这里实现
	return true

## 返回主菜单
func _return_to_main_menu() -> void:
	# 恢复游戏（必须在切换场景前）
	get_tree().paused = false
	
	# 重置游戏数据
	GameMain.reset_game()
	
	# 发送信号
	main_menu_requested.emit()
	
	print("[ESC Menu] 正在返回主菜单...")
	
	# 切换到主菜单场景
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")

## 处理ESC键输入（关闭菜单）
func _input(event: InputEvent) -> void:
	# 只有在菜单可见时才响应ESC键关闭
	if event.is_action_pressed("ui_cancel") and visible:
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_restart_pressed() -> void:
		# 恢复游戏（必须在切换场景前）
	get_tree().paused = false
	
	# 重置游戏数据
	GameMain.reset_game()
	
	# 发送信号
	main_menu_requested.emit()
	
	print("[ESC Menu] 正在返回主菜单...")
	
	# 切换到主菜单场景
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/UI/start_menu.tscn")
