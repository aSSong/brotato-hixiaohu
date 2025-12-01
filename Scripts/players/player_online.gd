extends CharacterBody2D
class_name PlayerCharacter

## 联网模式专用玩家脚本
## 相比 player.gd 简化了单机模式的逻辑，专注于联网同步

@onready var playerAni: AnimatedSprite2D = %AnimatedSprite2D
@onready var trail: Trail = %Trail
@onready var playerCamera: Camera2D = $Camera2D
@onready var weapons_node: Node = get_node_or_null("now_weapons")

## 基础属性
var dir = Vector2.ZERO
var base_speed = 400
var speed = 400
var flip = false
var canMove = true
var stop = false

## 战斗属性
var now_hp = 50
var base_max_hp = 50
var max_hp = 50
var max_exp = 5
var now_exp = 0
var level = 1
var gold = 0
var master_key = 0

## 网络同步的属性（用于 MultiplayerSynchronizer）
var display_name: String = ""
var player_class_id: String = "player2"
var player_role_id: String = "player"

## 网络相关
var is_local_player: bool = true  # 默认为 true（与原版一致）
var peer_id: int = 0
var _sync_completed: bool = false
var _last_synced_hp: int = 50  # 用于跟踪远程玩家的血量变化

## 属性系统（简化版，联网模式主要依赖服务器）
var attribute_manager: AttributeManager = null
var buff_system: BuffSystem = null
var current_class: ClassData = null
var class_manager: ClassManager = null

## Dash系统
@export var dash_duration := 0.5
@export var dash_speed_multi := 2.0
@export var dash_cooldown := 5.0
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null
var is_dashing := false
var dash_available := true

## PvP 系统组件
var pvp_system: PlayerPvPOnline = null

## 信号：血量变化
signal hp_changed(current_hp: int, max_hp: int)

## 名字显示Label
var name_label: Label = null

## 说话气泡组件
var speech_bubble: PlayerSpeechBubble = null

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
	
	# 创建Dash计时器
	_setup_dash_timers()
	
	# 初始化 PvP 系统（联网模式）
	_setup_pvp_system()
	
	# 创建头顶名字显示
	_create_name_label()
	
	# 创建说话气泡组件
	_create_speech_bubble()
	
	# 注册到说话管理器
	call_deferred("_register_to_speech_manager")


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
	
	print("[PlayerOnline] 选择职业: %s" % class_data.name)


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
		playerAni.sprite_frames = ClassDatabase.player_sprite_frames("player2")
		playerAni.play("default")


func get_class_color() -> Color:
	if current_class and "color" in current_class:
		return current_class.color
	return Color.WHITE


func _process(delta: float) -> void:
	_process_local_player(delta)
	_process_remote_player_sync(delta)


func _process_remote_player_sync(delta: float) -> void:
	# 只处理远程玩家（联网模式下非本地玩家）
	if is_local_player or GameMain.current_mode_id != "online":
		return
	
	# 检查血量同步变化（用于死亡状态处理）
	if _last_synced_hp != now_hp:
		_last_synced_hp = now_hp
		_check_remote_death_state()
	
	# 检查同步完成状态
	if not _sync_completed:
		_check_sync_completion()


func _process_local_player(delta: float) -> void:
	# 服务器不处理玩家移动逻辑
	if NetworkManager.is_server():
		return
	
	# 只有本地玩家才处理输入
	if not is_local_player:
		return
	
	var mouse_pos = get_global_mouse_position()
	var self_pos = position
	
	if canMove and not stop:
		flip = mouse_pos.x > self_pos.x
		playerAni.flip_h = flip
		
		dir = (mouse_pos - self_pos).normalized()
		
		if can_dash():
			start_dash()
		
		var final_speed = speed
		if attribute_manager and attribute_manager.final_stats:
			final_speed = attribute_manager.final_stats.speed
		elif class_manager and class_manager.current_class:
			final_speed = class_manager.current_class.speed
		
		if is_dashing:
			final_speed *= dash_speed_multi
		
		velocity = dir * final_speed
		move_and_slide()


