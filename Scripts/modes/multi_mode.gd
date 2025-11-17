extends BaseGameMode
class_name MultiMode

## Multi模式 - 无复活，每波刷新墓碑
## 核心特性：
## - 角色不可复活
## - 每波开始时刷新对应wave死亡的ghost墓碑
## - 可以拯救墓碑复活为ghost

## 是否允许复活
var allow_revive: bool = false

func _init() -> void:
	mode_id = "multi"
	mode_name = "Multi模式"
	mode_description = "无复活模式，拯救墓碑获得援助"
	total_waves = GameConfig.total_waves
	victory_condition_type = "waves"
	allow_revive = false

## 获取当前波次配置（与survival模式一致）
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
	# Multi模式：完成40波即胜利
	var wave_manager = Engine.get_main_loop().get_first_node_in_group("wave_manager")
	if wave_manager and "current_wave" in wave_manager:
		return wave_manager.current_wave >= GameConfig.multi_mode_victory_waves
	return false

## 检查失败条件（Multi模式：玩家死亡即失败）
func check_defeat_condition() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return false
	
	# Multi模式下，玩家死亡即失败（不检查复活条件）
	if "is_dead" in player and player.is_dead:
		return true
	
	return false

## 是否允许复活
func can_revive() -> bool:
	return allow_revive

