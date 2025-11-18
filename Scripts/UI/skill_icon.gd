extends BaseSkillUI

## 职业技能图标UI组件
## 显示技能图标、名称和CD倒计时

@onready var skill_des_label: Label = $Skill_des

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
	
	# 设置技能描述
	if skill_des_label:
		skill_des_label.text = _generate_skill_description()

## 重写：获取技能CD剩余时间
func _get_remaining_cd() -> float:
	if not player_ref or not player_ref.class_manager or not skill_data:
		return 0.0
	
	var class_manager = player_ref.class_manager
	
	# ⭐ 新系统：直接用技能名称作为键（不加 "_cd" 后缀）
	return class_manager.get_skill_cooldown(skill_data.skill_name)

## 生成技能描述文本
func _generate_skill_description() -> String:
	if not skill_data:
		return ""
	
	var lines = []
	var params = skill_data.skill_params
	
	# 持续时间
	var duration = params.get("duration", 0.0)
	if duration > 0:
		lines.append("持续时间：%.1f秒" % duration)
	
	# 冷却时间
	var cooldown = params.get("cooldown", 0.0)
	if cooldown > 0:
		lines.append("冷却：%.1f秒" % cooldown)
	
	# 技能效果（根据技能名称生成）
	var effects = _get_skill_effects_description()
	if not effects.is_empty():
		lines.append("技能效果：")
		for effect in effects:
			lines.append("  " + effect)
	
	return "\n".join(lines)

## 获取技能效果描述
func _get_skill_effects_description() -> Array:
	if not skill_data:
		return []
	
	var effects = []
	var params = skill_data.skill_params
	var skill_name = skill_data.skill_name
	
	match skill_name:
		"狂暴":
			var atk_speed = params.get("attack_speed_boost", 0.0)
			var damage = params.get("damage_boost", 1.0)
			if atk_speed > 0:
				effects.append("攻击速度+%d%%" % int(atk_speed * 100))
			if damage > 1.0:
				effects.append("伤害+%d%%" % int((damage - 1.0) * 100))
		
		"精准射击":
			var crit = params.get("crit_chance_boost", 0.0)
			var all_crit = params.get("all_projectiles_crit", false)
			if crit > 0:
				effects.append("暴击率+%d%%" % int(crit * 100))
			if all_crit:
				effects.append("所有子弹必定暴击")
		
		"魔法爆发":
			var radius = params.get("explosion_radius_multiplier", 1.0)
			var damage = params.get("damage_multiplier", 1.0)
			if radius > 1.0:
				effects.append("爆炸范围+%d%%" % int((radius - 1.0) * 100))
			if damage > 1.0:
				effects.append("伤害+%d%%" % int((damage - 1.0) * 100))
		
		"全面强化":
			var boost = params.get("all_stats_boost", 1.0)
			if boost > 1.0:
				effects.append("所有属性+%d%%" % int((boost - 1.0) * 100))
		
		"护盾":
			var shield = params.get("shield_amount", 0)
			var duration = params.get("shield_duration", 0.0)
			if shield > 0:
				effects.append("获得%d点护盾" % shield)
			if duration > 0:
				effects.append("持续%.1f秒" % duration)
	
	# 如果有 skill_description，也可以添加
	if skill_data.skill_description and not skill_data.skill_description.is_empty():
		effects.append(skill_data.skill_description)
	
	return effects

## 处理点击激活技能（可选功能）
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if player_ref and player_ref.has_method("activate_class_skill"):
				player_ref.activate_class_skill()
