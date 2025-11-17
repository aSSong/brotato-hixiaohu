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

## 获取胜利条件描述文本
func get_victory_description() -> String:
	match victory_condition_type:
		"keys":
			return "持有钥匙 %d 把" % GameConfig.keys_required
		"waves":
			return "完成消灭 %d 波敌人" % total_waves
		"time":
			return "生存指定时间"
		"survival":
			return "尽可能生存"
	return "未知目标"

## 获取当前进度文本
func get_progress_text() -> String:
	match victory_condition_type:
		"keys":
			return "已持有 %d 把" % GameMain.gold
		"waves":
			var wave_manager = Engine.get_main_loop().get_first_node_in_group("wave_manager")
			if wave_manager and "current_wave" in wave_manager:
				# 已消灭的波数 = 当前波次 - 1（因为当前波次还在进行中）
				# 如果波次没在进行，说明是波次结束后，已消灭数就是当前波次号
				var completed_waves = wave_manager.current_wave
				if "is_wave_in_progress" in wave_manager and wave_manager.is_wave_in_progress:
					completed_waves -= 1
				return "已消灭 %d 波" % completed_waves
			return "已消灭 0 波"
		"time":
			return "已生存 0 秒"
		"survival":
			return ""
	return ""

## 获取完整的 KPI 文本
func get_kpi_text() -> String:
	var desc = get_victory_description()
	var progress = get_progress_text()
	
	if progress.is_empty():
		return "目标：%s" % desc
	else:
		return "目标：%s（%s）" % [desc, progress]
