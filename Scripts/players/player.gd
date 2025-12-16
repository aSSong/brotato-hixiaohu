extends CharacterBody2D
@onready var playerAni: AnimatedSprite2D = %AnimatedSprite2D
@onready var trail: Trail = %Trail
@onready var name_label: Label = $NameLabel

## ===== 受伤闪白效果配置 =====
const HURT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)  # 闪白颜色
const HURT_FLASH_DURATION: float = 0.1  # 闪白持续时间（秒）

## ===== 复活无敌效果配置 =====
const REVIVE_INVINCIBLE_DURATION: float = 5.0  # 复活无敌持续时间（秒）
const REVIVE_FLASH_COLOR: Color = Color(1.0, 0.85, 0.0, 1.0)  # 金黄色

## 是否正在闪白
var is_flashing: bool = false

## 是否处于复活无敌状态
var is_invincible: bool = false

## FX 节点引用
@onready var revive_fx: AnimatedSprite2D = $"revive-FX"
@onready var skill_fx: AnimatedSprite2D = $"skill-FX"

var dir = Vector2.ZERO
var base_speed = 400  # 基础速度
var speed = 400
var flip =false
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
@export var dash_cooldown := 5.4
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null
var is_dashing := false
var dash_available := true


var original_path_record_distance: float = 3.0  # 保存原始路径记录间隔

## 信号：血量变化
signal hp_changed(current_hp: int, max_hp: int)

## 名字显示Label
#var name_label: Label = null

## 说话气泡组件
var speech_bubble: PlayerSpeechBubble = null

## 拾取范围相关
@onready var drop_item_area: Area2D = $drop_item_area
@onready var camera: Camera2D = $Camera2D
var base_pickup_radius: float = 0.0  # 保存原始拾取半径

## ===== 相机缩放配置 =====
const CAMERA_ZOOM_DEFAULT: float = 0.9  # 默认缩放
const CAMERA_ZOOM_MIN: float = 0.5  # 最小缩放（画面最大）
const CAMERA_ZOOM_MAX: float = 1.8  # 最大缩放（画面最小）
const CAMERA_ZOOM_STEP: float = 0.1  # 每次滚轮缩放的步长
var current_zoom: float = CAMERA_ZOOM_DEFAULT

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
	
	# 保存原始拾取半径
	if drop_item_area:
		var collision_shape = drop_item_area.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			base_pickup_radius = collision_shape.shape.radius
	
	# 创建Dash计时器
	_setup_dash_timers()
	
	# 默认选择玩家外观
	choosePlayer("player2")
	
	# 从GameMain读取选择的职业，如果没有则使用默认值
	var class_id = GameMain.selected_class_id if GameMain.selected_class_id != "" else "balanced"
	chooseClass(class_id)
	
	# 创建头顶名字显示
	_create_name_label()
	
	# 创建说话气泡组件
	_create_speech_bubble()
	
	# 注册到说话管理器
	call_deferred("_register_to_speech_manager")
	
	# 初始化时隐藏 FX 节点
	if revive_fx:
		revive_fx.visible = false
	if skill_fx:
		skill_fx.visible = false
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

