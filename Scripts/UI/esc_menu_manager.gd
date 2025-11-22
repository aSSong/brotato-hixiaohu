extends Node
class_name ESCMenuManager

## ESC菜单管理器
## 负责监听ESC键并显示/隐藏菜单

## ESC菜单实例
var esc_menu: ESCMenu = null

func _ready() -> void:
	# 设置为暂停时也能处理（关键！）
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 加载并实例化ESC菜单
	var esc_menu_scene = load("res://scenes/UI/esc_menu.tscn")
	if esc_menu_scene:
		esc_menu = esc_menu_scene.instantiate()
		# 添加到根节点，确保在所有UI之上
		get_tree().root.add_child(esc_menu)
		
		# 连接信号（可选）
		if esc_menu.has_signal("resume_requested"):
			esc_menu.resume_requested.connect(_on_resume)
		if esc_menu.has_signal("main_menu_requested"):
			esc_menu.main_menu_requested.connect(_on_main_menu)
		
		print("[ESC Manager] ESC菜单已创建并添加到场景树")
	else:
		push_error("[ESC Manager] 无法加载ESC菜单场景！")

## 监听ESC键
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 检查菜单是否已存在且不可见
		if esc_menu and not esc_menu.visible:
			print("[ESC Manager] 检测到ESC键，打开菜单")
			
			# 记录打开前的状态，以便恢复
			# GameState 会自动记录 previous_state
			GameState.change_state(GameState.State.ESC_MENU)
			
			esc_menu.show_menu()
			get_viewport().set_input_as_handled()

		elif esc_menu and esc_menu.visible:
			# 菜单已经打开，ESC键会被esc_menu.gd自己处理
			pass

## 继续游戏回调
func _on_resume() -> void:
	print("[ESC Manager] 游戏继续")
	# 恢复到上一个状态
	if GameState.previous_state != GameState.State.NONE:
		GameState.change_state(GameState.previous_state)
	else:
		GameState.change_state(GameState.State.WAVE_FIGHTING)

## 返回主菜单回调
func _on_main_menu() -> void:
	print("[ESC Manager] 返回主菜单")

func _exit_tree() -> void:
	# 清理ESC菜单
	if esc_menu and is_instance_valid(esc_menu):
		esc_menu.queue_free()
		print("[ESC Manager] ESC菜单已清理")
