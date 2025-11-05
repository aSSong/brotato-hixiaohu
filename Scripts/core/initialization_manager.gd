extends Node

## 初始化管理器 - 统一管理游戏初始化顺序

## 初始化阶段
enum InitPhase {
	NONE = 0,
	AUTOLOAD_READY = 1,      # 自动加载就绪
	SCENE_LOADED = 2,         # 场景加载完成
	MANAGERS_CREATED = 3,     # 管理器创建完成
	PLAYER_READY = 4,         # 玩家就绪
	SYSTEMS_READY = 5,        # 系统就绪
	GAME_READY = 6            # 游戏完全就绪
}

signal phase_started(phase: InitPhase)
signal phase_completed(phase: InitPhase)
signal initialization_complete()

var current_phase: InitPhase = InitPhase.NONE
var is_initializing: bool = false
var completed_phases: Array[InitPhase] = []

func _ready() -> void:
	print("[InitManager] 初始化管理器就绪")

## 开始一个初始化阶段
func start_phase(phase: InitPhase) -> void:
	if current_phase == phase:
		push_warning("[InitManager] 阶段已经开始: %s" % _phase_name(phase))
		return
	
	current_phase = phase
	print("[InitManager] ========== 开始阶段: %s ==========" % _phase_name(phase))
	phase_started.emit(phase)

## 完成当前初始化阶段
func complete_phase(phase: InitPhase) -> void:
	if current_phase != phase:
		push_warning("[InitManager] 阶段不匹配: 当前=%s, 请求完成=%s" % [_phase_name(current_phase), _phase_name(phase)])
		return
	
	completed_phases.append(phase)
	print("[InitManager] ========== 完成阶段: %s ==========" % _phase_name(phase))
	phase_completed.emit(phase)
	
	# 如果是最后一个阶段，发出初始化完成信号
	if phase == InitPhase.GAME_READY:
		is_initializing = false
		print("[InitManager] ========== 游戏初始化完全完成 ==========")
		initialization_complete.emit()

## 检查阶段是否已完成
func is_phase_completed(phase: InitPhase) -> bool:
	return phase in completed_phases

## 等待阶段完成
func wait_for_phase(phase: InitPhase) -> void:
	if is_phase_completed(phase):
		return
	
	# 等待信号
	while not is_phase_completed(phase):
		await get_tree().process_frame

## 重置初始化状态
func reset() -> void:
	current_phase = InitPhase.NONE
	is_initializing = false
	completed_phases.clear()
	print("[InitManager] 初始化状态已重置")

## 获取阶段名称
func _phase_name(phase: InitPhase) -> String:
	match phase:
		InitPhase.NONE: return "NONE"
		InitPhase.AUTOLOAD_READY: return "AUTOLOAD_READY"
		InitPhase.SCENE_LOADED: return "SCENE_LOADED"
		InitPhase.MANAGERS_CREATED: return "MANAGERS_CREATED"
		InitPhase.PLAYER_READY: return "PLAYER_READY"
		InitPhase.SYSTEMS_READY: return "SYSTEMS_READY"
		InitPhase.GAME_READY: return "GAME_READY"
		_: return "UNKNOWN"
