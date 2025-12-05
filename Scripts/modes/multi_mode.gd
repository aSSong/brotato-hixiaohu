extends BaseGameMode
class_name MultiMode

## Multi模式 - 无复活，每波刷新墓碑
## 核心特性：
## - 角色不可复活
## - 每波开始时刷新对应wave死亡的ghost墓碑
## - 可以拯救墓碑复活为ghost

func _init() -> void:
	mode_id = "multi"
	mode_name = "Multi模式"
	mode_description = "无复活模式，拯救墓碑获得援助"
	total_waves = GameConfig.total_waves
	victory_condition_type = "waves"
	#victory_condition_type = "keys"
	wave_config_id = "default"  # 使用默认波次配置（从JSON加载）
	victory_waves = 40  # Multi模式胜利条件：完成40波
	#victory_keys = 30  # 生存模式胜利条件：收集200把钥匙
	#victory_waves = GameConfig.multi_mode_victory_waves  # 从GameConfig读取胜利波数
	allow_revive = false  # Multi模式不允许复活
	initial_gold = 10  # Multi模式初始gold数量
	initial_master_key = 3  # Multi模式初始masterkey数量

## 注意：波次配置已由wave_system_v3从JSON文件（wave_config_id）加载，不再使用硬编码配置
## 注意：胜利失败判定已由base_game_mode统一实现，通过配置参数控制

## 是否允许复活
func can_revive() -> bool:
	return allow_revive

## 注意：get_victory_description和get_progress_text已由base_game_mode统一实现
