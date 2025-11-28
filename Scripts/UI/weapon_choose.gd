extends Control
class_name WeaponChooseUI

## 武器选择界面
## 让用户选择2把武器，然后开始游戏

# ========== UI 节点引用 ==========
@onready var player_portrait: TextureRect = $TitleSection/PlayerInfo/PlayerPortrait
@onready var player_name_label: Label = $TitleSection/PlayerInfo/PlayerName
@onready var weapon_grid: GridContainer = $MainContent/WeaponGridSection/WeaponGrid

# 武器1详情
@onready var weapon1_name: Label = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Header/Weapon1Name
@onready var weapon1_icon: TextureRect = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Icon
@onready var weapon1_damage_value: Label = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/DamageSection/DamageValue
@onready var weapon1_damage_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/DamageSection/DamageBar
@onready var weapon1_speed_value: Label = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/SpeedSection/SpeedValue
@onready var weapon1_speed_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/SpeedSection/SpeedBar
@onready var weapon1_range_value: Label = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/RangeSection/RangeValue
@onready var weapon1_range_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/RangeSection/RangeBar
@onready var weapon1_effect_text: Label = $MainContent/WeaponDetailSection/Weapon1Panel/Weapon1Container/Weapon1Content/Weapon1Stats/EffectSection/EffectText

# 武器2详情
@onready var weapon2_name: Label = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Header/Weapon2Name
@onready var weapon2_placeholder: Panel = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Placeholder
@onready var weapon2_content: HBoxContainer = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content
@onready var weapon2_icon: TextureRect = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Icon
@onready var weapon2_damage_value: Label = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/DamageSection/DamageValue
@onready var weapon2_damage_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/DamageSection/DamageBar
@onready var weapon2_speed_value: Label = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/SpeedSection/SpeedValue
@onready var weapon2_speed_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/SpeedSection/SpeedBar
@onready var weapon2_range_value: Label = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/RangeSection/RangeValue
@onready var weapon2_range_bar: ProgressBar = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/RangeSection/RangeBar
@onready var weapon2_effect_text: Label = $MainContent/WeaponDetailSection/Weapon2Panel/Weapon2Container/Weapon2Content/Weapon2Stats/EffectSection/EffectText

# 底部按钮
@onready var back_button: Button = $BottomSection/BackButton
@onready var start_button: Button = $BottomSection/StartButton

# ========== 状态变量 ==========
var weapon_ids: Array = []
var selected_weapon_ids: Array = []
var weapon_cards: Dictionary = {}

const MAX_WEAPONS = 2
const CLASS_CHOOSE_SCENE = "res://scenes/UI/Class_choose.tscn"

## 预定义的武器列表（与 start_menu 保持一致）
var available_weapons: Array = [
	"pistol", "rifle", "machine_gun",  # 远程
	"sword", "axe", "dagger",  # 近战
	"fireball", "ice_shard", "meteor"  # 魔法
]

