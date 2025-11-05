extends Node
class_name GameStateMachine

## 游戏状态机
## 统一管理游戏状态，避免状态分散在多个Manager中

## 游戏状态枚举
enum State {
	NONE,                  # 无状态
	MAIN_MENU,             # 主菜单
	CHARACTER_SELECT,      # 角色选择
	GAME_INITIALIZING,     # 游戏初始化中
	WAVE_FIGHTING,         # 波次战斗中
	WAVE_COMPLETE,         # 波次完成
	SHOP_OPEN,             # 商店开启
	PLAYER_DEAD,           # 玩家死亡
	PLAYER_REVIVING,       # 玩家复活中
	GRAVE_RESCUING,        # 墓碑救援中
	GAME_PAUSED,           # 游戏暂停
	GAME_VICTORY,          # 游戏胜利
	GAME_OVER,             # 游戏结束
}

## 信号
signal state_changed(from_state: State, to_state: State)
signal state_entered(state: State)
signal state_exited(state: State)

## 当前状态
var current_state: State = State.NONE

## 上一个状态
var previous_state: State = State.NONE

## 状态历史（用于调试）
var state_history: Array[State] = []
var max_history_size: int = 10

func _init() -> void:
	print("[GameStateMachine] 状态机初始化")

## 改变状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		push_warning("[GameStateMachine] 已经在状态: %s" % _get_state_name(new_state))
		return
	
	# 记录历史
	_add_to_history(current_state)
	
	# 退出旧状态
	if current_state != State.NONE:
		print("[GameStateMachine] 退出状态: %s" % _get_state_name(current_state))
		state_exited.emit(current_state)
	
	# 保存旧状态
	previous_state = current_state
	current_state = new_state
	
	# 发送状态变化信号
	print("[GameStateMachine] 状态变化: %s -> %s" % [_get_state_name(previous_state), _get_state_name(current_state)])
	state_changed.emit(previous_state, current_state)
	
	# 进入新状态
	print("[GameStateMachine] 进入状态: %s" % _get_state_name(current_state))
	state_entered.emit(current_state)

## 检查是否在指定状态
func is_in_state(state: State) -> bool:
	return current_state == state

## 检查是否在任一指定状态中
func is_in_any_state(states: Array) -> bool:
	for state in states:
		if current_state == state:
			return true
	return false

## 检查是否可以暂停
func can_pause() -> bool:
	# 在战斗或商店中可以暂停
	return is_in_any_state([State.WAVE_FIGHTING, State.SHOP_OPEN])

## 检查是否可以移动
func can_player_move() -> bool:
	# 只在战斗状态可以移动
	return current_state == State.WAVE_FIGHTING

## 检查是否可以攻击
func can_attack() -> bool:
	# 在战斗状态且玩家未死亡可以攻击
	return current_state == State.WAVE_FIGHTING

## 获取状态名称
func _get_state_name(state: State) -> String:
	match state:
		State.NONE: return "NONE"
		State.MAIN_MENU: return "MAIN_MENU"
		State.CHARACTER_SELECT: return "CHARACTER_SELECT"
		State.GAME_INITIALIZING: return "GAME_INITIALIZING"
		State.WAVE_FIGHTING: return "WAVE_FIGHTING"
		State.WAVE_COMPLETE: return "WAVE_COMPLETE"
		State.SHOP_OPEN: return "SHOP_OPEN"
		State.PLAYER_DEAD: return "PLAYER_DEAD"
		State.PLAYER_REVIVING: return "PLAYER_REVIVING"
		State.GRAVE_RESCUING: return "GRAVE_RESCUING"
		State.GAME_PAUSED: return "GAME_PAUSED"
		State.GAME_VICTORY: return "GAME_VICTORY"
		State.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"

## 添加到历史记录
func _add_to_history(state: State) -> void:
	if state == State.NONE:
		return
	
	state_history.append(state)
	
	# 限制历史大小
	while state_history.size() > max_history_size:
		state_history.pop_front()

## 获取状态信息（用于调试）
func get_status() -> Dictionary:
	return {
		"current": _get_state_name(current_state),
		"previous": _get_state_name(previous_state),
		"history": _get_history_names(),
		"can_pause": can_pause(),
		"can_move": can_player_move(),
		"can_attack": can_attack()
	}

## 获取历史状态名称
func _get_history_names() -> Array[String]:
	var names: Array[String] = []
	for state in state_history:
		names.append(_get_state_name(state))
	return names

## 重置状态机
func reset() -> void:
	current_state = State.NONE
	previous_state = State.NONE
	state_history.clear()
	print("[GameStateMachine] 状态机已重置")

