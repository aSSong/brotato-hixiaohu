extends Node
class_name BaseGameMode

## 游戏模式基类 - 定义所有游戏模式的通用接口

signal mode_started()
signal mode_ended()
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)

## 模式配置
var mode_id: String = ""
var mode_name: String = ""
var mode_description: String = ""
var total_waves: int = 20
var victory_condition_type: String = "waves"  # "waves", "keys", "time", "survival"

## 初始化模式
func initialize(config: Dictionary = {}) -> void:
	mode_id = config.get("mode_id", "")
	mode_name = config.get("mode_name", "未命名模式")
	mode_description = config.get("mode_description", "")
	total_waves = config.get("total_waves", 20)
	victory_condition_type = config.get("victory_condition", "waves")
	print("[BaseGameMode] 模式初始化: %s (%s)" % [mode_name, mode_id])

## 开始模式
func start_mode() -> void:
	print("[BaseGameMode] 模式开始: %s" % mode_name)
	mode_started.emit()

## 结束模式
func end_mode() -> void:
	print("[BaseGameMode] 模式结束: %s" % mode_name)
	mode_ended.emit()

## 检查胜利条件
func check_victory_condition() -> bool:
	match victory_condition_type:
		"waves":
			return _check_waves_victory()
		"keys":
			return _check_keys_victory()
		"time":
			return _check_time_victory()
		"survival":
			return false  # 生存模式没有胜利，只有失败
	return false

## 检查失败条件
func check_defeat_condition() -> bool:
	return false  # 由子类实现

## 获取当前波次配置
func get_wave_config(wave_number: int) -> Dictionary:
	return {}  # 由子类实现

## 波次检查（由子类重写）
func _check_waves_victory() -> bool:
	return false

func _check_keys_victory() -> bool:
	return GameMain.gold >= GameConfig.keys_required

func _check_time_victory() -> bool:
	return false

## 获取模式信息
func get_mode_info() -> Dictionary:
	return {
		"id": mode_id,
		"name": mode_name,
		"description": mode_description,
		"total_waves": total_waves,
		"victory_condition": victory_condition_type
	}
