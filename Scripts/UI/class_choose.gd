extends Control
class_name ClassChooseUI

## 职业选择界面
## 让用户选择职业，然后进入武器选择界面

# ========== UI 节点引用 ==========
@onready var player_name_edit: LineEdit = $TitleSection/PlayerNameContainer/PlayerNameEdit
@onready var class_name_cn: Label = $MainContent/LeftSection/ClassNameCN
@onready var class_name_en: Label = $MainContent/LeftSection/ClassNameEN
@onready var character_sprite: TextureRect = $MainContent/CenterSection/CharacterDisplay/CharacterSprite
@onready var left_arrow: Button = $MainContent/CenterSection/CharacterDisplay/LeftArrow
@onready var right_arrow: Button = $MainContent/CenterSection/CharacterDisplay/RightArrow

# 右侧信息面板
@onready var info_text: RichTextLabel = $MainContent/RightSection/InfoContainer/InfoSection/InfoText
@onready var hp_value: Label = $MainContent/RightSection/InfoContainer/HPSection/HPValue
@onready var hp_bar: ProgressBar = $MainContent/RightSection/InfoContainer/HPSection/HPBar
@onready var speed_value: Label = $MainContent/RightSection/InfoContainer/SpeedSection/SpeedValue
@onready var speed_bar: ProgressBar = $MainContent/RightSection/InfoContainer/SpeedSection/SpeedBar
@onready var defence_value: Label = $MainContent/RightSection/InfoContainer/DefenceSection/DefenceValue
@onready var defence_bar: ProgressBar = $MainContent/RightSection/InfoContainer/DefenceSection/DefenceBar
@onready var talent_text: RichTextLabel = $MainContent/RightSection/InfoContainer/TalentSection/TalentText
@onready var skill_icon: TextureRect = $MainContent/RightSection/InfoContainer/SkillSection/SkillIcon
@onready var skill_name: Label = $MainContent/RightSection/InfoContainer/SkillSection/SkillInfo/SkillName
@onready var skill_desc: RichTextLabel = $MainContent/RightSection/InfoContainer/SkillSection/SkillInfo/SkillDesc

# 底部按钮
@onready var back_button: Button = $BottomSection/BackButton
@onready var class_portraits: HBoxContainer = $BottomSection/ClassPortraits
@onready var next_button: Button = $BottomSection/NextButton

# ========== 状态变量 ==========
var class_ids: Array = []
var current_class_index: int = 0
var selected_class_id: String = ""
var portrait_buttons: Dictionary = {}

# ========== 常量 ==========
const WEAPON_CHOOSE_SCENE = "res://scenes/UI/Weapon_choose.tscn"

func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	
	# 初始化职业列表
	_initialize_classes()
	
	# 连接按钮信号
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	
	# 选择第一个职业
	if class_ids.size() > 0:
		_select_class(0)
	
	# 初始化下一页按钮状态
	_update_next_button()

## 初始化职业列表
func _initialize_classes() -> void:
	class_ids = ClassDatabase.get_all_class_ids()
	
	# 创建底部职业头像按钮
	for i in range(class_ids.size()):
		var class_id = class_ids[i]
		var class_data = ClassDatabase.get_class_data(class_id)
		
		# 创建头像容器
		var portrait_container = Panel.new()
		portrait_container.custom_minimum_size = Vector2(80, 80)
		
		# 创建头像图片（使用 TextureRect）
		var portrait = TextureRect.new()
		portrait.name = "Portrait"
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# TODO: 这里需要填充头像纹理
		# 如果有 skin_frames，尝试获取第一帧作为头像
		if class_data.skin_frames and class_data.skin_frames.get_animation_names().size() > 0:
			var anim_name = class_data.skin_frames.get_animation_names()[0]
			if class_data.skin_frames.get_frame_count(anim_name) > 0:
				portrait.texture = class_data.skin_frames.get_frame_texture(anim_name, 0)
		
		portrait_container.add_child(portrait)
		
		# 设置面板可点击
		portrait_container.gui_input.connect(_on_portrait_clicked.bind(i))
		portrait_container.mouse_filter = Control.MOUSE_FILTER_STOP
		
		class_portraits.add_child(portrait_container)
		portrait_buttons[class_id] = portrait_container