func _input(event: InputEvent) -> void:
	# 服务器不处理输入
	if NetworkManager.is_server():
		return
	
	if not is_local_player:
		return
	
	if event.is_action_pressed("skill"):
		activate_class_skill()
		return
	
	# Impostor 叛变触发（按 B 键）
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		if NetworkPlayerManager.can_betray():
			NetworkPlayerManager.trigger_betrayal()
		return
	
	if event.is_action("dash"):
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.is_action("skill") and not event.is_action("dash"):
			canMove = not event.is_pressed()


func _on_stop_mouse_entered() -> void:
	stop = true


func _on_stop_mouse_exited() -> void:
	stop = false


## ==================== PvP 系统 ====================

## 初始化 PvP 系统
func _setup_pvp_system() -> void:
	pvp_system = PlayerPvPOnline.new()
	pvp_system.name = "PvPSystem"
	add_child(pvp_system)


## ==================== 战斗系统 ====================

func player_hurt(damage: int) -> void:
	# 联网模式只有服务器处理伤害计算
	if not NetworkManager.is_server():
		return
	
	var final_damage = damage
	
	if attribute_manager and attribute_manager.final_stats:
		final_damage = DamageCalculator.calculate_defense_reduction(damage, attribute_manager.final_stats)
	else:
		var actual_damage = damage
		if current_class:
			actual_damage = max(1, damage - current_class.defense)
			actual_damage = int(actual_damage * current_class.damage_reduction_multiplier)
		
		if class_manager and class_manager.is_skill_active("护盾"):
			var reduction = class_manager.get_skill_effect("护盾_reduction", 0.0)
			actual_damage = int(actual_damage * (1.0 - reduction))
		
		final_damage = max(1, actual_damage)
	
	print("[PlayerOnline] 服务器处理伤害: peer_id=%d, damage=%d, 服务器端now_hp=%d" % [peer_id, final_damage, now_hp])
	
	# 服务器通知客户端（authority）应用伤害，由客户端修改 now_hp，MultiplayerSynchronizer 会自动同步
	rpc_id(peer_id, "rpc_apply_damage", final_damage)
	
	# 服务器本地显示浮动文字（以当前跟随的玩家作为"当前玩家"）
	var damage_label = "目标 -" + str(final_damage)
	if peer_id == NetworkPlayerManager._following_peer_id:
		damage_label = "玩家 -" + str(final_damage)
	
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),
		damage_label,
		Color(1.0, 0.0, 0.0, 1.0),
		true
	)
	
	# 服务器广播伤害浮动文字给所有客户端（除了被伤害的玩家，他在 rpc_apply_damage 中已显示）
	for client_peer_id in multiplayer.get_peers():
		if client_peer_id != peer_id:  # 跳过被伤害的玩家
			rpc_id(client_peer_id, "rpc_show_damage_text", final_damage, peer_id)


## 客户端（authority）：应用伤害，修改 now_hp，MultiplayerSynchronizer 会自动同步给其他人
@rpc("any_peer", "call_remote", "reliable")
func rpc_apply_damage(damage: int) -> void:
	print("[PlayerOnline] rpc_apply_damage 收到: damage=%d, peer_id=%d, is_local_player=%s, 修改前now_hp=%d" % [damage, peer_id, is_local_player, now_hp])
	
	# 只有 authority（拥有这个玩家的客户端）才处理
	if not is_local_player:
		print("[PlayerOnline] rpc_apply_damage 跳过: 不是本地玩家")
		return
	
	now_hp -= damage
	if now_hp < 0:
		now_hp = 0
	
	print("[PlayerOnline] rpc_apply_damage 应用: 修改后now_hp=%d" % now_hp)
	hp_changed.emit(now_hp, max_hp)
	
	# 显示伤害浮动文字（自己掉血显示"玩家"）
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),
		"玩家 -" + str(damage),
		Color(1.0, 0.0, 0.0, 1.0),
		true
	)
	
	if now_hp <= 0:
		canMove = false
		stop = true
		visible = false
		
		# 直接显示死亡 UI（因为这里已经是本地客户端执行的代码）
		print("[PlayerOnline] 玩家死亡，显示死亡 UI")
		_show_death_ui()


