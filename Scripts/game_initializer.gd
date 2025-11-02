extends Node2D

## 游戏初始化器
## 负责初始化死亡管理器和死亡UI

var death_manager: DeathManager = null
var death_ui: DeathUI = null
var player: CharacterBody2D = null
var floor_layer: TileMapLayer = null

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

