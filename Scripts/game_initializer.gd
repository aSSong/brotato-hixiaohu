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
	
	# 创建说话管理器
	_create_speech_manager()
	
	# 设置胜利条件检测
	_setup_victory_detection()
	
	# 统一设置游戏流程监听
	_setup_game_flow()
	
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

## 创建说话管理器
func _create_speech_manager() -> void:
	var speech_manager_script = load("res://Scripts/managers/speech_manager.gd")
	if not speech_manager_script:
		push_error("[GameInitializer] 无法加载说话管理器脚本！")
		return
	
	var speech_manager = speech_manager_script.new()
	speech_manager.name = "SpeechManager"
	add_child(speech_manager)
	speech_manager.add_to_group("speech_manager")
	print("[GameInitializer] 说话管理器已创建")
	
	# 等待一帧后，主动注册所有Player和Ghost
	await get_tree().process_frame
	_register_all_speakers(speech_manager)

## 注册所有说话者到SpeechManager
func _register_all_speakers(speech_manager: SpeechManager) -> void:
	# 注册Player
	if player and is_instance_valid(player):
		if speech_manager.has_method("register_speaker"):
			speech_manager.register_speaker(player)
			print("[GameInitializer] Player已注册到SpeechManager")
	
	# 注册所有Ghost
	var ghosts = get_tree().get_nodes_in_group("ghost")
	for ghost in ghosts:
		if ghost and is_instance_valid(ghost):
			if speech_manager.has_method("register_speaker"):
				speech_manager.register_speaker(ghost)
				print("[GameInitializer] Ghost已注册到SpeechManager: ", ghost.name)

## 应用模式的初始资源配置
func _apply_initial_resources(mode: BaseGameMode) -> void:
	if not mode:
		return
	
	# 设置初始gold（即使为0也设置，确保覆盖之前的值）
	GameMain.gold = mode.initial_gold
	if mode.initial_gold > 0:
		print("[GameInitializer] 应用初始gold: %d" % mode.initial_gold)
	
	# 设置初始masterkey（即使为0也设置，确保覆盖之前的值）
	GameMain.master_key = mode.initial_master_key
	if mode.initial_master_key > 0:
		print("[GameInitializer] 应用初始masterkey: %d" % mode.initial_master_key)

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
	
	# 应用模式的初始资源配置
	_apply_initial_resources(current_mode)
	
	# 根据胜利条件类型连接相应信号
	match current_mode.victory_condition_type:
		"keys":
			# 钥匙胜利条件：监听金币变化
			if not GameMain.gold_changed.is_connected(_on_resource_changed):
				GameMain.gold_changed.connect(_on_resource_changed)
			print("[GameInitializer] 已连接金币变化信号用于胜利检测")
		"waves":
			# 波次胜利条件：已在 _setup_game_flow 中统一处理，这里不再连接 wave_ended
			print("[GameInitializer] 波次胜利检测已委托给 _setup_game_flow")

## 资源变化回调（用于钥匙胜利条件）
func _on_resource_changed(_new_val: int, _change: int) -> void:
	_check_victory()

# 已废弃，由 _on_wave_flow_step 接管
# func _on_wave_ended(_wave_number: int) -> void:

## 统一设置游戏流程监听
func _setup_game_flow() -> void:
	# 等待波次系统就绪
	await get_tree().process_frame
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	
	if wave_manager:
		# 监听商店关闭信号
		var shop = get_tree().get_first_node_in_group("upgrade_shop")
		if shop:
			if not shop.has_signal("shop_closed"):
				push_error("[GameInitializer] 商店没有shop_closed信号")
			elif not shop.shop_closed.is_connected(_on_shop_closed):
				shop.shop_closed.connect(_on_shop_closed)
				print("[GameInitializer] 已连接商店关闭信号")

		# 连接到我们新的主流程控制函数
		if wave_manager.has_signal("wave_completed"):
			if not wave_manager.wave_completed.is_connected(_on_wave_flow_step):
				wave_manager.wave_completed.connect(_on_wave_flow_step)
				print("[GameInitializer] 已接管波次流程控制")

