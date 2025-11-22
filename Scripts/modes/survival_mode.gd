extends BaseGameMode
class_name SurvivalMode

## 生存模式 - 当前游戏的默认模式

func _init() -> void:
	mode_id = "survival"
	mode_name = "生存模式"
	mode_description = "收集200个钥匙以获得胜利"
	total_waves = GameConfig.total_waves
	victory_condition_type = "keys"
	wave_config_id = "default"  # 使用默认波次配置（从JSON加载）
	victory_keys = GameConfig.keys_required  # 从GameConfig读取胜利钥匙数
	allow_revive = true  # 生存模式允许复活

## 注意：波次配置已由wave_system_v3从JSON文件（wave_config_id）加载，不再使用硬编码配置
## 注意：胜利失败判定已由base_game_mode统一实现，通过配置参数控制