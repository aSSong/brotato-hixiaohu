extends Node
class_name GameSession

## 游戏会话管理器
## 管理单次游戏的运行时数据，从GameMain解耦

## 信号
signal gold_changed(new_amount: int, change: int)
signal master_key_changed(new_amount: int, change: int)
signal session_started()
signal session_ended()

# ========== 游戏数据 ==========
var _gold_internal: int = 0
var gold: int = 0:
	get:
		return _gold_internal
	set(value):
		var old_gold = _gold_internal
		var new_gold = max(0, value)
		if new_gold != old_gold:
			_gold_internal = new_gold
			var change = new_gold - old_gold
			gold_changed.emit(new_gold, change)

var _master_key_internal: int = 0
var master_key: int = 0:
	get:
		return _master_key_internal
	set(value):
		var old_key = _master_key_internal
		var new_key = max(0, value)
		if new_key != old_key:
			_master_key_internal = new_key
			var change = new_key - old_key
			master_key_changed.emit(new_key, change)

var score: int = 0
var current_wave: int = 0
var revive_count: int = 0  # 本局游戏累计复活次数

# ========== 玩家选择数据 ==========
var selected_class_id: String = ""
var selected_weapon_ids: Array = []

# ========== 引用 ==========
var player: CharacterBody2D = null
var map_controller: Node = null
var wave_system: Node = null

func _init() -> void:
	print("[GameSession] 游戏会话初始化")

## 开始新会话
func start_session() -> void:
	reset()
	session_started.emit()
	print("[GameSession] 会话开始")

## 结束会话
func end_session() -> void:
	session_ended.emit()
	print("[GameSession] 会话结束")

## 重置会话数据
func reset() -> void:
	gold = 0
	master_key = 0
	score = 0
	current_wave = 0
	revive_count = 0
	selected_class_id = ""
	selected_weapon_ids.clear()
	player = null
	map_controller = null
	wave_system = null
	print("[GameSession] 会话数据已重置")

# ========== 便捷方法 ==========

## 添加金币
func add_gold(amount: int) -> void:
	gold += amount

## 扣除金币
func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

## 添加主钥
func add_master_key(amount: int) -> void:
	master_key += amount

## 扣除主钥
func remove_master_key(amount: int) -> bool:
	if master_key >= amount:
		master_key -= amount
		return true
	return false

## 检查是否能支付
func can_afford(cost: int) -> bool:
	return gold >= cost

## 获取会话状态信息
func get_session_info() -> Dictionary:
	return {
		"gold": gold,
		"master_key": master_key,
		"score": score,
		"wave": current_wave,
		"revive_count": revive_count,
		"class": selected_class_id,
		"weapons": selected_weapon_ids.size()
	}