## 客户端（authority）：恢复血量，修改 now_hp，MultiplayerSynchronizer 会自动同步给其他人
@rpc("any_peer", "call_remote", "reliable")
func rpc_heal(heal_amount: int) -> void:
	# 只有 authority（拥有这个玩家的客户端）才处理
	if not is_local_player:
		return
	
	var old_hp = now_hp
	now_hp = min(now_hp + heal_amount, max_hp)
	var actual_heal = now_hp - old_hp
	
	if actual_heal > 0:
		hp_changed.emit(now_hp, max_hp)
		
		# 显示恢复浮动文字
		FloatingText.create_floating_text(
			global_position + Vector2(0, -40),
			"+%d" % actual_heal,
			Color(0.0, 1.0, 0.0),  # 绿色
			true
		)
		print("[PlayerOnline] 恢复血量: %d -> %d (+%d)" % [old_hp, now_hp, actual_heal])


## 客户端（authority）：添加资源，修改 gold/master_key，MultiplayerSynchronizer 会自动同步给其他人
@rpc("any_peer", "call_remote", "reliable")
func rpc_add_resource(item_type: String, amount: int) -> void:
	# 只有 authority（拥有这个玩家的客户端）才处理
	if not is_local_player:
		return
	
	if item_type == "masterkey" or item_type == "master_key":
		master_key += amount
		print("[PlayerOnline] 客户端添加 master_key: %d -> %d" % [master_key - amount, master_key])
	else:
		gold += amount
		print("[PlayerOnline] 客户端添加 gold: %d -> %d" % [gold - amount, gold])


## 其他客户端：显示伤害浮动文字（不修改血量，血量由 MultiplayerSynchronizer 同步）
@rpc("any_peer", "call_remote", "reliable")
func rpc_show_damage_text(damage: int, hurt_peer_id: int) -> void:
	# 本地玩家已在 rpc_apply_damage 中显示，跳过
	if is_local_player:
		return
	
	# 判断是自己掉血还是目标掉血
	var local_peer_id = NetworkManager.get_peer_id()
	var damage_label = "目标 -" + str(damage)
	if hurt_peer_id == local_peer_id:
		damage_label = "玩家 -" + str(damage)
	
	# 显示伤害浮动文字
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),
		damage_label,
		Color(1.0, 0.0, 0.0, 1.0),
		true
	)
	
	hp_changed.emit(now_hp, max_hp)


func disable_weapons() -> void:
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_DISABLED
		weapons_node.visible = false


func enable_weapons() -> void:
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
		weapons_node.visible = true


## 添加初始武器
func add_initial_weapons(weapon_ids: Array) -> void:
	if not weapons_node:
		push_warning("[PlayerOnline] weapons_node 不存在，无法添加武器")
		return
	
	# 先清空现有武器
	if weapons_node.has_method("clear_weapons"):
		weapons_node.clear_weapons()
	
	# 添加初始武器
	for weapon_id in weapon_ids:
		if weapons_node.has_method("add_weapon"):
			await weapons_node.add_weapon(weapon_id)
			print("[PlayerOnline] 添加武器: %s" % weapon_id)
	
	print("[PlayerOnline] 初始武器添加完成: %s" % str(weapon_ids))


## Impostor 叛变后的回调（用于视觉效果等）
func on_betrayal() -> void:
	print("[PlayerOnline] %s 叛变了！" % display_name)
	
	# 更新名字标签颜色为橙色（叛变者）
	if name_label:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 1.0))
	
	# 可以添加其他视觉效果，如粒子特效等


func get_attack_multiplier() -> float:
	var multiplier = 1.0
	if current_class:
		multiplier = current_class.attack_multiplier
	return multiplier


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


