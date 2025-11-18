extends CharacterBody2D
@onready var playerAni: AnimatedSprite2D = %AnimatedSprite2D
@onready var trail: Trail = %Trail

var dir = Vector2.ZERO
var base_speed = 400  # 基础速度
var speed = 400
var flip =false
var canMove = true
var stop = false

var now_hp = 50
var base_max_hp = 50  # 基础最大血量
var max_hp = 50
var max_exp = 5
var now_exp = 0
var level = 1
var gold = 0

## ===== 新属性系统 =====
var attribute_manager: AttributeManager = null  ## 属性管理器
var buff_system: BuffSystem = null  ## Buff系统

## 职业系统
var current_class: ClassData = null
var class_manager: ClassManager = null

## Ghost管理器
var ghost_manager: GhostManager = null

## 路径记录（用于Ghost跟随）
var path_history: Array = []
var path_record_distance: float = 3.0  # 路径记录间隔（减小以获得更平滑的跟随）
var last_recorded_position: Vector2 = Vector2.ZERO
var max_path_points: int = 300  # 最多记录的路径点数量（增加以支持更多Ghost）

## Dash系统
@export var dash_duration := 0.5
@export var dash_speed_multi := 2.0
@export var dash_cooldown := 5.0
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null
var is_dashing := false
var dash_available := true


var original_path_record_distance: float = 3.0  # 保存原始路径记录间隔

## 信号：血量变化
signal hp_changed(current_hp: int, max_hp: int)

## 名字显示Label
var name_label: Label = null

func _ready() -> void:
	# 初始化属性管理器
	attribute_manager = AttributeManager.new()
	attribute_manager.name = "AttributeManager"
	add_child(attribute_manager)
	attribute_manager.stats_changed.connect(_on_stats_changed)
	
	# 初始化Buff系统
	buff_system = BuffSystem.new()
	buff_system.name = "BuffSystem"
	add_child(buff_system)
	buff_system.buff_tick.connect(_on_buff_tick)
	
	# 初始化职业管理器
	class_manager = ClassManager.new()
	add_child(class_manager)
	class_manager.skill_activated.connect(_on_skill_activated)
	class_manager.skill_deactivated.connect(_on_skill_deactivated)
	
	# 初始化Ghost管理器
	ghost_manager = GhostManager.new()
	add_child(ghost_manager)
	ghost_manager.set_player(self)
	
	# 初始化路径记录
	last_recorded_position = global_position
	path_history.append(global_position)
	original_path_record_distance = path_record_distance
	
	# 创建Dash计时器
	_setup_dash_timers()
	
	# 默认选择玩家外观
	choosePlayer("player2")
	
	# 从GameMain读取选择的职业，如果没有则使用默认值
	var class_id = GameMain.selected_class_id if GameMain.selected_class_id != "" else "balanced"
	chooseClass(class_id)
	
	# 创建头顶名字显示
	_create_name_label()
	pass

func choosePlayer(type):
	var player_path = "res://assets/player/"
	
	playerAni.sprite_frames.clear_all()
	
	var sprite_frame_custom = SpriteFrames.new()
	#sprite_frame_custom.add_animation("default")
	#sprite_frame_custom.set_animation_loop("default",true)
	var texture_size = Vector2(520,240)
	var sprite_size = Vector2(130,240)
	var full_texture : Texture = load(player_path + type + "-sheet.png")
	
	var num_columns = int(texture_size.x / sprite_size.x )
	var num_row = int(texture_size.y / sprite_size.y )
	
	for x in range(num_columns):
		for y in range(num_row):
			var frame = AtlasTexture.new()
			frame.atlas = full_texture
			frame.region = Rect2(Vector2(x,y) * sprite_size,sprite_size)
			sprite_frame_custom.add_frame("default",frame)
	playerAni.sprite_frames = sprite_frame_custom
	playerAni.play("default")
	pass

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var self_pos = position
	

	
	if canMove and !stop:
		if mouse_pos.x > self_pos.x:
			flip = true
		else:
			flip = false
	
		playerAni.flip_h = flip
		
		dir = (mouse_pos - self_pos).normalized()
		
		# 检查是否可以dash
		if can_dash():
			start_dash()
		
		# 应用速度加成（使用新系统）
		var final_speed = speed
		# 新系统：速度已经在 attribute_manager.final_stats 中计算好了
		# 不需要额外应用 class_manager 的被动效果
		if attribute_manager and attribute_manager.final_stats:
			final_speed = attribute_manager.final_stats.speed
		elif class_manager and class_manager.current_class:
			# 降级方案：使用旧系统
			final_speed = class_manager.current_class.speed
		
		# 应用dash速度倍数
		if is_dashing:
			final_speed *= dash_speed_multi
		
		velocity = dir * final_speed
		#移动
		move_and_slide()
		
		# 记录路径点（用于Ghost跟随）
		_record_path_point()
	pass
	
