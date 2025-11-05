extends Node
class_name GameConfig

## 游戏配置系统
## 集中管理所有硬编码的游戏配置

# ========== 玩家配置 ==========
## 玩家基础移动速度
var base_speed: float = 400.0

## 玩家基础最大血量
var base_max_hp: int = 100

## 玩家基础防御
var base_defense: int = 0

## 玩家基础经验需求
var base_max_exp: int = 5

# ========== 胜利条件 ==========
## 达到胜利需要收集的钥匙数量
var keys_required: int = 200

# ========== Ghost配置 ==========
## Ghost路径记录间隔（像素）
var ghost_path_record_distance: float = 5.0

## Ghost跟随距离（像素）
var ghost_follow_distance: float = 5.0

## Ghost跟随速度
var ghost_follow_speed: float = 400.0

## Ghost之间的间隔路径点数
var ghost_interval: int = 8

## 每个Ghost保留的路径点数量
var ghost_path_length: int = 30

## 最多记录的路径点数量
var max_path_points: int = 300

# ========== 经济配置 ==========
## 复活基础费用（每次复活费用 = base * (revive_count + 1)）
var revive_base_cost: int = 5

## 商店刷新基础费用（每次刷新费用 = base * 2^refresh_count）
var shop_refresh_base_cost: int = 2

# ========== 武器配置 ==========
## 最大武器数量
var max_weapon_count: int = 6

## 武器环绕半径
var weapon_radius: float = 230.0

# ========== 死亡配置 ==========
## 死亡后显示UI的延迟时间（秒）
var death_delay: float = 1.5

# ========== 波次配置 ==========
## 总波次数
var total_waves: int = 200

## 第一波基础敌人数（不含BOSS）
var wave_first_base_count: int = 9

## 每波敌人增加数量
var wave_enemy_increment: int = 2

## 敌人类型配比
var enemy_ratio_basic: float = 0.5    # 50%基础敌人
var enemy_ratio_fast: float = 0.2     # 20%快速敌人
var enemy_ratio_tank: float = 0.2     # 20%坦克敌人
var enemy_ratio_elite: float = 0.1    # 10%精英敌人

func _ready() -> void:
	print("[GameConfig] 游戏配置已加载")
	print("  - 胜利条件: %d 钥匙" % keys_required)
	print("  - 玩家基础属性: HP=%d, 速度=%.1f" % [base_max_hp, base_speed])
	print("  - 复活费用: %d 钥匙起" % revive_base_cost)

