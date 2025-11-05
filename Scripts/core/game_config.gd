extends Node
class_name GameConfig

## 游戏配置系统 - 集中管理所有硬编码配置

# 玩家配置
var base_speed: float = 400.0
var base_max_hp: int = 100
var base_defense: int = 0
var base_max_exp: int = 5

# 胜利条件
var keys_required: int = 200

# Ghost配置
var ghost_path_record_distance: float = 5.0
var ghost_follow_distance: float = 5.0
var ghost_follow_speed: float = 400.0
var ghost_interval: int = 8
var ghost_path_length: int = 30
var max_path_points: int = 300

# 经济配置
var revive_base_cost: int = 5
var shop_refresh_base_cost: int = 2

# 武器配置
var max_weapon_count: int = 6
var weapon_radius: float = 230.0

# 死亡配置
var death_delay: float = 1.5

# 波次配置
var total_waves: int = 200
var wave_first_base_count: int = 9
var wave_enemy_increment: int = 2
var enemy_ratio_basic: float = 0.5
var enemy_ratio_fast: float = 0.2
var enemy_ratio_tank: float = 0.2
var enemy_ratio_elite: float = 0.1

func _ready() -> void:
	print("[GameConfig] 游戏配置已加载 | 胜利条件: %d 钥匙" % keys_required)
