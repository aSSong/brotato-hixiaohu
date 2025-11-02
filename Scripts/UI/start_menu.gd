extends Control
class_name StartMenu

## 开始菜单
## 让用户选择职业和武器

@onready var class_container: VBoxContainer = $MainPanel/VBoxContainer/ContentContainer/ClassSection/ClassList
@onready var class_description: RichTextLabel = $MainPanel/VBoxContainer/ContentContainer/ClassDescSection/ClassDescription
@onready var weapon_container: GridContainer = $MainPanel/VBoxContainer/ContentContainer/WeaponSection/WeaponList
@onready var weapon_description: RichTextLabel = $MainPanel/VBoxContainer/ContentContainer/WeaponDescSection/WeaponDescription
@onready var start_button: Button = $MainPanel/VBoxContainer/BottomSection/StartButton

var selected_class_id: String = ""
var selected_weapon_ids: Array = []
var class_buttons: Dictionary = {}
var weapon_buttons: Dictionary = {}

const MAX_WEAPONS = 2

## 预定义的武器列表（用于选择）
var available_weapons: Array = [
	"pistol", "rifle", "machine_gun",  # 远程
	"sword", "axe", "dagger",  # 近战
	"fireball", "ice_shard", "meteor"  # 魔法
]

func _ready() -> void:
	# 初始化界面
	_populate_classes()
	_populate_weapons()
	
	# 初始状态：按钮灰色不可点击
	_update_start_button()
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)

## 填充职业列表
func _populate_classes() -> void:
	var class_ids = ClassDatabase.get_all_class_ids()
	
	for class_id in class_ids:
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data == null:
			continue
		
		# 创建职业面板（矩形+文字）
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(150, 60)
		
		# 创建样式 - 默认无边框
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.2, 0.25, 1)
		style_normal.border_width_left = 0
		style_normal.border_width_right = 0
		style_normal.border_width_top = 0
		style_normal.border_width_bottom = 0
		
		panel.add_theme_stylebox_override("panel", style_normal)
		
		# 创建标签显示职业名称
		var label = Label.new()
		label.text = class_data.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchor_left = 0
		label.anchor_right = 1
		label.anchor_top = 0
		label.anchor_bottom = 1
		
		panel.add_child(label)
		
		# 让面板可点击
		panel.gui_input.connect(_on_class_panel_clicked.bind(class_id))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		
		class_container.add_child(panel)
		class_buttons[class_id] = panel

## 填充武器列表
func _populate_weapons() -> void:
	for weapon_id in available_weapons:
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		if weapon_data == null:
			continue
		
		# 创建武器面板容器
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(120, 120)  # 增大尺寸
		
		# 创建样式 - 默认无边框
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.15, 0.15, 0.2, 1)
		style_normal.border_width_left = 0
		style_normal.border_width_right = 0
		style_normal.border_width_top = 0
		style_normal.border_width_bottom = 0
		
		panel.add_theme_stylebox_override("panel", style_normal)
		
		# 创建武器图标
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(weapon_data.texture_path)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(100, 100)
		texture_rect.anchor_left = 0
		texture_rect.anchor_right = 1
		texture_rect.anchor_top = 0
		texture_rect.anchor_bottom = 1
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		panel.add_child(texture_rect)
		
		# 让面板可点击
		panel.gui_input.connect(_on_weapon_panel_clicked.bind(weapon_id))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		
		weapon_container.add_child(panel)
		weapon_buttons[weapon_id] = panel

## 职业面板被点击
func _on_class_panel_clicked(event: InputEvent, class_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_class(class_id)

## 武器面板被点击
func _on_weapon_panel_clicked(event: InputEvent, weapon_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_weapon(weapon_id)

## 选择职业
func _select_class(class_id: String) -> void:
	selected_class_id = class_id
	var class_data = ClassDatabase.get_class_data(class_id)
	
	if class_data == null:
		return
	
	# 更新所有职业面板的边框
	for cid in class_buttons.keys():
		var panel = class_buttons[cid]
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.25, 1)
		
		if cid == class_id:
			# 选中：绿色粗边框
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(0.2, 0.8, 0.2, 1)
		else:
			# 未选中：无边框
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0
		
		panel.add_theme_stylebox_override("panel", style)
	
	# 更新职业说明显示
	_update_class_description()
	
	# 更新开始按钮状态
	_update_start_button()

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
			return  # 已达上限，不做处理
	
	# 更新所有武器面板的边框
	for wid in weapon_buttons.keys():
		var panel = weapon_buttons[wid]
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 1)
		
		if selected_weapon_ids.has(wid):
			# 选中：绿色粗边框
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(0.2, 0.8, 0.2, 1)
		else:
			# 未选中：无边框
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0
		
		panel.add_theme_stylebox_override("panel", style)
	
	# 更新武器说明显示
	_update_weapon_description()
	
	# 更新开始按钮状态
	_update_start_button()