func _ready() -> void:
	# 初始化玩家信息显示
	_initialize_player_info()
	
	# 初始化武器网格
	_initialize_weapon_grid()
	
	# 连接按钮信号
	back_button.pressed.connect(_on_back_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	
	# 初始化开战按钮状态
	_update_start_button()
	
	# 初始化武器详情面板
	_update_weapon_details()

## 初始化玩家信息显示
func _initialize_player_info() -> void:
	# 显示已选择的职业头像
	var class_id = GameMain.selected_class_id
	if class_id != "":
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.skin_frames:
			var anim_names = class_data.skin_frames.get_animation_names()
			if anim_names.size() > 0:
				var anim_name = anim_names[0]
				if class_data.skin_frames.get_frame_count(anim_name) > 0:
					player_portrait.texture = class_data.skin_frames.get_frame_texture(anim_name, 0)
	
	# TODO: 显示玩家名字（如果有保存）
	player_name_label.text = "玩家名字"

## 初始化武器网格
func _initialize_weapon_grid() -> void:
	weapon_ids = available_weapons.duplicate()
	
	for weapon_id in weapon_ids:
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		if weapon_data == null:
			continue
		
		# 创建武器卡片
		var card = _create_weapon_card(weapon_id, weapon_data)
		weapon_grid.add_child(card)
		weapon_cards[weapon_id] = card

## 创建武器卡片
func _create_weapon_card(weapon_id: String, weapon_data: WeaponData) -> Panel:
	# 主卡片面板
	var card = Panel.new()
	card.custom_minimum_size = Vector2(140, 180)
	
	# 卡片样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.9, 0.95, 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	card.add_theme_stylebox_override("panel", style)
	
	# 创建垂直布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)
	
	# 武器图片区域（紫色背景）
	var image_panel = Panel.new()
	image_panel.custom_minimum_size = Vector2(0, 130)
	image_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var image_style = StyleBoxFlat.new()
	image_style.bg_color = Color(0.35, 0.2, 0.5, 1)
	image_panel.add_theme_stylebox_override("panel", image_style)
	vbox.add_child(image_panel)
	
	# 武器图标
	var icon = TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 加载武器图标
	if weapon_data.texture_path != "":
		var tex = load(weapon_data.texture_path)
		if tex:
			icon.texture = tex
	image_panel.add_child(icon)
	
	# 选中勾选标记（初始隐藏）
	var check_mark = Label.new()
	check_mark.name = "CheckMark"
	check_mark.text = "✓"
	check_mark.add_theme_font_size_override("font_size", 24)
	check_mark.add_theme_color_override("font_color", Color(1, 0.3, 0.5, 1))
	check_mark.position = Vector2(110, 5)
	check_mark.visible = false
	image_panel.add_child(check_mark)
	
	# 武器名称区域（黑色背景）
	var name_panel = Panel.new()
	name_panel.custom_minimum_size = Vector2(0, 50)
	name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(0.1, 0.1, 0.12, 1)
	name_panel.add_theme_stylebox_override("panel", name_style)
	vbox.add_child(name_panel)
	
	# 武器名称标签
	var name_label = Label.new()
	name_label.text = weapon_data.weapon_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_panel.add_child(name_label)
	
	# 让卡片可点击
	card.gui_input.connect(_on_weapon_card_clicked.bind(weapon_id))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return card

## 切换武器选择
func _toggle_weapon(weapon_id: String) -> void:
	if selected_weapon_ids.has(weapon_id):
		# 取消选择
		selected_weapon_ids.erase(weapon_id)
	else:
		# 选择武器（最多2个）
		if selected_weapon_ids.size() < MAX_WEAPONS:
			selected_weapon_ids.append(weapon_id)
		else:
			return  # 已达上限
	
	# 更新卡片选中状态
	_update_card_selection()
	
	# 更新武器详情
	_update_weapon_details()
	
	# 更新开战按钮
	_update_start_button()

## 更新卡片选中状态
func _update_card_selection() -> void:
	for weapon_id in weapon_cards.keys():
		var card = weapon_cards[weapon_id] as Panel
		var is_selected = selected_weapon_ids.has(weapon_id)
		
		# 更新边框
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.95, 1)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		
		if is_selected:
			# 选中：粉色边框
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(1, 0.3, 0.5, 1)
		else:
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0
		
		card.add_theme_stylebox_override("panel", style)
		
		# 更新勾选标记
		var vbox = card.get_child(0) as VBoxContainer
		if vbox:
			var image_panel = vbox.get_child(0) as Panel
			if image_panel:
				var check_mark = image_panel.get_node_or_null("CheckMark")
				if check_mark:
					check_mark.visible = is_selected

## 更新武器详情面板
func _update_weapon_details() -> void:
	# 武器1
	if selected_weapon_ids.size() >= 1:
		var weapon_id = selected_weapon_ids[0]
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		_update_weapon_panel(1, weapon_data)
	else:
		_clear_weapon_panel(1)
	
	# 武器2
	if selected_weapon_ids.size() >= 2:
		var weapon_id = selected_weapon_ids[1]
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		_update_weapon_panel(2, weapon_data)
		weapon2_placeholder.visible = false
		weapon2_content.visible = true
	else:
		_clear_weapon_panel(2)
		weapon2_placeholder.visible = true
		weapon2_content.visible = false

## 更新武器面板
func _update_weapon_panel(slot: int, weapon_data: WeaponData) -> void:
	var name_label: Label
	var icon: TextureRect
	var damage_value: Label
	var damage_bar: ProgressBar
	var speed_value: Label
	var speed_bar: ProgressBar
	var range_value: Label
	var range_bar: ProgressBar
	var effect_text: Label
	
	if slot == 1:
		name_label = weapon1_name
		icon = weapon1_icon
		damage_value = weapon1_damage_value
		damage_bar = weapon1_damage_bar
		speed_value = weapon1_speed_value
		speed_bar = weapon1_speed_bar
		range_value = weapon1_range_value
		range_bar = weapon1_range_bar
		effect_text = weapon1_effect_text
	else:
		name_label = weapon2_name
		icon = weapon2_icon
		damage_value = weapon2_damage_value
		damage_bar = weapon2_damage_bar
		speed_value = weapon2_speed_value
		speed_bar = weapon2_speed_bar
		range_value = weapon2_range_value
		range_bar = weapon2_range_bar
		effect_text = weapon2_effect_text
	
	# 更新数据
	name_label.text = weapon_data.weapon_name
	
	# 加载图标
	if weapon_data.texture_path != "":
		var tex = load(weapon_data.texture_path)
		if tex:
			icon.texture = tex
	
	# 伤害
	damage_value.text = str(weapon_data.damage)
	damage_bar.value = weapon_data.damage
	
	# 攻速（转换为每分钟攻击次数）
	var attacks_per_minute = 60.0 / weapon_data.attack_speed if weapon_data.attack_speed > 0 else 0
	speed_value.text = str(int(attacks_per_minute))
	speed_bar.value = attacks_per_minute
	
	# 范围
	var range_val = weapon_data.range if weapon_data.weapon_type == WeaponData.WeaponType.RANGED else weapon_data.hit_range
	range_value.text = str(int(range_val))
	range_bar.value = range_val
	
	# 特效
	var effect_str = _get_weapon_effect_text(weapon_data)
	effect_text.text = effect_str

