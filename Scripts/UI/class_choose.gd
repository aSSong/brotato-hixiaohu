extends Control
class_name ClassChooseUI

## 职业选择界面
## 让用户选择职业，然后进入武器选择界面

# ========== UI 节点引用 ==========
# 标题区域
@onready var player_portrait: TextureRect = $TitleSection/PlayerNameContainer/QuestionMark/playerportrait
@onready var player_name_label: Label = $TitleSection/PlayerNameContainer/PlayerName

# 左侧职业名称图片
@onready var classname_image: TextureRect = $MainContent/LeftSection/classname_image

# 中间角色展示
@onready var character_sprite: TextureRect = $MainContent/CenterSection/CharacterDisplay/CharacterSprite
@onready var left_arrow: TextureButton = $MainContent/CenterSection/CharacterDisplay/LeftArrow
@onready var right_arrow: TextureButton = $MainContent/CenterSection/CharacterDisplay/RightArrow

# 右侧信息面板
@onready var info_text: RichTextLabel = $MainContent/RightSection/InfoContainer/InfoSection/InfoText
@onready var hp_value: Label = $MainContent/RightSection/InfoContainer/HPSection/HPBar/HPValue
@onready var hp_bar: ProgressBar = $MainContent/RightSection/InfoContainer/HPSection/HPBar
@onready var speed_value: Label = $MainContent/RightSection/InfoContainer/SpeedSection/SpeedBar/SpeedValue
@onready var speed_bar: ProgressBar = $MainContent/RightSection/InfoContainer/SpeedSection/SpeedBar
@onready var defence_value: Label = $MainContent/RightSection/InfoContainer/DefenceSection/DefenceBar/DefenceValue
@onready var defence_bar: ProgressBar = $MainContent/RightSection/InfoContainer/DefenceSection/DefenceBar
@onready var talent_text: RichTextLabel = $MainContent/RightSection/InfoContainer/TalentSection/TalentText
@onready var skill_icon: TextureRect = $MainContent/RightSection/InfoContainer/SkillSection/SkillIcon
@onready var skill_name_label: Label = $MainContent/RightSection/InfoContainer/SkillSection/SkillInfo/SkillName
@onready var skill_desc: RichTextLabel = $MainContent/RightSection/InfoContainer/SkillSection/SkillInfo/SkillDesc

# 底部按钮
@onready var back_button: TextureButton = $BottomSection/BackButton
@onready var next_button: TextureButton = $BottomSection/NextButton

# 底部职业按钮（固定6个）
@onready var btn_betty: TextureRect = $BottomSection/ClassPortraits/"btn-betty"
@onready var btn_babayaga: TextureRect = $BottomSection/ClassPortraits/"btn-babayaga"
@onready var btn_mrwill: TextureRect = $BottomSection/ClassPortraits/"btn-mrwill"
@onready var btn_arm: TextureRect = $BottomSection/ClassPortraits/"btn-arm"
@onready var btn_mrdot: TextureRect = $BottomSection/ClassPortraits/"btn-mrdot"
@onready var btn_ky: TextureRect = $BottomSection/ClassPortraits/"btn-ky"

# ========== 资源引用 ==========
var tex_portrait_choose: Texture2D = preload("res://assets/UI/class_choose/bg-portrait-choose-01.png")
var tex_portrait_unchoose: Texture2D = preload("res://assets/UI/class_choose/bg-portrait-unchoose-01.png")

# ========== 状态变量 ==========
# 按钮到职业ID的映射
var button_to_class: Dictionary = {}
# 职业ID到按钮的映射
var class_to_button: Dictionary = {}
# 职业ID有序列表（用于箭头切换）
var class_ids: Array = []
var current_class_index: int = 0
var selected_class_id: String = ""

# ========== 常量 ==========
const WEAPON_CHOOSE_SCENE = "res://scenes/UI/Weapon_choose.tscn"

func _ready() -> void:
	# 播放标题BGM
	BGMManager.play_bgm("title")
	
	# 显示玩家名字（从存档读取）
	_initialize_player_name()
	
	# 初始化按钮映射
	_initialize_button_mapping()
	
	# 连接按钮信号
	_connect_signals()
	
	# 随机选择一个职业
	_select_random_class()

## 初始化玩家名字显示
func _initialize_player_name() -> void:
	var saved_name = SaveManager.get_player_name()
	if saved_name != "":
		player_name_label.text = saved_name
	else:
		player_name_label.text = "Key Person"

