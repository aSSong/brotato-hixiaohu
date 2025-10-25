extends Node

var animation_scene = preload("res://scenes/animations/animations.tscn")
var animation_scene_obj = null
var drop_item_scene = preload("res://scenes/items/drop_items.tscn")
var drop_item_scene_obj = null

var duplicate_node = null

func _ready():
	animation_scene_obj = animation_scene.instantiate()
	#add_child(animation_scene_obj)
	drop_item_scene_obj = drop_item_scene.instantiate()
	#add_child(drop_item_scene_obj)
	
	var node2d = Node2D.new()
	node2d.name = "duplicate_node"
	get_window().add_child.call_deferred(node2d)
	duplicate_node = node2d
	add_child(node2d)
	pass
	