## ==================== Dash系统 ====================

func _setup_dash_timers() -> void:
	dash_timer = Timer.new()
	dash_timer.name = "DashTimer"
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.name = "DashCooldownTimer"
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)


func can_dash() -> bool:
	return not is_dashing and \
		dash_cooldown_timer.is_stopped() and \
		Input.is_action_just_pressed("dash") and \
		dir != Vector2.ZERO


func start_dash() -> void:
	is_dashing = true
	dash_timer.start()
	playerAni.modulate.a = 0.5
	if trail:
		trail.start_trail()
	
	# 通知其他客户端显示拖尾效果
	if is_local_player:
		rpc("rpc_start_dash_effect")


## RPC: 通知其他客户端开始 dash 效果
@rpc("any_peer", "call_remote", "reliable")
func rpc_start_dash_effect() -> void:
	# 远程玩家收到通知，显示拖尾效果
	is_dashing = true
	playerAni.modulate.a = 0.5
	if trail:
		trail.start_trail()
	
	# 创建一个本地计时器来结束效果
	await get_tree().create_timer(dash_duration).timeout
	_end_dash_effect()


## 结束 dash 效果（本地和远程都使用）
func _end_dash_effect() -> void:
	is_dashing = false
	playerAni.modulate.a = 1.0


func _on_dash_timer_timeout() -> void:
	_end_dash_effect()
	dash_cooldown_timer.start()


## ==================== 属性系统回调 ====================

func _on_stats_changed(new_stats: CombatStats) -> void:
	if not new_stats:
		return
	
	var old_max_hp = max_hp
	var hp_increase = new_stats.max_hp - old_max_hp
	
	max_hp = new_stats.max_hp
	speed = new_stats.speed
	
	if hp_increase > 0:
		var old_hp = now_hp
		now_hp = min(now_hp + hp_increase, max_hp)
		var actual_heal = now_hp - old_hp
		
		if actual_heal > 0:
			SpecialEffects.show_heal_floating_text(self, actual_heal)
	
	if now_hp > max_hp:
		now_hp = max_hp
	
	hp_changed.emit(now_hp, max_hp)


func _on_buff_tick(buff_id: String, tick_data: Dictionary) -> void:
	SpecialEffects.apply_dot_damage(self, tick_data)


func activate_class_skill() -> void:
	if class_manager:
		class_manager.activate_skill()


func _on_skill_activated(skill_name: String) -> void:
	print("[PlayerOnline] 技能激活: %s" % skill_name)


func _on_skill_deactivated(skill_name: String) -> void:
	print("[PlayerOnline] 技能结束: %s" % skill_name)


## ==================== UI ====================

func _create_name_label() -> void:
	name_label = Label.new()
	add_child(name_label)
	
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-125, -190)
	name_label.size = Vector2(120, 30)
	
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.z_index = 100


func _update_name_label() -> void:
	if name_label == null:
		return
	
	# 如果 display_name 已经设置（通过网络同步），直接使用
	if display_name != "":
		name_label.text = display_name
		return
	
	# 否则从SaveManager获取玩家名字和死亡次数（仅用于本地玩家）
	# 设置后会通过 MultiplayerSynchronizer 同步给其他客户端
	if is_local_player:
		var player_name = SaveManager.get_player_name()
		var total_death = SaveManager.get_total_death_count()
		var local_display_name = "%s - 第 %d 世" % [player_name, total_death + 1]
		name_label.text = local_display_name
		display_name = local_display_name


func set_display_name(name: String) -> void:
	display_name = name
	if name_label:
		name_label.text = name


func get_display_name() -> String:
	return display_name


func _create_speech_bubble() -> void:
	speech_bubble = get_node_or_null("PlayerSpeechBubble")
	
	if not speech_bubble:
		var speech_bubble_scene = load("res://scenes/players/player_speech_bubble.tscn")
		if speech_bubble_scene:
			speech_bubble = speech_bubble_scene.instantiate()
			speech_bubble.name = "PlayerSpeechBubble"
			add_child(speech_bubble)


