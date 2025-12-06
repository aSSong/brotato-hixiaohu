extends TextureRect
class_name UpgradeOption

## 单个升级选项UI

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var buy_button: TextureButton = %BuyButton
@onready var lock_button: TextureButton = %LockButton
@onready var lock_label: Label = $VBoxContainer/HBoxContainer2/LockButton/loockLabel

var upgrade_data: UpgradeData = null
var is_locked: bool = false
var position_index: int = -1  # 在商店中的位置索引（0-2）

signal purchased(upgrade: UpgradeData)
signal lock_state_changed(upgrade: UpgradeData, is_locked: bool, position_index: int)

## 品质背景纹理（静态缓存）
static var quality_panel_textures: Dictionary = {}
## 锁定按钮纹理（静态缓存）
static var lock_button_textures: Dictionary = {}

## 初始化品质背景纹理
static func _init_quality_textures() -> void:
	if quality_panel_textures.is_empty():
		quality_panel_textures = {
			1: load("res://assets/UI/shop_ui/panel-shop-gray-01.png"),    # WHITE
			2: load("res://assets/UI/shop_ui/panel-shop-green-01.png"),   # GREEN
			3: load("res://assets/UI/shop_ui/panel-shop-blue-01.png"),    # BLUE
			4: load("res://assets/UI/shop_ui/panel-shop-purple-01.png"),  # PURPLE
			5: load("res://assets/UI/shop_ui/panel-shop-yellow-01.png")   # ORANGE
		}

## 初始化锁定按钮纹理
static func _init_lock_textures() -> void:
	if lock_button_textures.is_empty():
		lock_button_textures = {
			"locked": load("res://assets/UI/shop_ui/btn-shop-locked-01.png"),
			"unlocked": load("res://assets/UI/shop_ui/btn-shop-unlock-01.png")
		}

func _ready() -> void:
	_init_quality_textures()
	_init_lock_textures()
	
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
	if lock_button:
		lock_button.pressed.connect(_on_lock_button_pressed)
	
	# 如果 upgrade_data 已经在添加到场景树前设置，则初始化 UI
	if upgrade_data:
		_initialize_ui()

## 获取显示价格
## 
## 统一价格获取逻辑，优先返回锁定价格，否则返回波次调整后的价格
func get_display_cost() -> int:
	if not upgrade_data:
		return 0
	
	if upgrade_data.locked_cost >= 0:
		return upgrade_data.locked_cost
	elif upgrade_data.current_price > 0:
		return upgrade_data.current_price
	else:
		return UpgradeShop.calculate_wave_adjusted_cost(upgrade_data.actual_cost)

func set_upgrade_data(data: UpgradeData) -> void:
	upgrade_data = data
	
	if not upgrade_data:
		return
	
	# 如果@onready变量还没初始化，等待一帧
	if not name_label or not cost_label or not description_label or not lock_button:
		await get_tree().process_frame
	
	_initialize_ui()

## 初始化 UI（在 @onready 变量初始化后调用）
func _initialize_ui() -> void:
	if not upgrade_data:
		return
	
	# 根据品质设置背景纹理
	_update_quality_panel()
	
	# 设置名称（根据品质设置颜色）
	if name_label:
		name_label.text = upgrade_data.name
		# 设置名称颜色为品质颜色
		var quality_color = UpgradeData.get_quality_color(upgrade_data.quality)
		name_label.add_theme_color_override("font_color", quality_color)
	
	# 设置图标
	if icon_texture and upgrade_data.icon_path != "":
		var icon = load(upgrade_data.icon_path)
		if icon:
			icon_texture.texture = icon
	
	# 设置描述
	if description_label:
		var desc_text = upgrade_data.description if upgrade_data.description != "" else ""
		description_label.text = desc_text
	
	_update_cost_display()
	_update_lock_button()

## 根据品质更新背景面板纹理
func _update_quality_panel() -> void:
	if not upgrade_data:
		return
	
	_init_quality_textures()
	
	var quality = upgrade_data.quality
	# 确保品质在有效范围内
	quality = clamp(quality, 1, 5)
	
	if quality_panel_textures.has(quality):
		self.texture = quality_panel_textures[quality]
		print("[UpgradeOption] 设置品质面板: %s (品质 %d)" % [upgrade_data.name, quality])

func get_upgrade_data() -> UpgradeData:
	return upgrade_data

func _update_cost_display() -> void:
	if cost_label and upgrade_data:
		var display_cost = get_display_cost()
		cost_label.text = "🔑 %d" % display_cost
	_update_buy_button()

func _update_buy_button() -> void:
	if not buy_button or not upgrade_data:
		return
	
	var display_cost = get_display_cost()
	var can_afford = GameMain.gold >= display_cost
	buy_button.disabled = not can_afford
	
	# 钥匙不足时整个按钮变灰
	if not can_afford:
		buy_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		buy_button.modulate = Color.WHITE

func _on_buy_button_pressed() -> void:
	if upgrade_data:
		var display_cost = get_display_cost()
		
		if GameMain.gold >= display_cost:
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
	
	_init_lock_textures()
	
	# 所有升级类型都可以锁定/解锁
	lock_button.disabled = false
	
	if is_locked:
		# 已锁定状态：使用 locked 图片
		var locked_tex = lock_button_textures.get("locked")
		if locked_tex:
			lock_button.texture_normal = locked_tex
			lock_button.texture_pressed = locked_tex
			lock_button.texture_hover = locked_tex
			lock_button.texture_disabled = locked_tex
			lock_button.texture_focused = locked_tex
		
		# 更新标签：绿字"已锁定"
		if lock_label:
			lock_label.text = "已锁定"
			lock_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))  # 绿色
	else:
		# 未锁定状态：使用 unlocked 图片
		var unlocked_tex = lock_button_textures.get("unlocked")
		if unlocked_tex:
			lock_button.texture_normal = unlocked_tex
			lock_button.texture_pressed = unlocked_tex
			lock_button.texture_hover = unlocked_tex
			lock_button.texture_disabled = unlocked_tex
			lock_button.texture_focused = unlocked_tex
		
		# 更新标签：白字"锁定"
		if lock_label:
			lock_label.text = "锁定"
			lock_label.add_theme_color_override("font_color", Color.WHITE)  # 白色

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

## ========== 翻牌动画 ==========

## 翻入动画（从 scale.x = 0 翻转展开）
func play_flip_in_animation(delay: float = 0.0) -> void:
	# 设置初始状态
	scale.x = 0.0
	pivot_offset = size / 2  # 设置中心点
	modulate = Color(0.5, 0.5, 0.5)  # 初始稍暗
	
	var tween = create_tween()
	tween.set_parallel(true)  # 并行执行
	
	# 如果有延迟，先等待
	if delay > 0:
		tween.tween_interval(delay)
	
	# 翻入动画：scale.x 从 0 到 1
	tween.tween_property(self, "scale:x", 1.0, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(delay)
	
	# 亮度恢复动画
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)\
		.set_delay(delay)

## 翻出动画（从 scale.x = 1 翻转收起）
## 返回 Tween 对象以便等待完成
func play_flip_out_animation() -> Tween:
	pivot_offset = size / 2  # 设置中心点
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# 翻出动画：scale.x 从 1 到 0
	tween.tween_property(self, "scale:x", 0.0, 0.15)
	
	# 变暗动画
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 0.5), 0.15)
	
	return tween
