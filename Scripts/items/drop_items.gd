extends Area2D
var canMoving = false
var speed = 600
var player
var dir = Vector2.ZERO
var is_collected: bool = false  # 防止重复拾取
var pickup_distance: float = 30.0  # 拾取距离

## 便当配置（拾取回血百分比按最大HP）
const BENTO_HEAL_PERCENTS: Dictionary = {
	"bento1": 0.01,
	"bento2": 0.10,
	"bento3": 0.30,
}

## 显示名称（非multi模式）
const BENTO_DISPLAY_NAMES: Dictionary = {
	"bento1": "谁的健身餐啊！",
	"bento2": "谁的剩饭啊！",
	"bento3": "谁的豪华外卖啊！",
}

## 显示名称（multi模式：用某个墓碑的玩家名拼接）
const BENTO_MULTI_SUFFIX: Dictionary = {
	"bento1": "的健身餐",
	"bento2": "的剩饭",
	"bento3": "的豪华外卖",
}

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
	elif _is_bento(item_type):
		_apply_bento_heal(item_type)
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
	
	# 设置掉落显示名称（bento显示；masterkey不显示；其他默认不显示）
	var name_label: Label = all_ani.get_node_or_null("itemNameLabel")
	if name_label:
		if _is_bento(ani_name):
			name_label.text = _get_bento_display_name(ani_name)
			name_label.visible = true
		else:
			# masterkey / gold 都不显示
			name_label.visible = false
	
	all_ani.get_node("all_animation").play(ani_name)
	pass

func _is_bento(item_type: String) -> bool:
	return BENTO_HEAL_PERCENTS.has(item_type)

func _apply_bento_heal(item_type: String) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# 取最大HP并按百分比计算，至少1点
	var percent: float = float(BENTO_HEAL_PERCENTS.get(item_type, 0.0))
	if percent <= 0.0:
		return
	
	if not ("max_hp" in player) or not ("now_hp" in player):
		return
	
	var max_hp_val: int = int(player.max_hp)
	var heal_amount: int = max(1, int(ceil(max_hp_val * percent)))
	
	var old_hp: int = int(player.now_hp)
	player.now_hp = min(old_hp + heal_amount, max_hp_val)
	var actual_heal: int = int(player.now_hp) - old_hp
	
	if actual_heal > 0:
		# 浮动治愈字
		if SpecialEffects:
			SpecialEffects.show_heal_floating_text(player, actual_heal)
		# 通知UI刷新
		if player.has_signal("hp_changed"):
			player.hp_changed.emit(int(player.now_hp), int(player.max_hp))

func _get_bento_display_name(item_type: String) -> String:
	# multi模式：从当前波次场景里的墓碑随机取一个名字（非玩家自己）
	if GameMain.current_mode_id == "multi":
		var grave_player_name := _get_random_grave_player_name()
		if not grave_player_name.is_empty():
			return grave_player_name + str(BENTO_MULTI_SUFFIX.get(item_type, "的便当"))
	
	# 默认：固定文案
	return str(BENTO_DISPLAY_NAMES.get(item_type, "谁的便当啊！"))

func _get_random_grave_player_name() -> String:
	var tree = get_tree()
	if tree == null:
		return ""
	
	# 优先从玩家头顶NameLabel解析玩家名（格式通常为：名字 - 第 n 世）
	var self_name := ""
	if player != null and is_instance_valid(player):
		var name_label: Label = player.get_node_or_null("NameLabel")
		if name_label and not str(name_label.text).is_empty():
			var t := str(name_label.text)
			# 取 " - " 之前的部分
			var parts = t.split(" - ", false, 1)
			if parts.size() > 0:
				self_name = str(parts[0]).strip_edges()
	
	# 兜底：从存档读取玩家名
	if self_name.is_empty() and SaveManager and SaveManager.has_method("get_player_name"):
		self_name = str(SaveManager.get_player_name()).strip_edges()
	
	# 如果仍然拿不到自己的名字，为避免误把自己的墓碑当成“他人墓碑”，直接回退默认文案
	if self_name.is_empty():
		return ""
	
	var names: Array[String] = []
	for node in tree.get_nodes_in_group("grave"):
		if node == null or not is_instance_valid(node):
			continue
		# grave.gd: var ghost_data: GhostData，里面有 player_name
		if not ("ghost_data" in node):
			continue
		var gd = node.ghost_data
		if gd == null:
			continue
		if not ("player_name" in gd):
			continue
		var n := str(gd.player_name)
		if n.is_empty():
			continue
		# 排除玩家自己
		if n == self_name:
			continue
		names.append(n)
	
	if names.is_empty():
		return ""
	
	# Godot4: Array.pick_random()
	if names.has_method("pick_random"):
		return names.pick_random()
	return names[randi() % names.size()]