## 选择指定索引的职业
func _select_class(index: int) -> void:
	if index < 0 or index >= class_ids.size():
		return
	
	current_class_index = index
	selected_class_id = class_ids[index]
	
	var class_data = ClassDatabase.get_class_data(selected_class_id)
	if class_data == null:
		return
	
	# 更新职业名称显示
	var name_parts = class_data.name.split(" ", false, 1)
	if name_parts.size() >= 2:
		class_name_cn.text = name_parts[0]
		class_name_en.text = name_parts[1]
	else:
		class_name_cn.text = class_data.name
		class_name_en.text = ""
	
	# 更新角色展示图片
	# TODO: 这里需要填充角色大图纹理
	if class_data.skin_frames and class_data.skin_frames.get_animation_names().size() > 0:
		var anim_name = class_data.skin_frames.get_animation_names()[0]
		if class_data.skin_frames.get_frame_count(anim_name) > 0:
			character_sprite.texture = class_data.skin_frames.get_frame_texture(anim_name, 0)
	
	# 更新信息面板
	_update_info_panel(class_data)
	
	# 更新头像选中状态
	_update_portrait_selection()
	
	# 更新下一页按钮
	_update_next_button()

## 更新信息面板
func _update_info_panel(class_data: ClassData) -> void:
	# Info 描述
	info_text.text = class_data.description
	
	# HP
	hp_value.text = str(class_data.max_hp)
	hp_bar.value = class_data.max_hp
	
	# Speed
	speed_value.text = str(int(class_data.speed))
	speed_bar.value = class_data.speed
	
	# Defence
	defence_value.text = str(class_data.defense)
	defence_bar.value = class_data.defense
	
	# Talent 天赋（使用 traits）
	var talent_str = ""
	for trait_value in class_data.traits:
		if talent_str != "":
			talent_str += "\n"
		talent_str += str(trait_value)
	talent_text.text = talent_str if talent_str != "" else "无特殊天赋"
	
	# Skill 技能
	if class_data.skill_data:
		skill_name.text = class_data.skill_data.name
		skill_desc.text = class_data.skill_data.description
		# TODO: 填充技能图标
		if class_data.skill_data.icon:
			skill_icon.texture = class_data.skill_data.icon
	else:
		skill_name.text = "无技能"
		skill_desc.text = ""

## 更新头像选中状态
func _update_portrait_selection() -> void:
	for class_id in portrait_buttons.keys():
		var panel = portrait_buttons[class_id] as Panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.3, 1)
		
		if class_id == selected_class_id:
			# 选中状态：粉色边框 + 勾选标记
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(1, 0.3, 0.5, 1)
		else:
			# 未选中：无边框
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0
		
		panel.add_theme_stylebox_override("panel", style)

## 更新下一页按钮状态
func _update_next_button() -> void:
	var can_proceed = selected_class_id != ""
	next_button.disabled = not can_proceed
	
	var style = StyleBoxFlat.new()
	if can_proceed:
		# 可点击：渐变橙红色
		style.bg_color = Color(1, 0.4, 0.3, 1)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(1, 0.6, 0.4, 1)
		next_button.modulate = Color(1, 1, 1, 1)
	else:
		# 不可点击：灰色
		style.bg_color = Color(0.3, 0.3, 0.3, 1)
		next_button.modulate = Color(0.6, 0.6, 0.6, 1)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	next_button.add_theme_stylebox_override("normal", style)
	next_button.add_theme_stylebox_override("hover", style)
	next_button.add_theme_stylebox_override("pressed", style)
	next_button.add_theme_stylebox_override("disabled", style)

# ========== 信号回调 ==========

func _on_left_arrow_pressed() -> void:
	var new_index = current_class_index - 1
	if new_index < 0:
		new_index = class_ids.size() - 1
	_select_class(new_index)

func _on_right_arrow_pressed() -> void:
	var new_index = current_class_index + 1
	if new_index >= class_ids.size():
		new_index = 0
	_select_class(new_index)

func _on_portrait_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_class(index)

func _on_back_button_pressed() -> void:
	# 返回主菜单或上一个界面
	# TODO: 根据实际需求调整返回目标
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")

func _on_next_button_pressed() -> void:
	if selected_class_id == "":
		return
	
	# 保存选择的职业
	GameMain.selected_class_id = selected_class_id
	
	# 保存玩家名字（如果有输入）
	var player_name = player_name_edit.text.strip_edges()
	if player_name != "":
		# TODO: 保存玩家名字到 GameMain 或其他位置
		pass
	
	# 跳转到武器选择界面
	get_tree().change_scene_to_file(WEAPON_CHOOSE_SCENE)