func show_speech(text: String, duration: float = 3.0) -> void:
	if speech_bubble:
		speech_bubble.show_speech(text, duration)


func _register_to_speech_manager() -> void:
	var speech_manager = get_tree().get_first_node_in_group("speech_manager")
	if speech_manager and speech_manager.has_method("register_speaker"):
		speech_manager.register_speaker(self)


## ==================== 网络配置 ====================

func configure_as_local() -> void:
	is_local_player = true
	_sync_completed = true
	
	set_process_input(true)
	canMove = true
	stop = false
	visible = true
	
	if playerCamera:
		playerCamera.enabled = true
		playerCamera.make_current()
		if not playerCamera.is_in_group("camera"):
			playerCamera.add_to_group("camera")
	
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
		weapons_node.visible = true
	
	if class_manager:
		class_manager.set_process(true)
	
	_update_name_label()


func configure_as_remote() -> void:
	is_local_player = false
	_sync_completed = false
	
	set_process_input(false)
	canMove = false
	stop = false
	visible = false  # 等待同步完成后显示
	
	if playerCamera:
		playerCamera.enabled = false
		if playerCamera.is_current():
			playerCamera.clear_current()
		if playerCamera.is_in_group("camera"):
			playerCamera.remove_from_group("camera")
	
	if weapons_node:
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
		weapons_node.visible = false
	
	if class_manager:
		class_manager.set_process(false)


func mark_sync_completed() -> void:
	if _sync_completed:
		return
	
	_sync_completed = true
	
	if not is_local_player:
		visible = true
		
		# 显示武器
		if weapons_node:
			weapons_node.visible = true
		
		# 更新名字标签
		if name_label and display_name != "":
			name_label.text = display_name
		
		# 应用职业
		if player_class_id != "":
			chooseClass(player_class_id)
		
		print("[PlayerCharacter] 远程玩家同步完成: peer_id=%d, name=%s" % [peer_id, display_name])


## 检查同步是否完成（远程玩家）
func _check_sync_completion() -> void:
	if is_local_player or _sync_completed:
		return
	
	# 检查关键属性是否已同步
	var display_name_valid = display_name != ""
	var class_id_valid = player_class_id != ""
	
	# 如果所有属性都已同步，标记为完成并显示
	if display_name_valid and class_id_valid:
		_sync_completed = true
		visible = true
		
		# 显示武器
		if weapons_node:
			weapons_node.visible = true
		
		# 更新名字标签
		if name_label:
			name_label.text = display_name
		
		# 应用职业
		chooseClass(player_class_id)
		
		print("[PlayerCharacter] 远程玩家同步完成: peer_id=%d, name=%s" % [peer_id, display_name])


## 检查远程玩家的死亡状态（在血量同步后调用）
func _check_remote_death_state() -> void:
	if is_local_player:
		return
	
	# 当血量同步后，检查是否需要更新死亡状态
	if now_hp <= 0:
		_apply_remote_death_state()
	else:
		_apply_remote_alive_state()


func _apply_remote_death_state() -> void:
	if not visible:
		return
	visible = false
	canMove = false
	stop = true
	if weapons_node:
		weapons_node.visible = false
		weapons_node.process_mode = Node.PROCESS_MODE_DISABLED
	if class_manager:
		class_manager.set_process(false)


func _apply_remote_alive_state() -> void:
	# 只有在同步完成后才显示
	if not _sync_completed:
		return
	if visible:
		return
	visible = true
	if weapons_node:
		weapons_node.visible = true
		weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
	if class_manager:
		class_manager.set_process(false)


## ==================== 物品拾取区域回调 ====================

