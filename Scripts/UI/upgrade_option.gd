extends Control
class_name UpgradeOption

## 单个升级选项UI

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var buy_button: Button = %BuyButton

var upgrade_data: UpgradeData = null

signal purchased(upgrade: UpgradeData)

func _ready() -> void:
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
	_update_cost_display()

func set_upgrade_data(data: UpgradeData) -> void:
	upgrade_data = data
	
	if not upgrade_data:
		return
	
	# 如果@onready变量还没初始化，等待一帧
	if not name_label or not cost_label or not description_label:
		await get_tree().process_frame
	
	# 设置名称
	if name_label:
		name_label.text = upgrade_data.name
		print("设置升级名称: ", upgrade_data.name)
	
	# 设置图标
	if icon_texture and upgrade_data.icon_path != "":
		var texture = load(upgrade_data.icon_path)
		if texture:
			icon_texture.texture = texture
		else:
			print("无法加载图标: ", upgrade_data.icon_path)
	
	# 设置描述
	if description_label:
		var desc_text = upgrade_data.description if upgrade_data.description != "" else ""
		description_label.text = desc_text
		print("设置升级描述: ", desc_text)
	
	_update_cost_display()

func get_upgrade_data() -> UpgradeData:
	return upgrade_data

func _update_cost_display() -> void:
	if cost_label and upgrade_data:
		cost_label.text = "%d 金币" % upgrade_data.cost
	_update_buy_button()

func _update_buy_button() -> void:
	if not buy_button or not upgrade_data:
		return
	
	var can_afford = GameMain.gold >= upgrade_data.cost
	buy_button.disabled = not can_afford
	
	if not can_afford:
		buy_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		buy_button.modulate = Color.WHITE

func _on_buy_button_pressed() -> void:
	if upgrade_data and GameMain.gold >= upgrade_data.cost:
		purchased.emit(upgrade_data)

func _process(_delta: float) -> void:
	# 实时更新购买按钮状态（金币变化时）
	if upgrade_data:
		_update_buy_button()

