extends BaseGameMode
class_name SurvivalMode

## 生存模式
## 收集足够的钥匙获得胜利

func _init() -> void:
	mode_id = "survival"
	mode_name = "生存模式"
	mode_description = "收集 %d 个钥匙以获得胜利" % GameConfig.keys_required
	super._init()

## 设置模式
func setup_mode() -> void:
	print("[SurvivalMode] 设置生存模式")
	print("  - 胜利条件: 收集 %d 个钥匙" % GameConfig.keys_required)
	print("  - 波次数: %d 波" % GameConfig.total_waves)
	
	# 连接金币变化信号以检查胜利条件
	if session:
		if not session.gold_changed.is_connected(_on_gold_changed):
			session.gold_changed.connect(_on_gold_changed)

## 获取胜利条件
func get_victory_condition() -> Dictionary:
	return {
		"type": "collect_keys",
		"target": GameConfig.keys_required,
		"description": "收集 %d 个钥匙" % GameConfig.keys_required
	}

## 获取失败条件
func get_defeat_condition() -> Dictionary:
	return {
		"type": "player_give_up",
		"description": "玩家主动放弃或无法复活"
	}

## 波次完成回调
func on_wave_complete(wave: int) -> void:
	super.on_wave_complete(wave)
	
	# 每波完成后打开商店
	if state_machine:
		state_machine.change_state(GameStateMachine.State.SHOP_OPEN)
	
	print("[SurvivalMode] 波次 %d/%d 完成" % [wave, GameConfig.total_waves])

## 玩家死亡回调
func on_player_death() -> void:
	super.on_player_death()
	
	if state_machine:
		state_machine.change_state(GameStateMachine.State.PLAYER_DEAD)
	
	# 检查是否能复活
	var economy = EconomyController.new()
	if not economy.can_revive():
		print("[SurvivalMode] 玩家无法复活，可能导致游戏结束")

## 玩家复活回调
func on_player_revived() -> void:
	super.on_player_revived()
	
	if state_machine:
		state_machine.change_state(GameStateMachine.State.WAVE_FIGHTING)

## 金币变化时检查胜利条件
func _on_gold_changed(new_amount: int, _change: int) -> void:
	if new_amount >= GameConfig.keys_required:
		check_victory()

## 获取模式统计
func get_mode_stats() -> Dictionary:
	if not session:
		return {}
	
	return {
		"keys_collected": session.gold,
		"keys_required": GameConfig.keys_required,
		"progress": float(session.gold) / float(GameConfig.keys_required),
		"current_wave": session.current_wave,
		"total_waves": GameConfig.total_waves,
		"revive_count": session.revive_count
	}

## 打印模式统计
func print_stats() -> void:
	var stats = get_mode_stats()
	print("[SurvivalMode] 模式统计:")
	print("  - 钥匙: %d/%d (%.1f%%)" % [
		stats.get("keys_collected", 0),
		stats.get("keys_required", 0),
		stats.get("progress", 0.0) * 100
	])
	print("  - 波次: %d/%d" % [
		stats.get("current_wave", 0),
		stats.get("total_waves", 0)
	])
	print("  - 复活次数: %d" % stats.get("revive_count", 0))

