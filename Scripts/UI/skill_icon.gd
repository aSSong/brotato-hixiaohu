extends BaseSkillUI

## 职业技能图标UI组件
## 显示技能图标、名称和CD倒计时

var skill_data: ClassData = null
var player_ref: CharacterBody2D = null

## 技能图标映射（技能名称 -> icon编号）
const skill_icon_map = {
	"狂暴": 1,
	"精准射击": 2,
	"魔法爆发": 3,
	"全面强化": 4,
	"护盾": 5,
}

func _ready() -> void:
	super._ready()  # 调用基类初始化
	
	# 等待场景加载完成
	await get_tree().create_timer(0.2).timeout
	
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	if not player_ref:
		push_warning("[SkillIcon] 未找到玩家引用")

## 设置技能数据
func set_skill_data(class_data: ClassData) -> void:
	skill_data = class_data
	
	if not skill_data or skill_data.skill_name.is_empty():
		visible = false
		return
	
	visible = true
	
	# 设置技能名称
	if name_label:
		name_label.text = skill_data.skill_name
	
	# 加载技能图标
	var icon_index = skill_icon_map.get(skill_data.skill_name, 1)
	var icon_path = "res://assets/skillicon/%d.png" % icon_index
	var texture = load(icon_path)
	if texture and icon:
		icon.texture = texture

## 重写：获取技能CD剩余时间
func _get_remaining_cd() -> float:
	if not player_ref or not player_ref.class_manager or not skill_data:
		return 0.0
	
	var class_manager = player_ref.class_manager
	
	# ⭐ 新系统：直接用技能名称作为键（不加 "_cd" 后缀）
	return class_manager.get_skill_cooldown(skill_data.skill_name)

## 处理点击激活技能（可选功能）
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if player_ref and player_ref.has_method("activate_class_skill"):
				player_ref.activate_class_skill()
