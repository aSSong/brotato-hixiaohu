extends Node2D
class_name Grave

## 统一墓碑组件
## 包含墓碑的视觉元素和救援交互逻辑

## 静态变量：当前正在读条的墓碑（确保同时只有一个墓碑在读条）
static var active_grave: Grave = null

## 信号
signal rescue_requested(ghost_data: GhostData)  # 请求救援
signal transcend_requested(ghost_data: GhostData)  # 请求超度
signal rescue_cancelled  # 取消救援

## 场景中的节点引用
@onready var grave_sprite: Sprite2D = $GraveSprite
@onready var name_label: Label = $GraveSprite/NameLabel
@onready var range_circle: Sprite2D = $RangeCircle
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var time_label: Label = $ProgressBar/TimeLabel

## 数据
var ghost_data: GhostData = null
var player: CharacterBody2D = null

## 救援范围
const RESCUE_RANGE: float = 400.0

## 读条相关
var is_in_range: bool = false
var rescue_progress: float = 0.0
const RESCUE_TIME: float = 2.0
var is_reading: bool = false

## 救援UI
var rescue_ui: CanvasLayer = null

func _ready() -> void:
	# 初始隐藏范围圈和进度条
	if range_circle:
		range_circle.visible = false
	if progress_bar:
		progress_bar.visible = false
	
	# 设置层级
	z_index = 20

func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	# 如果玩家死亡，隐藏所有UI并停止读条
	if player.now_hp <= 0:
		if is_reading:
			_stop_reading()
		if range_circle and range_circle.visible:
			range_circle.visible = false
		# 重置范围状态
		if is_in_range:
			is_in_range = false
		return
	
	# 检查玩家是否在范围内
	var distance = player.global_position.distance_to(global_position)
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

## 设置墓碑数据
func setup(data: GhostData, player_ref: CharacterBody2D) -> void:
	ghost_data = data
	player = player_ref
	
	# 更新名字标签
	_update_name_label()
	
	# 更新范围圈缩放（根据 RESCUE_RANGE）
	_setup_range_circle()
	
	print("[Grave] 墓碑设置完成 | 名字:", ghost_data.player_name, " 第", ghost_data.total_death_count, "世")

## 更新名字标签
func _update_name_label() -> void:
	if not name_label or not ghost_data:
		return
	
	var display_name = "%s - 第 %d 世" % [ghost_data.player_name, ghost_data.total_death_count]
	name_label.text = display_name

## 设置范围圈
func _setup_range_circle() -> void:
	if not range_circle or not range_circle.texture:
		return
	
	var target_diameter = RESCUE_RANGE * 2
	var texture_size = range_circle.texture.get_size().x
	if texture_size > 0:
		range_circle.scale = Vector2.ONE * (target_diameter / texture_size)

## 检查是否可以开始读条
func _can_start_reading() -> bool:
	if not player or not is_instance_valid(player):
		return false
	
	# 玩家死亡不能读条
	if player.now_hp <= 0:
		return false
	
	# 游戏暂停不能读条
	if get_tree().paused:
		return false
	
	# 救援界面打开时不能读条
	if rescue_ui and rescue_ui.visible:
		return false
	
	# 如果有其他墓碑正在读条，则不能开始
	if active_grave != null and active_grave != self and is_instance_valid(active_grave):
		return false
	
	return true

## 范围状态变化
func _on_range_changed(entered: bool) -> void:
	if entered:
		print("[Grave] 进入救援范围 | 玩家HP:", player.now_hp if player else "null")
	else:
		print("[Grave] 离开救援范围")

## 开始读条
func _start_reading() -> void:
	# 设置自己为当前活跃的墓碑
	active_grave = self
	
	is_reading = true
	rescue_progress = 0.0
	if range_circle:
		range_circle.visible = true
	if progress_bar:
		progress_bar.visible = true
	print("[Grave] 开始读条（已锁定）")