## 根据ClassData应用皮肤
func _update_skin_from_class_data() -> void:
	if not current_class:
		return
		
	if current_class.skin_frames:
		# 使用 SpriteFrames 资源
		playerAni.sprite_frames = current_class.skin_frames
		playerAni.play("default")
		playerAni.scale = current_class.scale
	else:
		# 降级处理：默认逻辑
		choosePlayer("player2")

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var self_pos = position
	
	if !stop:
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
	
	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# 滚轮向上：放大画面（增加zoom值）
			_zoom_camera(CAMERA_ZOOM_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# 滚轮向下：缩小画面（减少zoom值）
			_zoom_camera(-CAMERA_ZOOM_STEP)
			return
	


func _on_stop_mouse_entered() -> void:
	stop = true
	print("STOP = TRUE")
	

func _on_stop_mouse_exited() -> void:
	stop = false
	print("STOP = FALSE")


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
	
	# 应用外观
	_update_skin_from_class_data()
	
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
	
	# 计算最大HP的变化量
	var old_max_hp = max_hp
	var hp_increase = new_stats.max_hp - old_max_hp
	
	# 应用新属性
	max_hp = new_stats.max_hp
	speed = new_stats.speed
	
	# 如果最大HP增加了，同时恢复相应的HP
	if hp_increase > 0:
		var old_hp = now_hp
		now_hp = min(now_hp + hp_increase, max_hp)
		var actual_heal = now_hp - old_hp
		
		# 显示HP恢复的浮动文字（使用统一方法）
		if actual_heal > 0:
			SpecialEffects.show_heal_floating_text(self, actual_heal)
	
	# 确保当前血量不超过最大血量
	if now_hp > max_hp:
		now_hp = max_hp
	
	# 发送血量变化信号
	hp_changed.emit(now_hp, max_hp)
	
	# 更新拾取范围
	_update_pickup_range(new_stats)
	
	print("[Player] 属性更新: HP=%d/%d (+%d), Speed=%.1f" % [now_hp, max_hp, hp_increase, speed])

## 更新拾取范围
func _update_pickup_range(stats: CombatStats) -> void:
	if not drop_item_area or base_pickup_radius <= 0:
		return
	
	var collision_shape = drop_item_area.get_node("CollisionShape2D")
	if not collision_shape or not collision_shape.shape is CircleShape2D:
		return
	
	var new_radius = base_pickup_radius * stats.key_pickup_range_mult
	collision_shape.shape.radius = new_radius
	
	print("[Player] 拾取范围更新: %.1f -> %.1f (x%.2f)" % [base_pickup_radius, new_radius, stats.key_pickup_range_mult])

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
	
	# 获取技能持续时间
	var duration = 0.0
	if class_manager and class_manager.current_class and class_manager.current_class.skill_data:
		duration = class_manager.current_class.skill_data.duration
	
	# 播放 skill-FX 动画
	if skill_fx and duration > 0:
		skill_fx.visible = true
		skill_fx.play("skill")
		
		# 持续时间结束后自动停止
		await get_tree().create_timer(duration).timeout
		
		# 安全检查：节点是否有效
		if is_instance_valid(self):
			_stop_skill_fx()

## 技能取消激活回调
func _on_skill_deactivated(skill_name: String) -> void:
	print("技能结束: ", skill_name)

## 停止技能特效
func _stop_skill_fx() -> void:
	if skill_fx:
		skill_fx.stop()
		skill_fx.visible = false

## 强制停止技能特效（死亡时调用）
func force_stop_skill_fx() -> void:
	_stop_skill_fx()

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
	# 如果伤害 <= 0，直接返回（不造成伤害）
	if damage <= 0:
		return
	
	# 如果处于无敌状态，不受伤害
	if is_invincible:
		return
	
	# 使用新的DamageCalculator计算最终伤害
	var final_damage = damage
	
	if attribute_manager and attribute_manager.final_stats:
		final_damage = DamageCalculator.calculate_defense_reduction(
			damage,
			attribute_manager.final_stats
		)
		# 保险：只要触发伤害（原始伤害 > 0），最终伤害最小为1
		final_damage = max(1, final_damage)
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
		#"玩家 -" + str(final_damage),
		Color(1.0, 0.0, 0.0, 1.0),  # 伤害数字（区别于敌人）
		true  # 玩家受伤总是使用大字体/动画效果
	)
	
	# 播放受伤闪白效果
	player_flash()
	
	# 检查是否死亡
	if now_hp <= 0:
		now_hp = 0
		# 立即禁用玩家控制和显示
		stop = true
		
		# 隐藏玩家
		visible = false
		
		# 注意：不要在这里禁用武器，这会导致Ghost的武器也失效（如果Ghost引用了Player的disable_weapons）
		# 也不要在这里调用_disable_weapons，应该让DeathManager来统一管理
		# DeathManager会在触发死亡时调用disable_weapons
		
		# 死亡逻辑由DeathManager处理
		# hp_changed信号会通知DeathManager

## 禁用所有武器（彻底停止攻击）
func disable_weapons() -> void:
	_disable_weapons()

## 内部禁用武器实现
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
		# 刷新武器属性引用（修复复活后特效不触发的问题）
		if weapons_node.has_method("reapply_all_bonuses"):
			weapons_node.reapply_all_bonuses()
		print("[Player] 武器已启用")

## 受伤闪白效果
func player_flash() -> void:
	if not playerAni or not playerAni.material:
		return
	
	# 如果已经在闪白，不重复触发
	if is_flashing:
		return
	
	is_flashing = true
	
	# 设置 shader 闪白参数
	playerAni.material.set_shader_parameter("flash_color", HURT_FLASH_COLOR)
	playerAni.material.set_shader_parameter("flash_opacity", 1.0)
	
	# 等待闪白持续时间
	await get_tree().create_timer(HURT_FLASH_DURATION).timeout
	
	# 恢复原状
	playerAni.material.set_shader_parameter("flash_opacity", 0.0)
	
	is_flashing = false

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
	#name_label = Label.new()
	#add_child(name_label)
	
	# 设置Label属性
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 设置位置（在角色头顶上方）
	#name_label.position = Vector2(-125, -190)  # 根据角色大小调整
	#name_label.size = Vector2(120, 30)
	
	# 设置字体大小和颜色
	#name_label.add_theme_font_size_override("font_size", 36)
	#name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# 添加黑色描边效果
	#name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	#name_label.add_theme_constant_override("outline_size", 2)
	
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
	
	# 开始冷却计时器
	dash_cooldown_timer.start()

