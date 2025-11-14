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
	
	# 设置名称（根据品质设置颜色）
	if name_label:
		name_label.text = upgrade_data.name
		# 设置名称颜色为品质颜色
		var quality_color = UpgradeData.get_quality_color(upgrade_data.quality)
		name_label.add_theme_color_override("font_color", quality_color)
		print("设置升级名称: %s, 品质: %s, 颜色: %s" % [
			upgrade_data.name,
			UpgradeData.get_quality_name(upgrade_data.quality),
			quality_color
		])
	
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
	
	# 设置整个选项的边框颜色（modulate）
	var quality_color = UpgradeData.get_quality_color(upgrade_data.quality)
	self.modulate = quality_color.lerp(Color.WHITE, 0.7)  # 混合70%白色，避免过于鲜艳
	
	_update_cost_display()

func get_upgrade_data() -> UpgradeData:
	return upgrade_data

func _update_cost_display() -> void:
	if cost_label and upgrade_data:
		cost_label.text = "%d 钥匙" % upgrade_data.actual_cost
	_update_buy_button()

func _update_buy_button() -> void:
	if not buy_button or not upgrade_data:
		return
	
	var can_afford = GameMain.gold >= upgrade_data.actual_cost
	buy_button.disabled = not can_afford
	
	if not can_afford:
		buy_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		buy_button.modulate = Color.WHITE

func _on_buy_button_pressed() -> void:
	if upgrade_data and GameMain.gold >= upgrade_data.actual_cost:
		purchased.emit(upgrade_data)

func _process(_delta: float) -> void:
	# 实时更新购买按钮状态（钥匙变化时）
	if upgrade_data:
		_update_buy_button()