func _input(event):
	# 检查技能输入并激活
	if event.is_action_pressed("skill"):
		activate_class_skill()
		return
	
	# 检查是否是dash输入动作（需要优先处理，避免被鼠标左键逻辑拦截）
	if event.is_action("dash"):
		# dash输入不应该影响移动状态，让_process中的can_dash()处理
		return
	
	# 检查是否是添加Ghost的输入动作
	if event.is_action_pressed("Add_ghost"):
		# 创建Ghost
		if ghost_manager:
			ghost_manager.spawn_ghost()
		return
	
	# 处理鼠标左键的移动逻辑
	# 但需要排除技能和dash输入的情况
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果这个鼠标事件是技能或dash输入的一部分，不处理移动逻辑
		if not event.is_action("skill") and not event.is_action("dash"):
			if event.is_pressed():
				canMove = false
			else:
				canMove = true
		
	


func _on_stop_mouse_entered() -> void:
	stop = true
	#print("STOP = TRUE")
	

func _on_stop_mouse_exited() -> void:
	stop = false
	#print("STOP = FALSE")


func _on_drop_item_area_area_entered(area: Area2D) -> void:
	
	if area.is_in_group("drop_item"):
		area.canMoving = true
		#print("开始移动")
	pass # Replace with function body.


func _on_stop_area_entered(area: Area2D) -> void:
	if area.is_in_group("drop_item"):
		# 检查是否已经被拾取（防止重复计数）
		if "is_collected" in area and area.is_collected:
			print("[Player] 物品已被拾取，忽略: ", area)
			return
		
		print("[Player] 拾取物品: ", area)
		
		# 立即标记为已拾取，并停止移动
		if "is_collected" in area:
			area.is_collected = true
		if "canMoving" in area:
			area.canMoving = false
		
		# 获取物品类型（从元数据或属性）
		var item_type = "gold"  # 默认
		if area.has_meta("item_type"):
			item_type = area.get_meta("item_type")
		elif "item_type" in area:
			item_type = area.item_type
		
		# 根据类型添加对应的物品
		if item_type == "masterkey" or item_type == "master_key":
			GameMain.add_master_key(1)
		else:
			GameMain.add_gold(1)
		
		# 播放拾取音效（可选）
		# $PickupSound.play()
		
		# 延迟删除物品，避免在碰撞检测期间删除
		area.call_deferred("queue_free")
	pass # Replace with function body.

## 选择职业
func chooseClass(class_id: String) -> void:
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data == null:
		push_error("职业不存在: " + class_id)
		return
	
	current_class = class_data
	class_manager.set_class(class_data)
	
	# 确保class_data的base_stats已同步
	if not current_class.base_stats or current_class.base_stats.max_hp == 100:
		current_class.sync_to_base_stats()
	
	# 设置AttributeManager的基础属性
	if attribute_manager:
		attribute_manager.base_stats = current_class.base_stats.clone()
		attribute_manager.recalculate()
	
	print("选择职业: ", class_data.name)
	print("描述: ", class_data.description)
	print("特性: ", class_data.traits)

