extends Node
class_name VictoryController

## 胜利条件控制器
## 监听游戏状态，判断是否达成胜利条件

signal victory_triggered()

var session: GameSession = null
var victory_triggered_flag: bool = false

func _ready() -> void:
	# 等待一帧确保所有自动加载完成
	await get_tree().process_frame
	
	# 获取当前会话
	if GameMain.current_session:
		session = GameMain.current_session
		session.gold_changed.connect(_check_victory)
		print("[VictoryController] 已连接到游戏会话")
	else:
		push_error("[VictoryController] 未找到游戏会话！")

## 检查是否达成胜利条件
func _check_victory(new_amount: int, _change: int) -> void:
	if victory_triggered_flag:
		return
	
	var victory_condition = GameConfig.keys_required
	
	if new_amount >= victory_condition:
		victory_triggered_flag = true
		victory_triggered.emit()
		_trigger_victory()
		print("[VictoryController] 胜利条件达成！钥匙: %d/%d" % [new_amount, victory_condition])

## 触发胜利
func _trigger_victory() -> void:
	# 延迟一下再跳转
	await get_tree().create_timer(1.0).timeout
	
	# 加载胜利UI场景
	var victory_scene = load("res://scenes/UI/victory_ui.tscn")
	if victory_scene:
		get_tree().change_scene_to_packed(victory_scene)
	else:
		push_error("[VictoryController] 无法加载胜利UI场景！")

## 重置状态
func reset() -> void:
	victory_triggered_flag = false