## 停止读条
func _stop_reading() -> void:
	is_reading = false
	rescue_progress = 0.0
	if range_circle:
		range_circle.visible = false
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0
	
	# 如果自己是当前活跃的墓碑，则释放锁定
	if active_grave == self:
		active_grave = null
		print("[Grave] 停止读条（已解锁）")
	else:
		print("[Grave] 停止读条")

## 更新进度条
func _update_progress_bar(progress: float) -> void:
	if not progress_bar:
		return
	
	progress_bar.value = progress * 100.0
	
	# 更新倒计时文本
	if time_label:
		var time_left = RESCUE_TIME - rescue_progress
		time_label.text = "%.1f" % time_left

## 读条完成
func _on_reading_complete() -> void:
	_stop_reading()
	_show_rescue_ui()
	print("[Grave] 读条完成，显示救援界面")

## 显示救援界面
func _show_rescue_ui() -> void:
	var tree = get_tree()
	if tree and tree.paused:
		print("[Grave] 游戏已暂停，取消显示救援界面")
		return
	
	if not rescue_ui:
		var rescue_ui_scene = load("res://scenes/UI/grave_rescue_ui.tscn")
		rescue_ui = rescue_ui_scene.instantiate()
		rescue_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(rescue_ui)
		
		# 连接信号
		rescue_ui.rescue_requested.connect(_on_rescue_ui_rescue)
		rescue_ui.transcend_requested.connect(_on_rescue_ui_transcend)
		rescue_ui.cancelled.connect(_on_rescue_ui_cancelled)
	
	if ghost_data:
		GameState.change_state(GameState.State.RESCUING)
		rescue_ui.show_rescue_dialog(ghost_data)
		print("[Grave] 显示救援UI")

## 救援UI：救援请求
func _on_rescue_ui_rescue() -> void:
	print("[Grave] 收到救援请求")
	# 释放锁定，允许其他墓碑读条
	_release_active_lock()
	rescue_requested.emit(ghost_data)

## 救援UI：超度请求
func _on_rescue_ui_transcend() -> void:
	print("[Grave] 收到超度请求")
	# 释放锁定，允许其他墓碑读条
	_release_active_lock()
	transcend_requested.emit(ghost_data)

## 救援UI：取消
func _on_rescue_ui_cancelled() -> void:
	print("[Grave] 救援取消")
	# 释放锁定，允许其他墓碑读条
	_release_active_lock()
	_restore_game_state()
	rescue_cancelled.emit()

## 释放活跃锁定
func _release_active_lock() -> void:
	if active_grave == self:
		active_grave = null
		print("[Grave] 已释放锁定")

## 恢复游戏状态
func _restore_game_state() -> void:
	if GameState.previous_state == GameState.State.WAVE_FIGHTING or GameState.previous_state == GameState.State.WAVE_CLEARING:
		GameState.change_state(GameState.previous_state)
	else:
		GameState.change_state(GameState.State.WAVE_FIGHTING)

## 强制停止读条
func force_stop_reading() -> void:
	print("[Grave] 强制停止读条")
	
	if is_reading:
		_stop_reading()
	
	is_in_range = false
	rescue_progress = 0.0
	is_reading = false
	
	# 释放锁定
	_release_active_lock()
	
	if rescue_ui and rescue_ui.visible:
		rescue_ui.hide_dialog()
		get_tree().paused = false
	
	if range_circle:
		range_circle.visible = false
	if progress_bar:
		progress_bar.visible = false

## 清理资源
func cleanup() -> void:
	# 释放锁定
	_release_active_lock()
	
	if rescue_ui and is_instance_valid(rescue_ui):
		rescue_ui.queue_free()
		rescue_ui = null
	queue_free()

## 节点移除时清理
func _exit_tree() -> void:
	# 释放锁定
	if active_grave == self:
		active_grave = null
	
	if rescue_ui and is_instance_valid(rescue_ui):
		rescue_ui.queue_free()
