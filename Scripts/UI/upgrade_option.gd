extends Control
class_name UpgradeOption

## 单个升级选项UI

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var buy_button: Button = %BuyButton
@onready var lock_button: Button = %LockButton

var upgrade_data: UpgradeData = null
var is_locked: bool = false
var position_index: int = -1  # 在商店中的位置索引（0-2）

signal purchased(upgrade: UpgradeData)
signal lock_state_changed(upgrade: UpgradeData, is_locked: bool, position_index: int)

func _ready() -> void:
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
	if lock_button:
		lock_button.pressed.connect(_on_lock_button_pressed)
		print("[UpgradeOption] LockButton 已连接信号")
	else:
		push_warning("[UpgradeOption] LockButton 未找到！")
	_update_cost_display()

## 获取显示价格
## 
## 统一价格获取逻辑，优先返回锁定价格，否则返回波次调整后的价格
func get_display_cost() -> int:
	if not upgrade_data:
		return 0
	
	if upgrade_data.locked_cost >= 0:
		return upgrade_data.locked_cost
	else:
		return UpgradeShop.calculate_wave_adjusted_cost(upgrade_data.actual_cost)

func set_upgrade_data(data: UpgradeData) -> void:
	upgrade_data = data
	
	if not upgrade_data:
		return
	
	# 如果@onready变量还没初始化，等待一帧
	if not name_label or not cost_label or not description_label or not lock_button:
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
	_update_lock_button()

func get_upgrade_data() -> UpgradeData:
	return upgrade_data

func _update_cost_display() -> void:
	if cost_label and upgrade_data:
		var display_cost = get_display_cost()
		cost_label.text = "%d 钥匙" % display_cost
	_update_buy_button()

func _update_buy_button() -> void:
	if not buy_button or not upgrade_data:
		return
	
	var display_cost = get_display_cost()
	var player_gold = _get_player_gold()
	var can_afford = player_gold >= display_cost
	buy_button.disabled = not can_afford
	
	if not can_afford:
		buy_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		buy_button.modulate = Color.WHITE


## 获取玩家当前钥匙数量（兼容单机和联网模式）
func _get_player_gold() -> int:
	if GameMain.current_mode_id == "online":
		# 联网模式：从本地玩家获取
		var local_player = NetworkPlayerManager.local_player
		if local_player:
			var gold = local_player.get("gold")
			if gold != null:
				return gold
		return 0
	else:
		# 单机模式：从 GameMain 获取
		return GameMain.gold


func _on_buy_button_pressed() -> void:
	if upgrade_data:
		var display_cost = get_display_cost()
		var player_gold = _get_player_gold()
		
		if player_gold >= display_cost:
			purchased.emit(upgrade_data)

func set_lock_state(locked: bool) -> void:
	is_locked = locked
	_update_lock_button()

func _update_lock_button() -> void:
	if not lock_button:
		push_warning("[UpgradeOption] LockButton 未找到，无法更新锁定按钮状态")
		return
	if not upgrade_data:
		return
	
	# 所有升级类型都可以锁定/解锁
	lock_button.disabled = false
	
	if is_locked:
		# 锁定态：绿色按钮，文本"已锁定"
		lock_button.text = "已锁定"
		lock_button.modulate = Color(0.0, 1.0, 0.0)  # 绿色
		# 创建绿色样式
		var green_style = StyleBoxFlat.new()
		green_style.bg_color = Color(0.0, 0.8, 0.0, 1.0)  # 深绿色背景
		lock_button.add_theme_stylebox_override("normal", green_style)
	else:
		# 正常态：常规按钮，文本"锁定"
		lock_button.text = "锁定"
		lock_button.modulate = Color.WHITE
		# 移除自定义样式，使用默认样式
		lock_button.remove_theme_stylebox_override("normal")

func _on_lock_button_pressed() -> void:
	if not upgrade_data:
		return
	
	# 切换锁定状态
	is_locked = not is_locked
	_update_lock_button()
	
	# 发送锁定状态变化信号
	lock_state_changed.emit(upgrade_data, is_locked, position_index)

func _process(_delta: float) -> void:
	# 实时更新购买按钮状态（钥匙变化时）
	if upgrade_data:
		_update_buy_button()