## 属性变化回调
##
## 当AttributeManager重新计算后，应用新属性到玩家
func _on_stats_changed(new_stats: CombatStats) -> void:
	if not new_stats:
		return
	
	# 应用新属性
	max_hp = new_stats.max_hp
	speed = new_stats.speed
	
	# 确保当前血量不超过最大血量
	if now_hp > max_hp:
		now_hp = max_hp
	
	# 发送血量变化信号
	hp_changed.emit(now_hp, max_hp)
	
	print("[Player] 属性更新: HP=%d/%d, Speed=%.1f" % [now_hp, max_hp, speed])

## Buff Tick回调
## 
## 当Buff触发Tick效果时（DoT伤害等）
func _on_buff_tick(buff_id: String, tick_data: Dictionary) -> void:
	# 处理DoT伤害
	SpecialEffects.apply_dot_damage(self, tick_data)

## 应用职业属性（保留旧系统兼容）
func _apply_class_stats() -> void:
	if current_class == null:
		return
	
	# 旧系统：直接设置属性
	max_hp = base_max_hp + current_class.max_hp - base_max_hp
	if now_hp > max_hp:
		now_hp = max_hp
	
	hp_changed.emit(now_hp, max_hp)
	speed = base_speed * (current_class.speed / 400.0)

## 激活技能（可以绑定到按键）
func activate_class_skill() -> void:
	if class_manager:
		class_manager.activate_skill()

## 技能激活回调
func _on_skill_activated(skill_name: String) -> void:
	print("技能激活: ", skill_name)
	# 可以在这里添加视觉特效等

## 技能取消激活回调
func _on_skill_deactivated(skill_name: String) -> void:
	print("技能结束: ", skill_name)

## 获取攻击力倍数（用于武器伤害计算）
func get_attack_multiplier() -> float:
	var multiplier = 1.0
	if current_class:
		multiplier = current_class.attack_multiplier
	
	# 新系统：伤害倍数已经在 DamageCalculator 中计算
	# 这里只需要返回基础的 attack_multiplier
	# 职业被动和技能效果由 AttributeManager 统一管理
	
	return multiplier

## 获取武器类型伤害倍数
func get_weapon_type_multiplier(weapon_type: WeaponData.WeaponType) -> float:
	if not current_class:
		return 1.0
	
	match weapon_type:
		WeaponData.WeaponType.MELEE:
			return current_class.melee_damage_multiplier
		WeaponData.WeaponType.RANGED:
			return current_class.ranged_damage_multiplier
		WeaponData.WeaponType.MAGIC:
			return current_class.magic_damage_multiplier
	
	return 1.0

## 玩家受伤
func player_hurt(damage: int) -> void:
	# 使用新的DamageCalculator计算最终伤害
	var final_damage = damage
	
	if attribute_manager and attribute_manager.final_stats:
		final_damage = DamageCalculator.calculate_defense_reduction(
			damage,
			attribute_manager.final_stats
		)
	else:
		# 降级方案：使用旧系统
		var actual_damage = damage
		if current_class:
			actual_damage = max(1, damage - current_class.defense)
			actual_damage = int(actual_damage * current_class.damage_reduction_multiplier)
		
		# 应用技能减伤
		if class_manager and class_manager.is_skill_active("护盾"):
			var reduction = class_manager.get_skill_effect("护盾_reduction", 0.0)
			actual_damage = int(actual_damage * (1.0 - reduction))
		
		final_damage = max(1, actual_damage)
	
	now_hp -= final_damage
	
	# 确保血量不小于0
	if now_hp < 0:
		now_hp = 0
	
	# 发送血量变化信号
	hp_changed.emit(now_hp, max_hp)
	
	# 显示伤害跳字
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),  # 在玩家上方显示
		"-" + str(final_damage),
		Color(1.0, 0.8, 0.2)  # 黄色伤害数字（区别于敌人）
	)
	
	# 检查是否死亡
	if now_hp <= 0:
		now_hp = 0
		# 立即禁用玩家控制和显示
		canMove = false
		stop = true
		
		# 禁用武器（彻底停止攻击）
		_disable_weapons()
		
		# 隐藏玩家
		visible = false
		
		# 死亡逻辑由DeathManager处理
		# hp_changed信号会通知DeathManager

