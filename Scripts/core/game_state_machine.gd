extends Node

## 游戏状态机 - 统一管理游戏状态

## 游戏状态枚举
enum State {
	NONE = 0,
	MAIN_MENU = 1,           # 主菜单
	CHARACTER_SELECT = 2,     # 角色选择
	GAME_INITIALIZING = 3,   # 游戏初始化中
	WAVE_FIGHTING = 4,        # 波次战斗中
	WAVE_CLEARING = 5,        # 波次结算中
	SHOPPING = 6,             # 商店购物中
	PLAYER_DEAD = 7,          # 玩家死亡
	GAME_PAUSED = 8,          # 游戏暂停
	GAME_VICTORY = 9,         # 游戏胜利
	GAME_OVER = 10            # 游戏结束
}

signal state_changed(old_state: State, new_state: State)
signal state_entered(state: State)
signal state_exited(state: State)

var current_state: State = State.NONE
var previous_state: State = State.NONE
var state_history: Array = []

func _ready() -> void:
	print("[GameState] 状态机就绪")

## 切换状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		print("[GameState] 状态已经是 %s，跳过切换" % _state_name(new_state))
		return
	
	var old_state = current_state
	
	# 退出当前状态
	if current_state != State.NONE:
		_exit_state(current_state)
	
	# 记录历史
	previous_state = current_state
	state_history.append(current_state)
	
	# 切换状态
	current_state = new_state
	
	print("[GameState] 状态切换: %s -> %s" % [_state_name(old_state), _state_name(new_state)])
	
	# 进入新状态
	_enter_state(new_state)
	
	# 发出信号
	state_changed.emit(old_state, new_state)

## 进入状态
func _enter_state(state: State) -> void:
	print("[GameState] 进入状态: %s" % _state_name(state))
	
	match state:
		State.WAVE_FIGHTING:
			get_tree().paused = false
		State.SHOPPING:
			get_tree().paused = true
		State.PLAYER_DEAD:
			get_tree().paused = true
		State.GAME_PAUSED:
			get_tree().paused = true
		State.GAME_VICTORY, State.GAME_OVER:
			get_tree().paused = false
	
	state_entered.emit(state)

## 退出状态
func _exit_state(state: State) -> void:
	print("[GameState] 退出状态: %s" % _state_name(state))
	state_exited.emit(state)

## 检查是否在指定状态
func is_in_state(state: State) -> bool:
	return current_state == state

## 检查是否在任意指定状态中
func is_in_any_state(states: Array) -> bool:
	return current_state in states

## 返回上一个状态
func return_to_previous_state() -> void:
	if previous_state != State.NONE:
		change_state(previous_state)
	else:
		push_warning("[GameState] 没有可返回的上一个状态")

## 获取状态名称
func _state_name(state: State) -> String:
	match state:
		State.NONE: return "NONE"
		State.MAIN_MENU: return "MAIN_MENU"
		State.CHARACTER_SELECT: return "CHARACTER_SELECT"
		State.GAME_INITIALIZING: return "GAME_INITIALIZING"
		State.WAVE_FIGHTING: return "WAVE_FIGHTING"
		State.WAVE_CLEARING: return "WAVE_CLEARING"
		State.SHOPPING: return "SHOPPING"
		State.PLAYER_DEAD: return "PLAYER_DEAD"
		State.GAME_PAUSED: return "GAME_PAUSED"
		State.GAME_VICTORY: return "GAME_VICTORY"
		State.GAME_OVER: return "GAME_OVER"
		_: return "UNKNOWN"

## 重置状态机
func reset() -> void:
	current_state = State.NONE
	previous_state = State.NONE
	state_history.clear()
	get_tree().paused = false
	print("[GameState] 状态机已重置")
