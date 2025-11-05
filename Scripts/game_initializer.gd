extends Node2D

## 游戏初始化器
## 负责初始化游戏系统和管理器

var death_manager: DeathManager = null
var death_ui: DeathUI = null
var victory_controller: VictoryController = null
var player: CharacterBody2D = null
var floor_layer: TileMapLayer = null

func _ready() -> void:
	# 设置游戏状态为初始化中
	GameState.change_state(GameState.State.GAME_INITIALIZING)
	
	# 标记初始化开始
	InitManager.is_initializing = true
	InitManager.start_phase(InitManager.InitPhase.SCENE_LOADED)
	
	# 等待场景完全加载
	await get_tree().process_frame
	InitManager.complete_phase(InitManager.InitPhase.SCENE_LOADED)
	
	# 播放战斗BGM
	BGMManager.play_bgm("fight")
	print("[GameInitializer] 开始播放战斗BGM")
	
	# 等待自动加载就绪
	InitManager.start_phase(InitManager.InitPhase.AUTOLOAD_READY)
	await get_tree().process_frame
	InitManager.complete_phase(InitManager.InitPhase.AUTOLOAD_READY)
	
	# 查找玩家
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[GameInitializer] 找不到玩家！")
		return
	
	# 查找floor_layer
	floor_layer = get_tree().get_first_node_in_group("floor_layer")
	if not floor_layer:
		push_warning("[GameInitializer] 找不到floor_layer，复活位置可能不正常")
	
	# 创建管理器阶段
	InitManager.start_phase(InitManager.InitPhase.MANAGERS_CREATED)
	
	# 创建死亡UI
	_create_death_ui()
	
	# 创建死亡管理器
	_create_death_manager()
	
	# 创建ESC菜单管理器
	_create_esc_menu_manager()
	
	# 创建胜利控制器
	_create_victory_controller()
	
	# 创建升级商店
	_create_upgrade_shop()
	
	InitManager.complete_phase(InitManager.InitPhase.MANAGERS_CREATED)
	
	# 玩家就绪阶段
	InitManager.start_phase(InitManager.InitPhase.PLAYER_READY)
	await get_tree().process_frame
	InitManager.complete_phase(InitManager.InitPhase.PLAYER_READY)
	
	# 系统就绪阶段
	InitManager.start_phase(InitManager.InitPhase.SYSTEMS_READY)
	await get_tree().process_frame
	InitManager.complete_phase(InitManager.InitPhase.SYSTEMS_READY)
	
	# 游戏完全就绪
	InitManager.start_phase(InitManager.InitPhase.GAME_READY)
	InitManager.complete_phase(InitManager.InitPhase.GAME_READY)
	
	# 切换到战斗状态
	GameState.change_state(GameState.State.WAVE_FIGHTING)
	
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

## 创建胜利控制器
func _create_victory_controller() -> void:
	victory_controller = VictoryController.new()
	add_child(victory_controller)
	print("[GameInitializer] 胜利控制器已创建")

## 创建升级商店
func _create_upgrade_shop() -> void:
	var upgrade_shop_scene = load("res://scenes/UI/upgrade_shop.tscn")
	if not upgrade_shop_scene:
		push_error("[GameInitializer] 无法加载升级商店场景！")
		return
	
	var upgrade_shop = upgrade_shop_scene.instantiate()
	upgrade_shop.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 尝试添加到CanvasLayer（game_ui）
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if not game_ui:
		# 通过名称查找
		game_ui = get_tree().root.find_child("game_ui", true, false)
	
	if game_ui:
		# 添加到CanvasLayer（game_ui）
		game_ui.add_child(upgrade_shop)
		print("[GameInitializer] 升级商店已添加到CanvasLayer (game_ui)")
	else:
		# 如果找不到game_ui，创建新的CanvasLayer
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "UpgradeShopLayer"
		get_tree().root.add_child(canvas_layer)
		canvas_layer.add_child(upgrade_shop)
		print("[GameInitializer] 升级商店已添加到新CanvasLayer")
	
	upgrade_shop.name = "upgrade_shop"
	
	# 确保添加到组中
	if not upgrade_shop.is_in_group("upgrade_shop"):
		upgrade_shop.add_to_group("upgrade_shop")
	
	print("[GameInitializer] 升级商店创建完成")

