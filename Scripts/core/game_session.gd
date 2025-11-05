extends Node
class_name GameSession

## 游戏会话管理器 - 管理单次游戏的运行时数据

signal gold_changed(new_amount: int, change: int)
signal master_key_changed(new_amount: int, change: int)

var _gold_internal: int = 0
var gold: int = 0:
	get: return _gold_internal
	set(value):
		var old = _gold_internal
		var new_val = max(0, value)
		if new_val != old:
			_gold_internal = new_val
			gold_changed.emit(new_val, new_val - old)

var _master_key_internal: int = 0
var master_key: int = 0:
	get: return _master_key_internal
	set(value):
		var old = _master_key_internal
		var new_val = max(0, value)
		if new_val != old:
			_master_key_internal = new_val
			master_key_changed.emit(new_val, new_val - old)

var score: int = 0
var current_wave: int = 0
var revive_count: int = 0
var selected_class_id: String = ""
var selected_weapon_ids: Array = []
var player: CharacterBody2D = null

func reset() -> void:
	gold = 0
	master_key = 0
	score = 0
	current_wave = 0
	revive_count = 0
	selected_class_id = ""
	selected_weapon_ids.clear()
	print("[GameSession] 会话数据已重置")

func add_gold(amount: int) -> void:
	gold += amount

func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func add_master_key(amount: int) -> void:
	master_key += amount

func remove_master_key(amount: int) -> bool:
	if master_key >= amount:
		master_key -= amount
		return true
	return false

func can_afford(cost: int) -> bool:
	return gold >= cost