## 创建说话气泡组件（如果场景中没有手动添加）
func _create_speech_bubble() -> void:
	# 尝试从场景中获取已添加的气泡组件
	speech_bubble = get_node_or_null("PlayerSpeechBubble")
	
	if speech_bubble:
		print("[Player] 从场景中找到说话气泡组件")
	else:
		# 如果场景中没有，动态创建（降级方案）
		var speech_bubble_scene = load("res://scenes/players/player_speech_bubble.tscn")
		if speech_bubble_scene:
			speech_bubble = speech_bubble_scene.instantiate()
			speech_bubble.name = "PlayerSpeechBubble"
			
			# 直接添加到Player节点下，作为子节点（与场景中手动添加的效果一致）
			add_child(speech_bubble)
			print("[Player] 说话气泡组件已动态创建并添加到Player节点下")
		else:
			push_error("[Player] 无法加载说话气泡场景！")

## 显示说话气泡
func show_speech(text: String, duration: float = 3.0) -> void:
	if speech_bubble:
		speech_bubble.show_speech(text, duration)
	else:
		push_warning("[Player] 说话气泡组件未找到！")

## 注册到说话管理器
func _register_to_speech_manager() -> void:
	print("[Player] 尝试注册到说话管理器...")
	var speech_manager = get_tree().get_first_node_in_group("speech_manager")
	if speech_manager:
		print("[Player] 找到SpeechManager: ", speech_manager.name)
		if speech_manager.has_method("register_speaker"):
			speech_manager.register_speaker(self)
			print("[Player] 已注册到SpeechManager")
		else:
			push_error("[Player] SpeechManager没有register_speaker方法！")
	else:
		push_warning("[Player] 未找到SpeechManager！")

## ===== 相机缩放功能 =====

## 缩放相机
## @param delta_zoom: 缩放变化量（正值放大，负值缩小）
func _zoom_camera(delta_zoom: float) -> void:
	if not camera:
		return
	
	# 计算新的缩放值
	current_zoom = clamp(current_zoom + delta_zoom, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	
	# 应用缩放
	camera.zoom = Vector2(current_zoom, current_zoom)

## 重置相机缩放到默认值
func reset_camera_zoom() -> void:
	current_zoom = CAMERA_ZOOM_DEFAULT
	if camera:
		camera.zoom = Vector2(current_zoom, current_zoom)

## 设置相机缩放值
func set_camera_zoom(zoom_value: float) -> void:
	current_zoom = clamp(zoom_value, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	if camera:
		camera.zoom = Vector2(current_zoom, current_zoom)

## ===== 复活无敌功能 =====

## 开始复活无敌效果
func start_revive_invincibility() -> void:
	if is_invincible:
		return
	
	is_invincible = true
	print("[Player] 开始复活无敌，持续 %.1f 秒" % REVIVE_INVINCIBLE_DURATION)
	
	# 播放 revive-FX 的 revive 动画
	if revive_fx:
		revive_fx.visible = true
		revive_fx.play("revive")
	
	# 设置金黄色 shader 效果
	if playerAni and playerAni.material:
		playerAni.material.set_shader_parameter("flash_color", REVIVE_FLASH_COLOR)
		playerAni.material.set_shader_parameter("flash_opacity", 0.5)  # 半透明金黄色
	
	# 5秒后结束无敌
	await get_tree().create_timer(REVIVE_INVINCIBLE_DURATION).timeout
	
	# 安全检查：节点是否有效，是否仍在无敌状态
	if is_instance_valid(self) and is_invincible:
		_end_revive_invincibility()

## 结束复活无敌效果
func _end_revive_invincibility() -> void:
	if not is_invincible:
		return
	
	is_invincible = false
	print("[Player] 复活无敌结束")
	
	# 停止 revive-FX 动画并隐藏
	if revive_fx:
		revive_fx.stop()
		revive_fx.visible = false
	
	# 恢复 shader 效果
	if playerAni and playerAni.material:
		playerAni.material.set_shader_parameter("flash_opacity", 0.0)

## 强制结束无敌（死亡时调用）
func force_end_invincibility() -> void:
	if is_invincible:
		is_invincible = false
		if revive_fx:
			revive_fx.stop()
			revive_fx.visible = false
		if playerAni and playerAni.material:
			playerAni.material.set_shader_parameter("flash_opacity", 0.0)
