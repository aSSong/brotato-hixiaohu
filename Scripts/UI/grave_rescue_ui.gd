extends CanvasLayer
class_name GraveRescueUI

## 救援界面UI
## 显示Ghost信息，提供救援、超度、取消选项

@onready var panel: TextureRect = $Panel
@onready var cost_label: Label = $Panel/ButtonContainer/RescueButton/CostLabel
@onready var rescue_button: TextureButton = $Panel/ButtonContainer/RescueButton
@onready var rescue_label: Label = $"Panel/ButtonContainer/RescueButton/rescue-label"
@onready var transcend_button: TextureButton = $Panel/ButtonContainer/TranscendButton
@onready var cancel_button: TextureButton = $Panel/ButtonContainer/CancelButton
@onready var dead_poster: TextureRect = $Panel/centersection/"dead-poster"
@onready var name_label: Label = $Panel/name/name
@onready var weapon_list: GridContainer = $Panel/weaponlist

## 武器组件场景
var weapon_compact_scene: PackedScene = preload("res://scenes/UI/components/weapon_compact.tscn")

## 信号
signal rescue_requested  # 请求救援
signal transcend_requested  # 请求超度
signal cancelled  # 取消

var ghost_data: GhostData = null

func _ready() -> void:
	# 连接按钮信号
	rescue_button.pressed.connect(_on_rescue_pressed)
	transcend_button.pressed.connect(_on_transcend_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# 设置武器列表为3行2列
	weapon_list.columns = 2
	
	# 默认隐藏
	hide()

## 显示救援界面
func show_rescue_dialog(data: GhostData) -> void:
	ghost_data = data
	
	if not ghost_data:
		push_error("[GraveRescueUI] Ghost数据为空")
		return
	
	# 更新死亡海报
	_update_dead_poster()
	
	# 更新名字标签："楼层数  名字（换行）第 总死亡次数 世"
	_update_name_label()
	
	# 填充武器列表
	_populate_weapon_list()
	
	# 检查是否有足够的masterkey并更新费用显示
	var current_keys = GameMain.master_key
	cost_label.text = "费用：2把 生命钥匙 \n(当前：" + str(current_keys) + "把)"
	
	# 更新救援按钮状态（动态内容）
	if current_keys >= 2:
		rescue_button.disabled = false
		rescue_label.text = "拯  救"
	else:
		rescue_button.disabled = true
		rescue_label.text = "生命钥匙不足"
	
	# 显示界面
	show()
	
	print("[GraveRescueUI] 显示救援界面")

## 更新死亡海报
func _update_dead_poster() -> void:
	if not ghost_data:
		return
	
	var class_data = ClassDatabase.get_class_data(ghost_data.class_id)
	if class_data and class_data.dead_poster:
		dead_poster.texture = class_data.dead_poster
	elif class_data and class_data.poster:
		# 如果没有 dead_poster，使用 poster 作为备用
		dead_poster.texture = class_data.poster

## 更新名字标签
func _update_name_label() -> void:
	if not ghost_data:
		return
	
	# 格式："楼层数  名字（换行）第 总死亡次数 世"
	var floor_text = str(ghost_data.wave) + "F"
	var name_text = ghost_data.player_name if ghost_data.player_name else "未知"
	var death_text = "第" + str(ghost_data.total_death_count) + "世"
	
	name_label.text = floor_text + "  " + name_text + "\n" + death_text

## 填充武器列表
func _populate_weapon_list() -> void:
	# 清空现有武器
	for child in weapon_list.get_children():
		child.queue_free()
	
	if not ghost_data or ghost_data.weapons.is_empty():
		return
	
	# 最多显示6把武器
	var max_weapons = min(ghost_data.weapons.size(), 6)
	
	for i in range(max_weapons):
		var weapon_info = ghost_data.weapons[i]
		
		# 实例化武器组件
		var weapon_compact: WeaponCompact = weapon_compact_scene.instantiate()
		weapon_list.add_child(weapon_compact)
		
		# 使用 WeaponCompact 的接口设置武器数据
		weapon_compact.setup_from_weapon_info(weapon_info)

## 救援按钮按下
func _on_rescue_pressed() -> void:
	if GameMain.master_key >= 2:
		print("[GraveRescueUI] 玩家选择救援")
		rescue_requested.emit()
		hide()

## 超度按钮按下
func _on_transcend_pressed() -> void:
	print("[GraveRescueUI] 玩家选择超度")
	transcend_requested.emit()
	hide()

## 取消按钮按下
func _on_cancel_pressed() -> void:
	print("[GraveRescueUI] 玩家取消")
	cancelled.emit()
	hide()

## 隐藏界面
func hide_dialog() -> void:
	hide()