## 更新职业说明显示
func _update_class_description() -> void:
	var text = ""
	
	# 显示职业信息
	if selected_class_id != "":
		var class_data = ClassDatabase.get_class_data(selected_class_id)
		if class_data:
			text += "[b][color=#4CAF50]" + class_data.name + "[/color][/b]\n\n"
			text += class_data.description + "\n\n"
			text += "[b]基础属性:[/b]\n"
			text += "• 血量: " + str(class_data.max_hp) + "\n"
			text += "• 速度: " + str(int(class_data.speed)) + "\n"
			text += "• 攻击倍数: " + str(class_data.attack_multiplier) + "x\n"
			text += "• 防御: " + str(class_data.defense) + "\n"
			text += "• 暴击率: " + str(int(class_data.crit_chance * 100)) + "%\n\n"
			
			if class_data.traits.size() > 0:
				text += "[b]特性:[/b]\n"
				for trait_value in class_data.traits:
					text += "• " + str(trait_value) + "\n"
	else:
		text = "[center][color=#888888]请选择一个职业[/color][/center]"
	
	class_description.text = text

## 更新武器说明显示
func _update_weapon_description() -> void:
	var text = ""
	
	# 显示武器信息
	if selected_weapon_ids.size() > 0:
		text += "[b][color=#4CAF50]已选武器 (" + str(selected_weapon_ids.size()) + "/" + str(MAX_WEAPONS) + "):[/color][/b]\n\n"
		
		for weapon_id in selected_weapon_ids:
			var weapon_data = WeaponDatabase.get_weapon(weapon_id)
			if weapon_data:
				text += "[b]" + weapon_data.weapon_name + "[/b]\n"
				text += weapon_data.description + "\n"
				
				var type_text = ""
				match weapon_data.weapon_type:
					WeaponData.WeaponType.RANGED:
						type_text = "远程"
					WeaponData.WeaponType.MELEE:
						type_text = "近战"
					WeaponData.WeaponType.MAGIC:
						type_text = "魔法"
				
				text += "类型: " + type_text + " | "
				text += "伤害: " + str(weapon_data.damage) + " | "
				text += "攻速: " + str(weapon_data.attack_speed) + "s\n\n"
	else:
		text = "[center][color=#888888]请选择2把武器[/color][/center]"
	
	weapon_description.text = text

## 更新开始按钮状态
func _update_start_button() -> void:
	var can_start = selected_class_id != "" and selected_weapon_ids.size() == MAX_WEAPONS
	
	start_button.disabled = not can_start
	
	# 创建按钮样式
	var style_box = StyleBoxFlat.new()
	
	if can_start:
		# 绿色可点击 - 明亮的绿色背景 + 白色边框
		style_box.bg_color = Color(0.2, 0.8, 0.2, 1)  # 亮绿色背景
		style_box.border_width_left = 5
		style_box.border_width_right = 5
		style_box.border_width_top = 5
		style_box.border_width_bottom = 5
		style_box.border_color = Color(1, 1, 1, 1)  # 白色边框
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		start_button.modulate = Color(1, 1, 1, 1)  # 正常颜色
	else:
		# 灰色不可点击 - 暗灰色背景 + 深灰边框
		style_box.bg_color = Color(0.2, 0.2, 0.2, 1)  # 深灰色背景
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(0.4, 0.4, 0.4, 1)  # 深灰边框
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		start_button.modulate = Color(0.6, 0.6, 0.6, 1)  # 变暗
	
	start_button.add_theme_stylebox_override("normal", style_box)
	start_button.add_theme_stylebox_override("hover", style_box)
	start_button.add_theme_stylebox_override("pressed", style_box)
	start_button.add_theme_stylebox_override("disabled", style_box)

## 开始游戏按钮被按下
func _on_start_button_pressed() -> void:
	if selected_class_id == "" or selected_weapon_ids.size() != MAX_WEAPONS:
		return
	
	# 保存选择到GameMain
	GameMain.selected_class_id = selected_class_id
	GameMain.selected_weapon_ids = selected_weapon_ids.duplicate()
	
	# 加载游戏场景
	var game_scene = load("res://scenes/map/bg_map.tscn")
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
	else:
		push_error("无法加载游戏场景！")
