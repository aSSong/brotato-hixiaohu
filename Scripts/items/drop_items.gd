extends Area2D
var canMoving = false
var speed = 600
var player
var dir = Vector2.ZERO
var is_collected: bool = false  # 防止重复拾取
var pickup_distance: float = 30.0  # 拾取距离

# 生成唯一ID用于追踪
var item_id: int = 0
static var _next_id: int = 0

func _ready() -> void:
	item_id = _next_id
	_next_id += 1
	#print("[DropItem ID:", item_id, "] 创建")
	
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
	# 如果已经被拾取，立即停止处理
	if is_collected:
		return
	
	if canMoving:
		# 检查玩家引用是否有效（只在引用失效时查询一次，不每帧查询）
		if player == null or not is_instance_valid(player):
			# 尝试重新获取玩家引用（只查询一次）
			player = get_tree().get_first_node_in_group("player")
			if player == null:
				# 如果找不到玩家，停止移动（不再每帧重试）
				canMoving = false
				return
		
		# 计算距离
		var distance = global_position.distance_to(player.global_position)
		
		# 如果距离足够近，触发拾取
		if distance <= pickup_distance:
			_pickup_item()
			return
		
		# 继续移动
		dir = (player.global_position - self.global_position).normalized()
		global_position += dir * speed * delta

## 拾取物品
func _pickup_item() -> void:
	if is_collected:
		#print("[DropItem ID:", item_id, "] 已被拾取，忽略 | 位置:", global_position)
		return
	
	#print("[DropItem ID:", item_id, "] 开始拾取 | 位置:", global_position)
	
	# 立即标记和停止所有处理
	is_collected = true
	canMoving = false
	set_physics_process(false)  # 立即停止物理处理
	
	# 获取物品类型
	var item_type = "gold"
	if has_meta("item_type"):
		item_type = get_meta("item_type")
	
	#print("[DropItem ID:", item_id, "] 物品类型:", item_type)
	
	# 添加到背包
	if item_type == "masterkey" or item_type == "master_key":
		#print("[DropItem ID:", item_id, "] 调用 GameMain.add_master_key(1)")
		GameMain.add_master_key(1)
	else:
		#print("[DropItem ID:", item_id, "] 调用 GameMain.add_gold(1)")
		GameMain.add_gold(1)
	
	#print("[DropItem ID:", item_id, "] 拾取完成，删除自己")
	# 删除自己
	queue_free()

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
	
	# 获取动画名称（gold或masterkey）
	var ani_name = options.ani_name if options.has("ani_name") else "gold"
	
	# 设置物品类型（用于拾取时判断）
	all_ani.set_meta("item_type", ani_name)
	
	all_ani.get_node("all_animation").play(ani_name)
	pass
