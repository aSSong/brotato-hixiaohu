extends Node

var animation_scene = preload("res://scenes/animations/animations.tscn")
var animation_scene_obj = null
var drop_item_scene = preload("res://scenes/items/drop_items.tscn")
var drop_item_scene_obj = null

var duplicate_node = null

func _ready():
	init_duplicate_node()
	animation_scene_obj = animation_scene.instantiate()
	#add_child(animation_scene_obj)
	drop_item_scene_obj = drop_item_scene.instantiate()
	#add_child(drop_item_scene_obj)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

# 初始化拷贝对象容器
func init_duplicate_node():
	if duplicate_node != null:
		duplicate_node.queue_free()
	var node2d = Node2D.new()
	node2d.name = "duplicate_node"
	get_window().add_child.call_deferred(node2d)
	duplicate_node = node2d
	pass

# 信号：当钥匙数量改变时发出
signal gold_changed(new_amount: int, change: int)
# 信号：当主钥数量改变时发出
signal master_key_changed(new_amount: int, change: int)
signal item_collected(item_type: String)

# 游戏数据 - 使用私有变量和setter避免递归
var _gold_internal: int = 0
var gold: int = 0:
	get:
		return _gold_internal
	set(value):
		print("[GameMain gold setter] 被调用 | 当前值:", _gold_internal, " 新值:", value)
		var old_gold = _gold_internal
		var new_gold = max(0, value)
		if new_gold != old_gold:
			_gold_internal = new_gold
			var change = new_gold - old_gold
			print("[GameMain gold setter] 值改变 | 旧值:", old_gold, " 新值:", new_gold, " 变化:", change)
			gold_changed.emit(new_gold, change)  # 发送信号
		else:
			print("[GameMain gold setter] 值未改变，不发送信号")

var _master_key_internal: int = 0
var master_key: int = 0:
	get:
		return _master_key_internal
	set(value):
		print("[GameMain master_key setter] 被调用 | 当前值:", _master_key_internal, " 新值:", value)
		var old_key = _master_key_internal
		var new_key = max(0, value)
		if new_key != old_key:
			_master_key_internal = new_key
			var change = new_key - old_key
			print("[GameMain master_key setter] 值改变 | 旧值:", old_key, " 新值:", new_key, " 变化:", change)
			master_key_changed.emit(new_key, change)  # 发送信号
		else:
			print("[GameMain master_key setter] 值未改变，不发送信号")

var score: int = 0
var level: int = 1
var revive_count: int = 0  # 本局游戏累计复活次数

# 添加钥匙
func add_gold(amount: int) -> void:
	gold += amount
	item_collected.emit("gold")
	print("获得钥匙: +%d (总计: %d)" % [amount, gold])

# 扣除钥匙
func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

# 添加主钥
func add_master_key(amount: int) -> void:
	master_key += amount
	item_collected.emit("master_key")
	print("获得主钥: +%d (总计: %d)" % [amount, master_key])

# 扣除主钥
func remove_master_key(amount: int) -> bool:
	if master_key >= amount:
		master_key -= amount
		return true
	return false

# 重置游戏数据
func reset_game() -> void:
	gold = 0
	master_key = 0
	score = 0
	level = 1
	revive_count = 0
	print("[GameMain] 游戏数据已重置")

# 玩家选择的数据
var selected_class_id: String = "balanced"
var selected_weapon_ids: Array = []