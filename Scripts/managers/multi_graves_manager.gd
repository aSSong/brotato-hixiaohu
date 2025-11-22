extends Node
class_name MultiGravesManager

## Multi模式墓碑管理器
## 负责在每波开始时刷新对应wave的ghost墓碑
## 注意：作为场景节点使用，不使用autoload

## 当前生成的墓碑列表（墓碑精灵节点）
var current_graves: Array = []

## 当前生成的救援管理器列表
var current_rescue_managers: Array = []

## 父节点引用（用于添加墓碑）
var parent_node: Node2D = null

## 玩家引用
var player: CharacterBody2D = null

func _ready() -> void:
	# 添加到组中方便查找
	add_to_group("multi_graves_manager")
	print("[MultiGravesManager] 初始化")

## 设置父节点（用于添加墓碑）
func set_parent_node(node: Node2D) -> void:
	parent_node = node
	print("[MultiGravesManager] 设置父节点:", node.name if node else "null")

## 设置玩家引用
func set_player(p: CharacterBody2D) -> void:
	player = p
	print("[MultiGravesManager] 设置玩家引用")

## 为指定wave刷新墓碑
func spawn_graves_for_wave(wave: int) -> void:
	if not parent_node:
		push_error("[MultiGravesManager] 父节点未设置，无法刷新墓碑")
		return
	
	# 清除旧墓碑
	clear_all_graves()
	
	# 从数据库查询该wave的ghost
	var mode_id = GameMain.current_mode_id
	var map_id = GameMain.current_map_id
	var ghosts = GhostDatabase.get_ghosts_for_wave(mode_id, map_id, wave)
	
	if ghosts.is_empty():
		print("[MultiGravesManager] Wave%d 没有Ghost数据" % wave)
		return
	
	print("[MultiGravesManager] 开始刷新 Wave%d 的墓碑，共 %d 个" % [wave, ghosts.size()])
	
	# 为每个ghost创建墓碑
	for ghost_data in ghosts:
		_create_grave_for_ghost(ghost_data)
	
	print("[MultiGravesManager] 墓碑刷新完成，共创建 %d 个墓碑" % current_graves.size())

## 为单个ghost创建墓碑
func _create_grave_for_ghost(ghost_data: GhostData) -> void:
	if not ghost_data:
		return
	
	# 加载墓碑纹理
	var grave_texture = load("res://assets/others/grave.png")
	if not grave_texture:
		push_error("[MultiGravesManager] 无法加载墓碑纹理！")
		return
	
	# 创建墓碑精灵
	var grave_sprite = Sprite2D.new()
	grave_sprite.texture = grave_texture
	grave_sprite.global_position = ghost_data.death_position
	grave_sprite.z_index = 20
	
	# 创建名字Label
	_create_grave_name_label(grave_sprite, ghost_data)
	
	# 添加到场景
	parent_node.add_child(grave_sprite)
	current_graves.append(grave_sprite)
	
	# 创建救援管理器
	_create_rescue_manager_for_grave(grave_sprite, ghost_data)
	
	print("[MultiGravesManager] 创建墓碑: %s (第%d世) 于 %s" % [ghost_data.player_name, ghost_data.total_death_count, ghost_data.death_position])

## 创建墓碑名字Label
func _create_grave_name_label(grave_sprite: Sprite2D, ghost_data: GhostData) -> void:
	if not grave_sprite or not ghost_data:
		return
	
	# 创建Label节点作为墓碑的子节点
	var name_label = Label.new()
	grave_sprite.add_child(name_label)
	
	# 设置Label属性
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置位置（在墓碑上方）
	name_label.position = Vector2(-115, -100)
	name_label.size = Vector2(120, 30)
	
	# 设置字体大小和颜色（与Ghost一致，使用淡蓝色）
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))  # 淡蓝色
	
	# 添加黑色描边效果
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	
	# 设置z_index确保在墓碑上方显示
	name_label.z_index = 100
	
	# 设置显示文本：名字 - n世
	var display_name = "%s - 第 %d 世" % [ghost_data.player_name, ghost_data.total_death_count]
	name_label.text = display_name

## 为墓碑创建救援管理器
func _create_rescue_manager_for_grave(grave_sprite: Sprite2D, ghost_data: GhostData) -> void:
	if not grave_sprite or not ghost_data or not player:
		return
	
	# 创建救援管理器
	var rescue_manager = GraveRescueManager.new()
	
	# 添加到场景
	parent_node.add_child(rescue_manager)
	
	# 设置引用
	rescue_manager.set_player(player)
	rescue_manager.set_grave(grave_sprite)
	rescue_manager.set_ghost_data(ghost_data)
	# Multi模式下不需要设置death_manager，因为墓碑不是玩家自己的
	
	# 初始化位置
	rescue_manager.update_position()
	
	# 记录到列表
	current_rescue_managers.append(rescue_manager)
	
	print("[MultiGravesManager] 为墓碑创建救援管理器")

## 清除所有墓碑
func clear_all_graves() -> void:
	print("[MultiGravesManager] 清除所有墓碑，共 %d 个" % current_graves.size())
	
	# 清除救援管理器
	for rescue_manager in current_rescue_managers:
		if rescue_manager and is_instance_valid(rescue_manager):
			rescue_manager.cleanup()
			rescue_manager.queue_free()
	current_rescue_managers.clear()
	
	# 清除墓碑
	for grave in current_graves:
		if grave and is_instance_valid(grave):
			grave.queue_free()
	current_graves.clear()

## 节点移除时清理
func _exit_tree() -> void:
	clear_all_graves()
	print("[MultiGravesManager] 已清理")

## 获取当前墓碑数量
func get_graves_count() -> int:
	return current_graves.size()
