extends BaseGameMode
class_name SurvivalMode

## 生存模式 - 当前游戏的默认模式

func _init() -> void:
	mode_id = "survival"
	mode_name = "生存模式"
	mode_description = "收集200个钥匙以获得胜利"
	total_waves = GameConfig.total_waves
	victory_condition_type = "keys"

## 获取当前波次配置
func get_wave_config(wave_number: int) -> Dictionary:
	# 计算敌人数量
	var base_count = GameConfig.wave_first_base_count
	var increment = GameConfig.wave_enemy_increment
	var total_enemies = base_count + (wave_number - 1) * increment
	
	# 计算不同类型敌人的数量
	var basic_count = int(total_enemies * GameConfig.enemy_ratio_basic)
	var fast_count = int(total_enemies * GameConfig.enemy_ratio_fast)
	var tank_count = int(total_enemies * GameConfig.enemy_ratio_tank)
	var elite_count = int(total_enemies * GameConfig.enemy_ratio_elite)
	
	# 确保至少有基础敌人
	if basic_count == 0:
		basic_count = 1
	
	return {
		"wave_number": wave_number,
		"total_enemies": total_enemies,
		"enemy_types": {
			"basic": basic_count,
			"fast": fast_count,
			"tank": tank_count,
			"elite": elite_count
		},
		"spawn_interval": 1.0,  # 生成间隔（秒）
		"spawn_batch_size": 3    # 每批生成数量
	}

## 检查波次胜利
func _check_waves_victory() -> bool:
	if GameMain.current_session:
		return GameMain.current_session.current_wave >= total_waves
	return false

## 检查失败条件（玩家死亡且金币不足复活）
func check_defeat_condition() -> bool:
	# 生存模式中，如果玩家死亡且无法复活，则失败
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return false
	
	if player.has("is_dead") and player.is_dead:
		var revive_cost = GameConfig.revive_base_cost * (GameMain.revive_count + 1)
		if GameMain.gold < revive_cost:
			return true
	
	return false
