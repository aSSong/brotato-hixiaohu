extends Node2D

## 游戏初始化器
## 负责初始化死亡管理器和死亡UI

var death_manager: DeathManager = null
var death_ui: DeathUI = null
var player: CharacterBody2D = null
var floor_layer: TileMapLayer = null
var current_mode: BaseGameMode = null
var victory_triggered: bool = false

func _ready() -> void:
	# 等待场景完全加载
	await get_tree().process_frame
	
	# 播放战斗BGM
	BGMManager.play_bgm("fight")
	print("[GameInitializer] 开始播放战斗BGM")
	
	# 查找玩家
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[GameInitializer] 找不到玩家！")
		return
	
	# 查找floor_layer
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_warning("[GameInitializer] 找不到floor_layer，复活位置可能不正常")
	
	# 创建死亡UI
	_create_death_ui()
	
	# 创建死亡管理器
	_create_death_manager()
	
	# 创建ESC菜单管理器
	_create_esc_menu_manager()
	
	# 设置胜利条件检测
	_setup_victory_detection()
	
	print("[GameInitializer] 游戏初始化完成")

## 创建死亡UI
func _create_death_ui() -> void:
	var death_ui_scene = load("res://scenes/UI/death_ui.tscn")
	if not death_ui_scene:
		push_error("[GameInitializer] 无法加载死亡UI场景！")
		return
	
	death_ui = death_ui_scene.instantiate()
	
	# 设置为暂停时可处理（重要！）
	death_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().root.add_child(death_ui)
	
	print("[GameInitializer] 死亡UI已创建")

## 创建死亡管理器
func _create_death_manager() -> void:
	death_manager = DeathManager.new()
	add_child(death_manager)
	
	# 设置引用
	death_manager.set_player(player)
	death_manager.set_death_ui(death_ui)
	
	if floor_layer:
		death_manager.set_floor_layer(floor_layer)
	
	print("[GameInitializer] 死亡管理器已创建")

## 创建ESC菜单管理器
func _create_esc_menu_manager() -> void:
	var esc_manager = Node.new()
	esc_manager.name = "ESCMenuManager"
	esc_manager.set_script(load("res://Scripts/UI/esc_menu_manager.gd"))
	add_child(esc_manager)
	print("[GameInitializer] ESC菜单管理器已创建")

## 设置胜利条件检测
func _setup_victory_detection() -> void:
	# 获取当前模式
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"  # 默认为生存模式
	
	current_mode = ModeRegistry.get_mode(mode_id)
	if not current_mode:
		push_error("[GameInitializer] 无法获取游戏模式: %s" % mode_id)
		return
	
	print("[GameInitializer] 设置胜利检测 | 模式: %s | 条件: %s" % [current_mode.mode_name, current_mode.victory_condition_type])
	
	# 根据胜利条件类型连接相应信号
	match current_mode.victory_condition_type:
		"keys":
			# 钥匙胜利条件：监听金币变化
			if not GameMain.gold_changed.is_connected(_on_resource_changed):
				GameMain.gold_changed.connect(_on_resource_changed)
			print("[GameInitializer] 已连接金币变化信号用于胜利检测")
		"waves":
			# 波次胜利条件：监听波次结束（重要：在波次结束后才检查胜利）
			await get_tree().create_timer(0.5).timeout  # 等待波次系统初始化
			var wave_manager = get_tree().get_first_node_in_group("wave_manager")
			if wave_manager and wave_manager.has_signal("wave_ended"):
				if not wave_manager.wave_ended.is_connected(_on_wave_ended):
					wave_manager.wave_ended.connect(_on_wave_ended)
				print("[GameInitializer] 已连接波次结束信号用于胜利检测")
			else:
				push_warning("[GameInitializer] 未找到wave_manager，波次胜利检测可能不工作")

## 资源变化回调（用于钥匙胜利条件）
func _on_resource_changed(_new_val: int, _change: int) -> void:
	_check_victory()

## 波次结束回调（用于波次胜利条件）
func _on_wave_ended(_wave_number: int) -> void:
	_check_victory()

## 检查胜利条件
func _check_victory() -> void:
	if victory_triggered:
		return
	
	if not current_mode:
		return
	
	if current_mode.check_victory_condition():
		victory_triggered = true
		_trigger_victory()

## 触发胜利
func _trigger_victory() -> void:
	print("[GameInitializer] 达成胜利条件！准备切换到胜利场景...")
	
	# 立即恢复游戏（取消暂停），阻止商店打开
	if get_tree().paused:
		get_tree().paused = false
		print("[GameInitializer] 取消暂停以阻止商店打开")
	
	# 短暂延迟以显示最后一击的效果
	await get_tree().create_timer(0.5).timeout
	
	# 加载胜利UI场景
	var victory_scene = load("res://scenes/UI/victory_ui.tscn")
	if victory_scene:
		# 使用安全的场景切换（带清理）
		await SceneCleanupManager.change_scene_to_packed_safely(victory_scene)
	else:
		push_error("[GameInitializer] 无法加载胜利UI场景！")