## 核心流程控制函数：波次结束后的统筹安排
func _on_wave_flow_step(wave_number: int) -> void:
	print("[Flow] 波次 %d 结束，开始流程结算..." % wave_number)
	
	# 1. 状态检查：如果玩家已经死了，中断流程
	if GameState.current_state == GameState.State.PLAYER_DEAD:
		print("[Flow] 玩家已死亡，终止流程")
		return

	# 2. 进入清扫阶段（捡东西时间），也就是你想要的延迟
	GameState.change_state(GameState.State.WAVE_CLEARING)
	var delay_time = 2.0 # 可以在这里调整延迟秒数
	print("[Flow] 进入捡落物时间 (%.1f秒)" % delay_time)
	await get_tree().create_timer(delay_time).timeout
	
	# 3. 再次检查死亡（防止延迟期间暴毙）
	if GameState.current_state == GameState.State.PLAYER_DEAD:
		return

	# 4. 胜利检测 (仅针对Wave类型，Key类型由资源回调处理)
	if current_mode and current_mode.victory_condition_type == "waves":
		if current_mode.check_victory_condition():
			print("[Flow] 触发胜利！")
			_trigger_victory()
			return

	# 5. 既没死也没赢 -> 打开商店
	print("[Flow] 进入商店阶段")
	_open_shop_flow()

## 打开商店的统一入口
func _open_shop_flow() -> void:
	# 如果正在救援，等待救援结束（简单策略：不打开商店，等下次检查？或者暂时阻塞？）
	# 这里采用：如果正在救援，稍后重试
	if GameState.current_state == GameState.State.RESCUING:
		print("[Flow] 玩家正在救援中，延迟打开商店...")
		await get_tree().create_timer(1.0).timeout
		_open_shop_flow()
		return

	GameState.change_state(GameState.State.SHOPPING)
	# 通知商店打开
	get_tree().call_group("upgrade_shop", "open_shop")

## 商店关闭回调
func _on_shop_closed() -> void:
	print("[Flow] 商店已关闭，准备下一波")
	
	# 切换到空闲/清扫状态，准备下一波
	GameState.change_state(GameState.State.WAVE_CLEARING)
	
	# 停顿2秒开始刷怪
	print("[Flow] 休息2秒...")
	await get_tree().create_timer(2.0).timeout
	
	# 开始下一波
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager and wave_manager.has_method("start_next_wave"):
		wave_manager.start_next_wave()

## 检查胜利条件
func _check_victory() -> void:
	if victory_triggered:
		print("[GameInitializer] 胜利已触发，跳过检查")
		return
	
	if not current_mode:
		print("[GameInitializer] 当前模式为空，跳过胜利检查")
		return
	
	print("[GameInitializer] 检查胜利条件...")
	var victory = current_mode.check_victory_condition()
	print("[GameInitializer] 胜利条件检查结果: %s" % victory)
	
	if victory:
		victory_triggered = true
		print("[GameInitializer] ========== 触发胜利！==========")
		_trigger_victory()
	else:
		print("[GameInitializer] 未达成胜利条件")

## 触发胜利
func _trigger_victory() -> void:
	print("[GameInitializer] 达成胜利条件！准备切换到胜利场景...")
	
	# 设置胜利状态（暂停游戏）
	GameState.change_state(GameState.State.GAME_VICTORY)
	
	# 清场（可选：消灭所有敌人）
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager and wave_manager.has_method("force_end_wave"):
		wave_manager.force_end_wave()
	
	# 等待1秒（如需求所述）
	await get_tree().create_timer(1.0).timeout
	
	# 加载胜利UI场景
	var victory_scene = load("res://scenes/UI/victory_ui.tscn")
	if victory_scene:
		# 使用安全的场景切换（带清理）
		await SceneCleanupManager.change_scene_to_packed_safely(victory_scene)
	else:
		push_error("[GameInitializer] 无法加载胜利UI场景！")
