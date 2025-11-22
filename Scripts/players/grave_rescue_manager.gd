extends Node2D
class_name GraveRescueManager

## 墓碑救援管理器
## 处理玩家与墓碑的交互：范围检测、读条、救援界面

## 引用
var player: CharacterBody2D = null
var grave_sprite: Sprite2D = null
var ghost_data: GhostData = null
var death_manager: Node = null

## 救援范围
const RESCUE_RANGE: float = 400.0

## 读条相关
var is_in_range: bool = false
var rescue_progress: float = 0.0
const RESCUE_TIME: float = 2.0
var is_reading: bool = false

## UI元素
var progress_bar: ProgressBar = null
var range_circle: Sprite2D = null
var rescue_ui: CanvasLayer = null  # GraveRescueUI是CanvasLayer类型

func _ready() -> void:
	# 创建进度条UI
	_create_progress_bar()
	
	# 创建范围圈
	_create_range_circle()

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	if not grave_sprite or not is_instance_valid(grave_sprite):
		return
	
	# 如果玩家死亡，隐藏所有UI并停止读条
	if player.now_hp <= 0:
		if is_reading:
			_stop_reading()
		if range_circle and range_circle.visible:
			range_circle.visible = false
		# 重置范围状态，这样复活后重新进入范围会触发_on_range_changed
		if is_in_range:
			is_in_range = false
		return
	
	# 检查玩家是否在范围内
	var distance = player.global_position.distance_to(grave_sprite.global_position)
	var in_range_now = distance <= RESCUE_RANGE
	
	# 范围状态变化
	if in_range_now != is_in_range:
		is_in_range = in_range_now
		_on_range_changed(in_range_now)
	
	# 在范围内且可以读条
	if is_in_range and _can_start_reading():
		if not is_reading:
			_start_reading()
		
		# 更新读条进度
		rescue_progress += delta
		_update_progress_bar(rescue_progress / RESCUE_TIME)
		
		# 读条完成
		if rescue_progress >= RESCUE_TIME:
			_on_reading_complete()
	else:
		# 不在范围内或不能读条，重置进度
		if is_reading:
			_stop_reading()

## 检查是否可以开始读条
func _can_start_reading() -> bool:
	# 检查玩家引用
	if not player or not is_instance_valid(player):
		return false
	
	# 玩家死亡不能读条（不打印日志，因为每帧都会检查）
	if player.now_hp <= 0:
		return false
	
	# 游戏暂停不能读条（商店打开等）
	if get_tree().paused:
		return false
	
	# 救援界面打开时不能读条
	if rescue_ui and rescue_ui.visible:
		return false
	
	return true

## 范围状态变化
func _on_range_changed(entered: bool) -> void:
	if entered:
		print("[GraveRescue] 进入救援范围 | 玩家HP:", player.now_hp if player else "null", " | 范围:", RESCUE_RANGE)
		if range_circle:
			range_circle.visible = true
	else:
		print("[GraveRescue] 离开救援范围")
		if range_circle:
			range_circle.visible = false

## 开始读条
func _start_reading() -> void:
	is_reading = true
	rescue_progress = 0.0
	if progress_bar:
		progress_bar.visible = true
	print("[GraveRescue] 开始读条")

## 停止读条
func _stop_reading() -> void:
	is_reading = false
	rescue_progress = 0.0
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0
	print("[GraveRescue] 停止读条")

## 更新进度条
func _update_progress_bar(progress: float) -> void:
	if not progress_bar:
		return
	
	progress_bar.value = progress * 100.0
	
	# 更新倒计时文本
	var time_left = RESCUE_TIME - rescue_progress
	var label = progress_bar.get_node_or_null("Label")
	if label:
		label.text = "%.1f" % time_left

## 读条完成
func _on_reading_complete() -> void:
	_stop_reading()
	_show_rescue_ui()
	print("[GraveRescue] 读条完成，显示救援界面")

## 创建进度条
func _create_progress_bar() -> void:
	progress_bar = ProgressBar.new()
	progress_bar.size = Vector2(100, 10)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.visible = false
	progress_bar.z_index = 100
	
	# 设置样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.WHITE
	progress_bar.add_theme_stylebox_override("fill", style_box)
	
	# 添加倒计时标签
	var label = Label.new()
	label.name = "Label"
	label.text = "5.0"
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(35, -20)
	progress_bar.add_child(label)
	
	add_child(progress_bar)

