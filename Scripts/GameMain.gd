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

# 信号：当金币数量改变时发出
signal gold_changed(new_amount: int, change: int)
signal item_collected(item_type: String)

# 游戏数据
var gold: int = 0:
	set(value):
		var old_gold = gold
		gold = max(0, value)  # 确保不小于 0
		var change = gold - old_gold
		gold_changed.emit(gold, change)  # 发送信号

var score: int = 0
var level: int = 1

# 添加金币
func add_gold(amount: int) -> void:
	gold += amount
	item_collected.emit("gold")
	print("获得金币: +%d (总计: %d)" % [amount, gold])

# 扣除金币
func remove_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

# 重置游戏数据
func reset_game() -> void:
	gold = 0
	score = 0
	level = 1
