extends Control
class_name SkillIcon

## 技能图标UI组件
## 显示技能图标、名称和CD进度

@onready var skill_button: Button = $SkillButton
@onready var skill_icon_texture: TextureRect = $SkillButton/SkillIcon
@onready var skill_name_label: Label = $SkillButton/SkillNameLabel
@onready var cd_overlay: ColorRect = $SkillButton/CDOverlay
@onready var cd_progress: ProgressBar = $SkillButton/CDProgress

var skill_data: ClassData = null
var player_ref: Node2D = null
var skill_icon_index: int = 1  # 默认使用1.png

## 技能图标映射（技能名称 -> icon编号）
const skill_icon_map = {
	"狂暴": 1,
	"精准射击": 2,
	"魔法爆发": 3,
	"全面强化": 4,
	"护盾": 5,
}

func _ready() -> void:
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 连接按钮信号
	if skill_button:
		skill_button.pressed.connect(_on_skill_button_pressed)
	
	# 初始化显示
	_update_skill_display()

## 设置技能数据
func set_skill_data(class_data: ClassData) -> void:
	skill_data = class_data
	if skill_data == null:
		visible = false
		return
	
	visible = true
	
	# 获取技能图标编号
	if skill_data.skill_name != "":
		skill_icon_index = skill_icon_map.get(skill_data.skill_name, 1)
	else:
		visible = false
		return
	
	_update_skill_display()

## 更新技能显示
func _update_skill_display() -> void:
	if skill_data == null or skill_data.skill_name == "":
		return
	
	# 设置技能名称
	if skill_name_label:
		skill_name_label.text = skill_data.skill_name
	
	# 加载技能图标
	var icon_path = "res://assets/skillicon/" + str(skill_icon_index) + ".png"
	var icon_texture = load(icon_path)
	if icon_texture and skill_icon_texture:
		skill_icon_texture.texture = icon_texture
	
	# 初始隐藏CD覆盖层
	if cd_overlay:
		cd_overlay.visible = false
	if cd_progress:
		cd_progress.visible = false

## 技能按钮被按下
func _on_skill_button_pressed() -> void:
	if player_ref and player_ref.has_method("activate_class_skill"):
		player_ref.activate_class_skill()

func _process(delta: float) -> void:
	if not player_ref or not player_ref.class_manager:
		return
	
	if skill_data == null or skill_data.skill_name == "":
		return
	
	var skill_name = skill_data.skill_name
	var class_manager = player_ref.class_manager
	var cooldown = skill_data.skill_params.get("cooldown", 0.0)
	
	# 检查技能是否在CD中
	# 注意：active_skills存储的是技能持续时间，CD时间需要单独跟踪
	
	# 如果技能正在激活中（duration > 0），不显示CD
	if class_manager.active_skills.has(skill_name):
		var duration_value = class_manager.active_skills[skill_name]
		# 确保是数值类型
		if (typeof(duration_value) == TYPE_FLOAT or typeof(duration_value) == TYPE_INT) and float(duration_value) > 0:
			# 技能激活中，不显示CD
			_hide_cd_display()
			return
	
	# 检查是否有CD计时器（存储在active_skills中）
	var cd_key = skill_name + "_cd"
	if class_manager.active_skills.has(cd_key):
		var remaining_cd_value = class_manager.active_skills.get(cd_key, 0.0)
		# 确保是数值类型
		if typeof(remaining_cd_value) == TYPE_FLOAT or typeof(remaining_cd_value) == TYPE_INT:
			var remaining_cd = float(remaining_cd_value)
			if remaining_cd > 0 and cooldown > 0:
				# 显示CD进度
				var cd_progress_value = remaining_cd / cooldown
				_update_cd_display(cd_progress_value)
			else:
				# CD结束，清除CD键
				if class_manager.active_skills.has(cd_key):
					class_manager.active_skills.erase(cd_key)
				_hide_cd_display()
		else:
			_hide_cd_display()
	else:
		# 没有CD
		_hide_cd_display()

## 更新CD显示
func _update_cd_display(progress: float) -> void:
	# progress: 0.0 = CD刚开始, 1.0 = CD结束
	# 使用ColorRect从上到下遮罩显示CD进度
	if cd_overlay:
		cd_overlay.visible = true
		# 设置遮罩的锚点和偏移，从下往上填充
		cd_overlay.anchor_top = progress
		cd_overlay.anchor_bottom = 1.0
		cd_overlay.offset_top = 0
		cd_overlay.offset_bottom = 0
	
	if cd_progress:
		cd_progress.visible = true
		cd_progress.value = (1.0 - progress) * 100.0  # 反转显示

## 隐藏CD显示
func _hide_cd_display() -> void:
	if cd_overlay:
		cd_overlay.visible = false
	if cd_progress:
		cd_progress.visible = false
