extends Control
class_name StartMenu

## 开始菜单
## 让用户选择职业和武器

@onready var class_container: VBoxContainer = $MainPanel/VBoxContainer/ClassSection/HSplitContainer/ClassContainer
@onready var weapon_container: VBoxContainer = $MainPanel/VBoxContainer/WeaponSection/HSplitContainer/WeaponContainer
@onready var selected_class_label: Label = $MainPanel/VBoxContainer/ClassSection/SelectedClassLabel
@onready var selected_weapons_label: Label = $MainPanel/VBoxContainer/WeaponSection/SelectedWeaponsLabel
@onready var start_button: Button = $MainPanel/VBoxContainer/StartButton
@onready var class_description: RichTextLabel = $MainPanel/VBoxContainer/ClassSection/HSplitContainer/ClassDescription
@onready var weapon_description: RichTextLabel = $MainPanel/VBoxContainer/WeaponSection/HSplitContainer/WeaponDescription

var selected_class_id: String = "balanced"
var selected_weapon_ids: Array = []

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
	
	# 默认选择平衡者职业
	_select_class("balanced")
	
	# 默认选择一些武器
	_select_weapon("pistol")
	_select_weapon("sword")
	_select_weapon("fireball")
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)

## 填充职业列表
func _populate_classes() -> void:
	var class_ids = ClassDatabase.get_all_class_ids()
	
	for class_id in class_ids:
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data == null:
			continue
		
		# 创建职业按钮
		var button = Button.new()
		button.text = class_data.name
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(_on_class_button_pressed.bind(class_id))
		
		# 如果是当前选择的职业，高亮显示并勾选
		if class_id == selected_class_id:
			button.modulate = Color(0.8, 1.0, 0.8)
		
		class_container.add_child(button)

## 填充武器列表
func _populate_weapons() -> void:
	for weapon_id in available_weapons:
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		if weapon_data == null:
			continue
		
		# 创建水平容器
		var hbox = HBoxContainer.new()
		
		# 创建武器复选框
		var check_box = CheckBox.new()
		check_box.text = weapon_data.weapon_name
		check_box.custom_minimum_size = Vector2(200, 30)
		check_box.toggled.connect(_on_weapon_checkbox_toggled.bind(weapon_id))
		
		# 添加类型标签
		var type_label = Label.new()
		var type_text = ""
		match weapon_data.weapon_type:
			WeaponData.WeaponType.RANGED:
				type_text = "[远程]"
			WeaponData.WeaponType.MELEE:
				type_text = "[近战]"
			WeaponData.WeaponType.MAGIC:
				type_text = "[魔法]"
		type_label.text = type_text
		type_label.custom_minimum_size = Vector2(60, 30)
		
		hbox.add_child(check_box)
		hbox.add_child(type_label)
		
		weapon_container.add_child(hbox)
		
		# 存储weapon_id到check_box的metadata中，方便后续查找
		check_box.set_meta("weapon_id", weapon_id)

## 职业按钮被按下
func _on_class_button_pressed(class_id: String) -> void:
	_select_class(class_id)
	
	# 更新按钮高亮
	for child in class_container.get_children():
		if child is Button:
			if child.text == ClassDatabase.get_class_data(class_id).name:
				child.modulate = Color(0.8, 1.0, 0.8)
			else:
				child.modulate = Color.WHITE

## 选择职业
func _select_class(class_id: String) -> void:
	selected_class_id = class_id
	var class_data = ClassDatabase.get_class_data(class_id)
	
	if class_data == null:
		return
	
	# 更新显示
	selected_class_label.text = "已选择职业: " + class_data.name
	
	# 更新职业描述
	var description_text = "[b]" + class_data.name + "[/b]\n\n"
	description_text += class_data.description + "\n\n"
	description_text += "[b]基础属性:[/b]\n"
	description_text += "血量: " + str(class_data.max_hp) + "\n"
	description_text += "速度: " + str(int(class_data.speed)) + "\n"
	description_text += "攻击倍数: " + str(class_data.attack_multiplier) + "x\n"
	description_text += "防御: " + str(class_data.defense) + "\n"
	description_text += "暴击率: " + str(int(class_data.crit_chance * 100)) + "%\n\n"
	
	if class_data.skill_name != "":
		description_text += "[b]技能: " + class_data.skill_name + "[/b]\n"
		if class_data.skill_description != "":
			description_text += class_data.skill_description + "\n"
	
	if class_data.traits.size() > 0:
		description_text += "\n[b]特性:[/b]\n"
		for trait_value in class_data.traits:
			description_text += "• " + str(trait_value) + "\n"
	
	class_description.text = description_text

## 武器复选框切换
func _on_weapon_checkbox_toggled(toggled_on: bool, weapon_id: String) -> void:
	if toggled_on:
		_select_weapon(weapon_id)
	else:
		_deselect_weapon(weapon_id)

## 选择武器
func _select_weapon(weapon_id: String) -> void:
	if not selected_weapon_ids.has(weapon_id):
		selected_weapon_ids.append(weapon_id)
		_update_weapon_display()

## 取消选择武器
func _deselect_weapon(weapon_id: String) -> void:
	var index = selected_weapon_ids.find(weapon_id)
	if index >= 0:
		selected_weapon_ids.remove_at(index)
		_update_weapon_display()

## 更新武器复选框状态
func _update_weapon_checkbox(weapon_id: String, checked: bool) -> void:
	for child in weapon_container.get_children():
		if child is HBoxContainer:
			var check_box = child.get_child(0)
			if check_box is CheckBox and check_box.get_meta("weapon_id", "") == weapon_id:
				check_box.button_pressed = checked
				break

## 更新武器显示
func _update_weapon_display() -> void:
	if selected_weapon_ids.size() == 0:
		selected_weapons_label.text = "已选择武器: 无"
		weapon_description.text = ""
		return
	
	var weapon_names = []
	var description_text = "[b]已选择武器:[/b]\n\n"
	
	for weapon_id in selected_weapon_ids:
		var weapon_data = WeaponDatabase.get_weapon(weapon_id)
		if weapon_data == null:
			continue
		
		weapon_names.append(weapon_data.weapon_name)
		
		description_text += "[b]" + weapon_data.weapon_name + "[/b]\n"
		description_text += weapon_data.description + "\n"
		
		var type_text = ""
		match weapon_data.weapon_type:
			WeaponData.WeaponType.RANGED:
				type_text = "远程武器"
			WeaponData.WeaponType.MELEE:
				type_text = "近战武器"
			WeaponData.WeaponType.MAGIC:
				type_text = "魔法武器"
		
		description_text += "类型: " + type_text + "\n"
		description_text += "伤害: " + str(weapon_data.damage) + "\n"
		description_text += "攻击速度: " + str(weapon_data.attack_speed) + "秒\n"
		description_text += "范围: " + str(int(weapon_data.range)) + "\n\n"
	
	selected_weapons_label.text = "已选择武器: " + ", ".join(weapon_names)
	weapon_description.text = description_text
	
	# 更新开始按钮状态
	start_button.disabled = selected_weapon_ids.size() == 0

## 开始游戏按钮被按下
func _on_start_button_pressed() -> void:
	if selected_weapon_ids.size() == 0:
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
