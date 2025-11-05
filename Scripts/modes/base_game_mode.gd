extends Node
class_name BaseGameMode

## 游戏模式基类
## 为多模式支持建立抽象接口

## 模式信息
var mode_id: String = "base"
var mode_name: String = "基础模式"
var mode_description: String = ""

## 引用
var session: GameSession = null
var state_machine: GameStateMachine = null
var map_controller: Node = null
var wave_controller: Node = null

## 信号
signal mode_started()
signal mode_ended()
signal victory_achieved()
signal defeat_occurred()

func _init() -> void:
	print("[BaseGameMode] 创建游戏模式: %s" % mode_name)

## 初始化模式
func initialize() -> void:
	# 获取引用
	if GameMain.current_session:
		session = GameMain.current_session
	
	state_machine = GameState
	
	print("[BaseGameMode] 模式初始化: %s" % mode_name)

# ========== 虚函数：子类必须实现 ==========

## 设置模式
func setup_mode() -> void:
	push_warning("[BaseGameMode] setup_mode() 应在子类中实现")

## 获取胜利条件
func get_victory_condition() -> Dictionary:
	return {
		"type": "none",
		"description": "无胜利条件"
	}

## 获取失败条件
func get_defeat_condition() -> Dictionary:
	return {
		"type": "none",
		"description": "无失败条件"
	}

## 波次完成回调
func on_wave_complete(wave: int) -> void:
	print("[BaseGameMode] 波次 %d 完成" % wave)

## 玩家死亡回调
func on_player_death() -> void:
	print("[BaseGameMode] 玩家死亡")

## 玩家复活回调
func on_player_revived() -> void:
	print("[BaseGameMode] 玩家复活")

# ========== 通用方法 ==========

## 开始模式
func start_mode() -> void:
	setup_mode()
	mode_started.emit()
	print("[BaseGameMode] 模式开始: %s" % mode_name)

## 结束模式
func end_mode() -> void:
	mode_ended.emit()
	print("[BaseGameMode] 模式结束: %s" % mode_name)

## 检查胜利条件
func check_victory() -> bool:
	var condition = get_victory_condition()
	var type = condition.get("type", "none")
	
	match type:
		"collect_keys":
			var target = condition.get("target", 0)
			if session and session.gold >= target:
				_trigger_victory()
				return true
		"survive_waves":
			var target_wave = condition.get("target", 0)
			if session and session.current_wave >= target_wave:
				_trigger_victory()
				return true
	
	return false

## 检查失败条件
func check_defeat() -> bool:
	var condition = get_defeat_condition()
	var type = condition.get("type", "none")
	
	match type:
		"no_revives":
			if session and session.gold < GameConfig.revive_base_cost * (session.revive_count + 1):
				_trigger_defeat()
				return true
	
	return false

## 触发胜利
func _trigger_victory() -> void:
	print("[BaseGameMode] ========== 胜利！ ==========")
	victory_achieved.emit()
	state_machine.change_state(GameStateMachine.State.GAME_VICTORY)

## 触发失败
func _trigger_defeat() -> void:
	print("[BaseGameMode] ========== 失败！ ==========")
	defeat_occurred.emit()
	state_machine.change_state(GameStateMachine.State.GAME_OVER)

## 获取模式信息
func get_mode_info() -> Dictionary:
	return {
		"id": mode_id,
		"name": mode_name,
		"description": mode_description,
		"victory": get_victory_condition(),
		"defeat": get_defeat_condition()
	}

