extends Area2D
var canMoving = false
var speed = 600
var player
var dir = Vector2.ZERO

func _ready() -> void:
	self.hide()
	self.set_collision_layer_value(5, false)
	player = get_tree().get_first_node_in_group("player")
	pass

#func _process(delta: float) -> void:
	#if canMoving:
		#var dir = (player.global_position- self.global_position).normalized()
		#self.position += dir * speed
	pass
func _physics_process(delta: float) -> void:
	if canMoving:
		# 检查玩家引用是否有效
		if player == null or not is_instance_valid(player):
			# 尝试重新获取玩家引用
			player = get_tree().get_first_node_in_group("player")
			if player == null or not is_instance_valid(player):
				# 如果找不到玩家，停止移动
				canMoving = false
				return
		
		# 确保玩家引用有效后再访问
		if is_instance_valid(player):
			dir = (player.global_position - self.global_position).normalized()
			global_position += dir * speed * delta
	pass
'''
options.box 动画父级
options.ani_name 动画名称
options.position 动画生成坐标
options.scale 动画缩放等级
'''

func gen_drop_item(options):
	if !options.has("box"):
		options.box = GameMain.duplicate_node
	var all_ani = self.duplicate()
	options.box.add_child.call_deferred(all_ani)
	all_ani.show.call_deferred()
	all_ani.set_collision_layer_value.call_deferred(5, true)
#	all_ani.get_node("CollisionShape2D").set_deferred("disabled", false)
	all_ani.scale = options.scale if options.has("scale") else Vector2(1,1)
	#all_ani.position = options.position
	all_ani.position = options.position
	all_ani.get_node("all_animation").play(options.ani_name)
	pass
