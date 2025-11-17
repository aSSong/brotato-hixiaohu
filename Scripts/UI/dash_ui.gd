extends BaseSkillUI

## Dash UI 控制脚本
## 显示 Dash 技能的 CD 状态

var player_ref: CharacterBody2D = null

func _ready():
	super._ready()  # 调用基类初始化
	
	# 等待场景加载完成，获取玩家引用
	await get_tree().create_timer(0.2).timeout
	player_ref = get_tree().get_first_node_in_group("player")
	
	if not player_ref:
		push_warning("[DashUI] 未找到玩家引用")

## 重写：获取Dash的CD剩余时间
func _get_remaining_cd() -> float:
	if not player_ref:
		return 0.0
	
	if not player_ref.dash_cooldown_timer:
		return 0.0
	
	var timer = player_ref.dash_cooldown_timer
	if timer.is_stopped():
		return 0.0
	
	return timer.time_left

