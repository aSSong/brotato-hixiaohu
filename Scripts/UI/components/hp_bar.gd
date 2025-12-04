extends Control
class_name HPBar

## HP条组件
## 显示玩家血量，支持自动连接到玩家

@onready var hp_value_bar: ProgressBar = $HBoxContainer/hp_value_bar
@onready var hp_label: Label = $HBoxContainer/hp_value_bar/Label

var player_ref: CharacterBody2D = null

func _ready() -> void:
	# 等待一帧确保场景加载完成
	await get_tree().process_frame
	
	# 尝试自动连接玩家
	auto_connect_player()

## 自动连接玩家
func auto_connect_player() -> void:
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		connect_to_player(player_ref)
	else:
		# 如果没找到，等待一下再试
		await get_tree().create_timer(0.2).timeout
		player_ref = get_tree().get_first_node_in_group("player")
		if player_ref:
			connect_to_player(player_ref)

## 连接到玩家
func connect_to_player(player: CharacterBody2D) -> void:
	if not player:
		return
	
	player_ref = player
	
	# 连接玩家血量变化信号
	if player.has_signal("hp_changed"):
		if not player.hp_changed.is_connected(_on_player_hp_changed):
			player.hp_changed.connect(_on_player_hp_changed)
	
	# 初始化显示
	if "now_hp" in player and "max_hp" in player:
		update_hp(player.now_hp, player.max_hp)

## 更新血量显示
func update_hp(current: int, maximum: int) -> void:
	if not hp_value_bar or not hp_label:
		return
	
	# 更新ProgressBar
	hp_value_bar.max_value = maximum
	hp_value_bar.value = current
	
	# 更新Label文本
	hp_label.text = "%d / %d" % [current, maximum]

## 玩家血量变化回调
func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	update_hp(current_hp, max_hp)