## 创建范围圈
func _create_range_circle() -> void:
	# 创建一个简单的圆形精灵作为范围指示
	range_circle = Sprite2D.new()
	
	# 根据RESCUE_RANGE创建对应大小的圆形纹理
	var circle_diameter = int(RESCUE_RANGE * 2)  # 直径 = 范围 * 2
	var image = Image.create(circle_diameter, circle_diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center = circle_diameter / 2
	var ring_thickness = 4  # 圆环厚度
	
	# 绘制圆环
	for x in range(circle_diameter):
		for y in range(circle_diameter):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(dx * dx + dy * dy)
			if dist >= RESCUE_RANGE - ring_thickness and dist <= RESCUE_RANGE + ring_thickness:
				image.set_pixel(x, y, Color(1, 1, 0, 0.5))  # 半透明黄色
	
	var texture = ImageTexture.create_from_image(image)
	range_circle.texture = texture
	range_circle.visible = false
	range_circle.z_index = 0
	
	add_child(range_circle)

## 显示救援界面
func _show_rescue_ui() -> void:
	# 检查是否有商店或其他UI已经打开
	var tree = get_tree()
	if tree and tree.paused:
		print("[GraveRescue] 游戏已暂停（可能商店已打开），取消显示救援界面")
		return
	
	if not rescue_ui:
		# 创建救援UI
		var rescue_ui_scene = load("res://scenes/UI/grave_rescue_ui.tscn")
		rescue_ui = rescue_ui_scene.instantiate()
		rescue_ui.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也能运行
		get_tree().root.add_child(rescue_ui)
		
		# 连接信号
		rescue_ui.rescue_requested.connect(_on_rescue_requested)
		rescue_ui.transcend_requested.connect(_on_transcend_requested)
		rescue_ui.cancelled.connect(_on_rescue_cancelled)
	
	# 显示界面
	if ghost_data:
		# 设置状态为RESCUING
		GameState.change_state(GameState.State.RESCUING)
		rescue_ui.show_rescue_dialog(ghost_data)
		# get_tree().paused = true  # 暂停游戏 - GameState会自动处理
		print("[GraveRescue] 显示救援UI")

## 救援请求
func _on_rescue_requested() -> void:
	print("[GraveRescue] 执行救援...")
	
	# 检查masterkey
	if GameMain.master_key < 1:
		print("[GraveRescue] Master Key不足")
		_restore_game_state()
		return
	
	# 消耗masterkey
	GameMain.master_key -= 1
	print("[GraveRescue] 消耗1个Master Key，剩余:", GameMain.master_key)
	
	# 创建Ghost
	_create_ghost_from_data()
	
	# 清除墓碑
	_cleanup_grave()
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[GraveRescue] 救援完成")

## 超度请求
func _on_transcend_requested() -> void:
	print("[GraveRescue] 执行超度...")
	
	# 清除墓碑
	_cleanup_grave()
	
	# 恢复游戏状态
	_restore_game_state()
	
	print("[GraveRescue] 超度完成")

## 取消救援
func _on_rescue_cancelled() -> void:
	print("[GraveRescue] 取消救援")
	_restore_game_state()

## 恢复游戏状态
func _restore_game_state() -> void:
	# 如果之前的状态是 WAVE_FIGHTING 或 WAVE_CLEARING，则恢复
	# 如果是其他状态（比如 PLAYER_DEAD），则不应该恢复为 FIGHTING
	if GameState.previous_state == GameState.State.WAVE_FIGHTING or GameState.previous_state == GameState.State.WAVE_CLEARING:
		GameState.change_state(GameState.previous_state)
	else:
		# 默认回退到 WAVE_FIGHTING，除非我们确实知道该去哪里
		# 更安全的做法是检查 GameState 历史或当前逻辑
		GameState.change_state(GameState.State.WAVE_FIGHTING)

## 从数据创建Ghost
func _create_ghost_from_data() -> void:
	if not ghost_data:
		push_error("[GraveRescue] Ghost数据为空")
		return
	
	print("[GraveRescue] 开始创建Ghost，职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())
	for i in range(ghost_data.weapons.size()):
		var w = ghost_data.weapons[i]
		print("[GraveRescue] 武器", i+1, ":", w.id, " Lv.", w.level)
	
	# 获取GhostManager
	var ghost_manager = get_tree().get_first_node_in_group("ghost_manager")
	if not ghost_manager:
		push_error("[GraveRescue] 找不到GhostManager")
		return
	
	# 创建Ghost
	var ghost_scene = load("res://scenes/players/ghost.tscn")
	var new_ghost = ghost_scene.instantiate()
	
	# 设置Ghost数据（在add_child之前）
	new_ghost.class_id = ghost_data.class_id
	new_ghost.ghost_weapons = ghost_data.weapons.duplicate()  # 复制数组
	
	# 设置Ghost的名字和死亡次数（从GhostData获取）
	new_ghost.set_name_from_ghost_data(ghost_data.player_name, ghost_data.total_death_count)
	
	print("[GraveRescue] Ghost数据已设置，class_id:", new_ghost.class_id, " ghost_weapons数量:", new_ghost.ghost_weapons.size())
	print("[GraveRescue] Ghost名字:", ghost_data.player_name, " 死亡次数:", ghost_data.total_death_count)
	
	# 设置初始位置（在add_child之前）
	if grave_sprite and is_instance_valid(grave_sprite):
		new_ghost.global_position = grave_sprite.global_position
	
	# 先添加到场景（这样_ready会触发，@onready变量会被赋值）
	get_tree().root.add_child(new_ghost)
	
	# 添加到GhostManager
	ghost_manager.ghosts.append(new_ghost)
	
	# 延迟初始化Ghost（等待_ready完成后）
	if player:
		var queue_index = ghost_manager.ghosts.size() - 1
		var player_speed = ghost_manager._get_player_speed() if ghost_manager.has_method("_get_player_speed") else 400.0
		new_ghost.call_deferred("initialize", player, queue_index, player_speed, true)  # use_existing_data = true
	
	print("[GraveRescue] Ghost创建成功！职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())

## 清除墓碑和相关资源
func _cleanup_grave() -> void:
	# 清除墓碑精灵
	if grave_sprite and is_instance_valid(grave_sprite):
		grave_sprite.queue_free()
	
	# 清除Ghost数据
	ghost_data = null
	
	# 清除自身
	cleanup()
	
	print("[GraveRescue] 墓碑和资源已清除")

## 清理
func cleanup() -> void:
	if progress_bar and is_instance_valid(progress_bar):
		progress_bar.queue_free()
	if range_circle and is_instance_valid(range_circle):
		range_circle.queue_free()
	if rescue_ui and is_instance_valid(rescue_ui):
		rescue_ui.queue_free()
	queue_free()

## 设置引用
func set_player(p: CharacterBody2D) -> void:
	player = p
	print("[GraveRescue] 设置玩家引用:", player)

func set_grave(g: Sprite2D) -> void:
	grave_sprite = g

func set_ghost_data(data: GhostData) -> void:
	ghost_data = data

func set_death_manager(dm: Node) -> void:
	death_manager = dm

## 更新位置（跟随墓碑）
func update_position() -> void:
	if grave_sprite and is_instance_valid(grave_sprite):
		global_position = grave_sprite.global_position
		
		# 更新进度条位置（墓碑上方，向上50）
		if progress_bar:
			progress_bar.position = Vector2(-50, -90)
		
		# 更新范围圈位置
		if range_circle:
			range_circle.position = Vector2.ZERO

## 强制停止读条（玩家死亡或其他中断）
func force_stop_reading() -> void:
	print("[GraveRescue] 强制停止读条")
	
	if is_reading:
		_stop_reading()
	
	# 重置所有状态
	is_in_range = false
	rescue_progress = 0.0
	is_reading = false
	
	# 隐藏救援UI
	if rescue_ui and rescue_ui.visible:
		rescue_ui.hide_dialog()
		get_tree().paused = false
	
	# 隐藏范围圈和进度条
	if range_circle:
		range_circle.visible = false
	if progress_bar:
		progress_bar.visible = false