## 禁用所有武器（彻底停止攻击）
func _disable_weapons() -> void:
	var weapons_node = get_node_or_null("now_weapons")
	if weapons_node:
		# 停止武器处理（不再攻击）
		weapons_node.process_mode = Node.PROCESS_MODE_DISABLED
		# 隐藏武器
		weapons_node.visible = false
		print("[Player] 武器已禁用")

## 启用所有武器（复活时调用）
func enable_weapons() -> void:
	var weapons_node = get_node_or_null("now_weapons")
	if weapons_node:
		# 恢复武器处理
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
		# 显示武器
		weapons_node.visible = true
		print("[Player] 武器已启用")

## 记录路径点（用于Ghost跟随）
func _record_path_point() -> void:
	# 如果移动距离超过记录间隔，记录新的路径点
	if global_position.distance_to(last_recorded_position) >= path_record_distance:
		path_history.append(global_position)
		last_recorded_position = global_position
		
		# 限制路径点数量，删除最旧的路径点
		if path_history.size() > max_path_points:
			path_history.pop_front()

## 获取路径历史（供Ghost使用）
func get_path_history() -> Array:
	return path_history

## 创建头顶名字Label
func _create_name_label() -> void:
	# 创建Label节点
	name_label = Label.new()
	add_child(name_label)
	
	# 设置Label属性
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置位置（在角色头顶上方）
	name_label.position = Vector2(-125, -190)  # 根据角色大小调整
	name_label.size = Vector2(120, 30)
	
	# 设置字体大小和颜色
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 添加黑色描边效果
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	
	# 设置z_index确保在角色上方显示
	name_label.z_index = 100
	
	# 更新名字显示
	_update_name_label()

## 更新名字Label显示内容
func _update_name_label() -> void:
	if name_label == null:
		return
	
	# 从SaveManager获取玩家名字和死亡次数
	var player_name = SaveManager.get_player_name()
	var total_death = SaveManager.get_total_death_count()
	
	# 格式：名字 - n世（n = total_death_count + 1）
	var display_name = "%s - 第 %d 世" % [player_name, total_death + 1]
	name_label.text = display_name

## 设置Dash计时器
func _setup_dash_timers() -> void:
	# 创建Dash持续时间计时器
	dash_timer = Timer.new()
	dash_timer.name = "DashTimer"
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(dash_timer)
	
	# 创建Dash冷却计时器
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.name = "DashCooldownTimer"
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)

## 检查是否可以dash
func can_dash() -> bool:
	return not is_dashing and\
		dash_cooldown_timer.is_stopped() and\
		Input.is_action_just_pressed("dash") and\
		dir != Vector2.ZERO

## 开始dash
func start_dash() -> void:
	is_dashing = true
	dash_timer.start()
	
	# 减少透明度
	playerAni.modulate.a = 0.5
	
	# 启动trail效果
	if trail:
		trail.start_trail()
	
	# 禁用碰撞
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	
	# 减少路径记录间隔，使Ghost跟随更平滑
	path_record_distance = original_path_record_distance * 0.5

## Dash计时器超时回调
func _on_dash_timer_timeout() -> void:
	is_dashing = false
	
	# 恢复透明度
	playerAni.modulate.a = 1.0
	
	# 恢复路径记录间隔
	path_record_distance = original_path_record_distance
	
	# 重置移动方向（可选，根据原示例）
	# dir = Vector2.ZERO  # 注释掉，保持当前移动方向
	
	# 重新启用碰撞
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", false)
	
	# 开始冷却计时器
	dash_cooldown_timer.start()
