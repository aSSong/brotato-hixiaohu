extends BaseSkillUI

## 职业技能图标UI组件
## 显示技能图标、名称和CD倒计时

@onready var skill_des_label: Label = $Skill_des

var skill_data: ClassData = null
var player_ref: CharacterBody2D = null

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
	
	if not class_data or not class_data.skill_data:
		visible = false
		return
	
	var actual_skill_data: SkillData = class_data.skill_data
	visible = true
	
	# 设置技能名称
	if name_label:
		name_label.text = actual_skill_data.name
	
	# 加载技能图标（从 SkillData 资源中读取）
	if icon and actual_skill_data.icon:
		icon.texture = actual_skill_data.icon
	
	# 设置技能描述
	if skill_des_label:
		skill_des_label.text = _generate_skill_description(actual_skill_data)

## 重写：获取技能CD剩余时间
func _get_remaining_cd() -> float:
	if not player_ref or not player_ref.class_manager or not skill_data or not skill_data.skill_data:
		return 0.0
	
	var class_manager = player_ref.class_manager
	return class_manager.get_skill_cooldown(skill_data.skill_data.name)

## 获取技能剩余持续时间
func _get_remaining_duration() -> float:
	if not player_ref or not player_ref.class_manager or not skill_data or not skill_data.skill_data:
		return 0.0
	
	var class_manager = player_ref.class_manager
	var skill_name = skill_data.skill_data.name
	return class_manager.get_skill_remaining_duration(skill_name)

## 重写：更新CD显示（自定义显示逻辑）
func _update_cd_display():
	if not skill_data or not skill_data.skill_data:
		# 隐藏CD相关元素
		if cd_mask:
			cd_mask.visible = false
		if cd_text:
			cd_text.visible = false
		return
	
	var class_manager = player_ref.class_manager if player_ref else null
	if not class_manager:
		return
	
	var skill_name = skill_data.skill_data.name
	
	# 检查技能是否激活
	var is_active = class_manager.is_skill_active(skill_name)
	var remaining_duration = _get_remaining_duration()
	var remaining_cooldown = _get_remaining_cd()
	
	if is_active and remaining_duration > 0:
		# 技能激活中：显示黄色文本倒计时（duration），cdmask 不可见
		if cd_mask:
			cd_mask.visible = false
		if cd_text:
			cd_text.visible = true
			cd_text.text = str(ceili(remaining_duration))
			# 设置黄色文本
			cd_text.modulate = Color.YELLOW
	elif remaining_cooldown > 0:
		# 技能持续时间结束后：cdmask 可见，显示白色倒计时（cooldown）
		if cd_mask:
			cd_mask.visible = true
		if cd_text:
			cd_text.visible = true
			cd_text.text = str(ceili(remaining_cooldown))
			# 设置白色文本
			cd_text.modulate = Color.WHITE
	else:
		# 技能可用：隐藏CD相关元素
		if cd_mask:
			cd_mask.visible = false
		if cd_text:
			cd_text.visible = false

## 生成技能描述文本
func _generate_skill_description(skill_data_resource: SkillData) -> String:
	if not skill_data_resource:
		return ""
	
	var lines = []
	
	# 持续时间
	if skill_data_resource.duration > 0:
		lines.append("持续时间：%.1f秒" % skill_data_resource.duration)
	
	# 冷却时间
	if skill_data_resource.cooldown > 0:
		lines.append("冷却：%.1f秒" % skill_data_resource.cooldown)
	
	# 技能描述
	if skill_data_resource.description and not skill_data_resource.description.is_empty():
		lines.append(skill_data_resource.description)
	
	return "\n".join(lines)

## 处理点击激活技能（可选功能）
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if player_ref and player_ref.has_method("activate_class_skill"):
				player_ref.activate_class_skill()
