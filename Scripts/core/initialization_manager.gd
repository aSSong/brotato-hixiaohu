extends Node
class_name InitializationManager

## 初始化管理器
## 建立明确的初始化生命周期，减少盲目的帧等待

## 初始化阶段
enum InitPhase {
	NONE,                  # 未初始化
	SCENE_LOADED,          # 场景加载完成
	AUTOLOAD_READY,        # 自动加载脚本就绪
	MANAGERS_CREATED,      # 管理器创建完成
	PLAYER_READY,          # 玩家就绪
	SYSTEMS_READY,         # 游戏系统就绪
	GAME_READY,            # 游戏完全就绪
}

## 信号
signal phase_completed(phase: InitPhase)
signal phase_started(phase: InitPhase)
signal initialization_complete()

## 当前阶段
var current_phase: InitPhase = InitPhase.NONE

## 是否正在初始化
var is_initializing: bool = false

func _init() -> void:
	print("[InitializationManager] 初始化管理器创建")

## 开始初始化阶段
func start_phase(phase: InitPhase) -> void:
	if current_phase >= phase:
		push_warning("[InitializationManager] 阶段 %s 已完成，跳过" % _get_phase_name(phase))
		return
	
	print("[InitializationManager] 开始阶段: %s" % _get_phase_name(phase))
	current_phase = phase
	phase_started.emit(phase)

## 完成当前阶段
func complete_phase(phase: InitPhase) -> void:
	if current_phase != phase:
		push_warning("[InitializationManager] 阶段不匹配 | 当前: %s, 完成: %s" % [_get_phase_name(current_phase), _get_phase_name(phase)])
		return
	
	print("[InitializationManager] 完成阶段: %s" % _get_phase_name(phase))
	phase_completed.emit(phase)
	
	# 如果是最后阶段，发出完成信号
	if phase == InitPhase.GAME_READY:
		initialization_complete.emit()
		is_initializing = false
		print("[InitializationManager] ========== 游戏初始化完成 ==========")

## 等待特定阶段完成
func wait_for_phase(target_phase: InitPhase) -> void:
	if current_phase >= target_phase:
		return  # 已经完成
	
	print("[InitializationManager] 等待阶段: %s" % _get_phase_name(target_phase))
	
	while current_phase < target_phase:
		await phase_completed
		
		# 检查是否达到目标阶段
		if current_phase >= target_phase:
			break

## 等待游戏完全就绪
func wait_for_game_ready() -> void:
	await wait_for_phase(InitPhase.GAME_READY)

## 检查是否已完成特定阶段
func is_phase_complete(phase: InitPhase) -> bool:
	return current_phase >= phase

## 检查是否在特定阶段
func is_in_phase(phase: InitPhase) -> bool:
	return current_phase == phase

## 获取阶段名称（用于日志）
func _get_phase_name(phase: InitPhase) -> String:
	match phase:
		InitPhase.NONE: return "NONE"
		InitPhase.SCENE_LOADED: return "SCENE_LOADED"
		InitPhase.AUTOLOAD_READY: return "AUTOLOAD_READY"
		InitPhase.MANAGERS_CREATED: return "MANAGERS_CREATED"
		InitPhase.PLAYER_READY: return "PLAYER_READY"
		InitPhase.SYSTEMS_READY: return "SYSTEMS_READY"
		InitPhase.GAME_READY: return "GAME_READY"
		_: return "UNKNOWN"

## 获取初始化状态信息
func get_status() -> Dictionary:
	return {
		"current_phase": _get_phase_name(current_phase),
		"is_initializing": is_initializing,
		"phase_value": current_phase
	}

## 重置初始化状态（用于场景切换）
func reset() -> void:
	current_phase = InitPhase.NONE
	is_initializing = false
	print("[InitializationManager] 初始化状态已重置")