## 初始化按钮与职业ID的映射
func _initialize_button_mapping() -> void:
	# 按钮 -> 职业ID 映射
	button_to_class = {
		btn_betty: "betty",
		btn_babayaga: "warrior",
		btn_mrwill: "ranger",
		btn_arm: "mage",
		btn_mrdot: "balanced",
		btn_ky: "tank"
	}
	
	# 职业ID -> 按钮 映射
	for btn in button_to_class.keys():
		var class_id = button_to_class[btn]
		class_to_button[class_id] = btn
	
	# 有序职业ID列表（用于箭头切换）
	class_ids = ["betty", "warrior", "ranger", "mage", "balanced", "tank"]
	
	# 为每个按钮设置头像纹理
	for btn in button_to_class.keys():
		var class_id = button_to_class[btn]
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.portrait:
			var portrait_node = btn.get_node_or_null("portrait")
			if portrait_node:
				portrait_node.texture = class_data.portrait

## 连接所有信号
func _connect_signals() -> void:
	# 箭头按钮
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	
	# 底部按钮
	back_button.pressed.connect(_on_back_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	
	# 职业选择按钮（使用gui_input实现点击）
	for btn in button_to_class.keys():
		btn.gui_input.connect(_on_class_button_input.bind(btn))
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

## 随机选择一个职业
func _select_random_class() -> void:
	var random_index = randi() % class_ids.size()
	_select_class_by_index(random_index)

## 通过索引选择职业
func _select_class_by_index(index: int) -> void:
	if index < 0 or index >= class_ids.size():
		return
	
	current_class_index = index
	selected_class_id = class_ids[index]
	
	_update_class_display()

## 通过职业ID选择职业
func _select_class_by_id(class_id: String) -> void:
	var index = class_ids.find(class_id)
	if index >= 0:
		_select_class_by_index(index)

## 更新职业显示
func _update_class_display() -> void:
	var class_data = ClassDatabase.get_class_data(selected_class_id)
	if class_data == null:
		return
	
	# 更新海报（中间角色图）
	if class_data.poster:
		character_sprite.texture = class_data.poster
	
	# 更新职业名称图片
	if class_data.name_image:
		classname_image.texture = class_data.name_image
	
	# 更新左上角头像
	if class_data.portrait:
		player_portrait.texture = class_data.portrait
	
	# 更新信息面板
	_update_info_panel(class_data)
	
	# 更新底部按钮选中状态
	_update_portrait_buttons()

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
		skill_name_label.text = class_data.skill_data.name
		skill_desc.text = class_data.skill_data.description
		if class_data.skill_data.icon:
			skill_icon.texture = class_data.skill_data.icon
	else:
		skill_name_label.text = "无技能"
		skill_desc.text = ""

## 更新底部职业按钮选中状态
func _update_portrait_buttons() -> void:
	for btn in button_to_class.keys():
		var class_id = button_to_class[btn]
		var is_selected = (class_id == selected_class_id)
		
		# 更新背景图片
		if is_selected:
			btn.texture = tex_portrait_choose
		else:
			btn.texture = tex_portrait_unchoose
		
		# 更新头像缩放
		var portrait_node = btn.get_node_or_null("portrait")
		if portrait_node:
			if is_selected:
				portrait_node.scale = Vector2(1.0, 1.0)
			else:
				portrait_node.scale = Vector2(0.8, 0.8)
		
		# 更新选中标记可见性
		var choose_node = btn.get_node_or_null("choose")
		if choose_node:
			choose_node.visible = is_selected

# ========== 信号回调 ==========

func _on_left_arrow_pressed() -> void:
	var new_index = current_class_index - 1
	if new_index < 0:
		new_index = class_ids.size() - 1  # 循环到最后
	_select_class_by_index(new_index)

func _on_right_arrow_pressed() -> void:
	var new_index = current_class_index + 1
	if new_index >= class_ids.size():
		new_index = 0  # 循环到第一个
	_select_class_by_index(new_index)

func _on_class_button_input(event: InputEvent, btn: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var class_id = button_to_class.get(btn, "")
		if class_id != "":
			_select_class_by_id(class_id)

func _on_back_button_pressed() -> void:
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")

func _on_next_button_pressed() -> void:
	if selected_class_id == "":
		return
	
	# 保存选择的职业
	GameMain.selected_class_id = selected_class_id
	
	# 保存玩家名字（如果有输入）
	var player_name = player_name_label.text.strip_edges()
	if player_name != "" and player_name != "Key Person":
		# 可以保存到 GameMain 或其他位置
		pass
	
	# 跳转到武器选择界面
	get_tree().change_scene_to_file(WEAPON_CHOOSE_SCENE)