## 获取武器特效文字
func _get_weapon_effect_text(weapon_data: WeaponData) -> String:
	if weapon_data.special_effects.is_empty():
		return "无"
	
	var effects = weapon_data.special_effects.get("effects", [])
	var texts = []
	
	for effect in effects:
		var effect_type = effect.get("type", "")
		var params = effect.get("params", {})
		
		match effect_type:
			"lifesteal":
				var chance = params.get("chance", 0) * 100
				var percent = params.get("percent", 0) * 100
				texts.append("%d%%概率吸血%d%%" % [int(chance), int(percent)])
			"bleed":
				var chance = params.get("chance", 0) * 100
				texts.append("%d%%概率流血" % int(chance))
			"burn":
				var chance = params.get("chance", 0) * 100
				texts.append("%d%%概率燃烧" % int(chance))
			"freeze":
				var chance = params.get("chance", 0) * 100
				texts.append("%d%%概率冰冻" % int(chance))
	
	return "\n".join(texts) if texts.size() > 0 else "无"

## 清空武器面板
func _clear_weapon_panel(slot: int) -> void:
	if slot == 1:
		weapon1_name.text = ""
		weapon1_icon.texture = null
		weapon1_damage_value.text = "0"
		weapon1_damage_bar.value = 0
		weapon1_speed_value.text = "0"
		weapon1_speed_bar.value = 0
		weapon1_range_value.text = "0"
		weapon1_range_bar.value = 0
		weapon1_effect_text.text = "无"
	else:
		weapon2_name.text = ""
		weapon2_icon.texture = null
		weapon2_damage_value.text = "0"
		weapon2_damage_bar.value = 0
		weapon2_speed_value.text = "0"
		weapon2_speed_bar.value = 0
		weapon2_range_value.text = "0"
		weapon2_range_bar.value = 0
		weapon2_effect_text.text = "无"

## 更新开战按钮状态
func _update_start_button() -> void:
	var can_start = selected_weapon_ids.size() == MAX_WEAPONS
	start_button.disabled = not can_start
	
	var style = StyleBoxFlat.new()
	if can_start:
		# 可点击：渐变橙红色
		style.bg_color = Color(1, 0.4, 0.3, 1)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(1, 0.6, 0.4, 1)
		start_button.modulate = Color(1, 1, 1, 1)
	else:
		# 不可点击：灰色
		style.bg_color = Color(0.3, 0.3, 0.3, 1)
		start_button.modulate = Color(0.6, 0.6, 0.6, 1)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	start_button.add_theme_stylebox_override("normal", style)
	start_button.add_theme_stylebox_override("hover", style)
	start_button.add_theme_stylebox_override("pressed", style)
	start_button.add_theme_stylebox_override("disabled", style)

# ========== 信号回调 ==========

func _on_weapon_card_clicked(event: InputEvent, weapon_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_weapon(weapon_id)

func _on_back_button_pressed() -> void:
	# 返回职业选择界面
	get_tree().change_scene_to_file(CLASS_CHOOSE_SCENE)

func _on_start_button_pressed() -> void:
	if selected_weapon_ids.size() != MAX_WEAPONS:
		return
	
	# 保存选择的武器
	GameMain.selected_weapon_ids = selected_weapon_ids.duplicate()
	
	# 根据当前mode_id选择目标场景（与 start_menu 保持一致）
	var mode_id = GameMain.current_mode_id
	var target_scene = ""
	
	if mode_id == "multi":
		target_scene = "res://scenes/map/model_2_stage_1.tscn"
		GameMain.current_map_id = "model2_stage1"
		print("[WeaponChoose] 进入Multi模式地图: model2_stage1")
	else:  # survival或空字符串
		target_scene = "res://scenes/map/bg_map.tscn"
		GameMain.current_map_id = "default"
		print("[WeaponChoose] 进入Survival模式地图: bg_map")
	
	# 加载游戏场景
	var game_scene = load(target_scene)
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
	else:
		push_error("[WeaponChoose] 无法加载游戏场景: %s" % target_scene)

