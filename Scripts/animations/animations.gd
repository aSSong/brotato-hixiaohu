extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

'''
options.box 动画父级
options.ani_name 动画名称
options.position 动画生成坐标
options.scale 动画缩放等级
'''

func run_animation(options):
	if !options.has("box"):
		options.box = GameMain.duplicate_node
	var all_ani = self.duplicate()
	options.box.add_child(all_ani)
	all_ani.show()
	all_ani.scale = options.scale if options.has("scale") else Vector2(1,1)
	all_ani.position = options.position
	all_ani.get_node("all_animation").play(options.ani_name)
	pass


func _on_all_animation_animation_finished() -> void:
	self.queue_free()
	pass # Replace with function body.