## 当物品进入拾取检测区域时（用于触发物品开始飞向玩家）
func _on_drop_item_area_area_entered(area: Area2D) -> void:
	# 联网模式：只有服务器处理
	if not NetworkManager.is_server():
		return
	
	if area.is_in_group("drop_item") or area.is_in_group("network_drop"):
		# 检查物品是否有 start_moving_for_player 方法
		if area.has_method("start_moving_for_player"):
			area.start_moving_for_player(peer_id)
		elif "is_moving" in area:
			area.is_moving = true


## ==================== 死亡系统 ====================

const DEATH_UI_SCENE := preload("res://scenes/UI/death_ui.tscn")
var _death_ui: DeathUI = null  # 死亡 UI 引用

## 显示死亡 UI
func _show_death_ui() -> void:
	if _death_ui:
		return  # 已经显示了
	
	# 实例化死亡 UI
	_death_ui = DEATH_UI_SCENE.instantiate()
	add_child(_death_ui)
	
	# 连接信号
	_death_ui.revive_requested.connect(_on_revive_button_pressed)
	_death_ui.give_up_requested.connect(_on_give_up_button_pressed)
	
	# 显示联网模式死亡界面
	_death_ui.show_death_screen_online(master_key)
	
	print("[PlayerOnline] 死亡 UI 已显示, master_key=%d" % master_key)


## 隐藏死亡 UI
func _hide_death_ui() -> void:
	if _death_ui:
		_death_ui.queue_free()
		_death_ui = null


## 复活按钮点击
func _on_revive_button_pressed() -> void:
	print("[PlayerOnline] 请求复活")
	_hide_death_ui()
	
	# 发送复活请求到服务器
	NetworkPlayerManager.request_revive.rpc_id(1)


## 放弃按钮点击
func _on_give_up_button_pressed() -> void:
	print("[PlayerOnline] 放弃游戏")
	_hide_death_ui()
	
	# 返回主菜单
	NetworkManager.stop_network()
	get_tree().change_scene_to_file("res://scenes/UI/main_title.tscn")


## 服务器通知客户端执行复活
@rpc("any_peer", "call_remote", "reliable")
func rpc_revive(full_hp: int) -> void:
	if not is_local_player:
		return
	
	print("[PlayerOnline] 执行复活, HP=%d" % full_hp)
	
	# 恢复血量
	now_hp = full_hp
	hp_changed.emit(now_hp, max_hp)
	
	# 恢复状态
	canMove = true
	stop = false
	visible = true
	
	# 启用武器
	enable_weapons()
	
	# 显示复活特效
	_show_revive_effect()


## 其他客户端：显示复活特效
@rpc("any_peer", "call_remote", "reliable")
func rpc_show_revive_effect(revived_peer_id: int) -> void:
	# 找到复活的玩家
	var revived_player = NetworkPlayerManager.get_player_by_peer_id(revived_peer_id)
	if revived_player and is_instance_valid(revived_player):
		revived_player._apply_remote_alive_state()
		print("[PlayerOnline] 其他玩家复活: peer_id=%d" % revived_peer_id)


## 复活结果回调
func on_revive_result(success: bool, message: String) -> void:
	if success:
		print("[PlayerOnline] 复活成功: %s" % message)
	else:
		print("[PlayerOnline] 复活失败: %s" % message)
		# 显示失败消息
		FloatingText.create_floating_text(
			global_position + Vector2(0, -50),
			message,
			Color(1, 0.3, 0.3),
			true
		)
		# 重新显示死亡 UI
		_show_death_ui()


## 显示复活特效
func _show_revive_effect() -> void:
	# 显示复活文字
	FloatingText.create_floating_text(
		global_position + Vector2(0, -50),
		"复活!",
		Color(0.3, 1.0, 0.3),
		true
	)
	
	# 闪烁效果
	var tween = create_tween()
	tween.tween_property(playerAni, "modulate:a", 0.3, 0.1)
	tween.tween_property(playerAni, "modulate:a", 1.0, 0.1)
	tween.tween_property(playerAni, "modulate:a", 0.3, 0.1)
	tween.tween_property(playerAni, "modulate:a", 1.0, 0.1)
