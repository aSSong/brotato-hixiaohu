extends CharacterBody2D
@onready var playerAni: AnimatedSprite2D = %AnimatedSprite2D

var dir = Vector2.ZERO
var base_speed = 400  # 基础速度
var speed = 400
var flip =false
var canMove = true
var stop = false

var now_hp = 100
var base_max_hp = 100  # 基础最大血量
var max_hp = 100
var max_exp = 5
var now_exp = 0
var level = 1
var gold = 0

## 职业系统
var current_class: ClassData = null
var class_manager: ClassManager = null

## 信号：血量变化
signal hp_changed(current_hp: int, max_hp: int)

func _ready() -> void:
	# 初始化职业管理器
	class_manager = ClassManager.new()
	add_child(class_manager)
	class_manager.skill_activated.connect(_on_skill_activated)
	class_manager.skill_deactivated.connect(_on_skill_deactivated)
	
	# 默认选择玩家外观
	choosePlayer("player2")
	
	# 从GameMain读取选择的职业，如果没有则使用默认值
	var class_id = GameMain.selected_class_id if GameMain.selected_class_id != "" else "balanced"
	chooseClass(class_id)
	pass

func choosePlayer(type):
	var player_path = "res://assets/player/"
	
	playerAni.sprite_frames.clear_all()
	
	var sprite_frame_custom = SpriteFrames.new()
	#sprite_frame_custom.add_animation("default")
	#sprite_frame_custom.set_animation_loop("default",true)
	var texture_size = Vector2(960,240)
	var sprite_size = Vector2(240,240)
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
	
	if mouse_pos.x > self_pos.x:
		flip = false
	else:
		flip = true
	
	playerAni.flip_h = flip
	
	dir = (mouse_pos - self_pos).normalized()
	
	if canMove and !stop:
		# 应用速度加成
		var final_speed = speed
		if class_manager:
			final_speed *= class_manager.get_passive_effect("speed_multiplier", 1.0)
			# 检查技能效果（使用安全的访问方式）
			if class_manager.is_skill_active("全面强化"):
				var multiplier = class_manager.get_skill_effect("全面强化_multiplier", 1.0)
				if multiplier > 0:
					final_speed *= multiplier
		
		velocity = dir * final_speed
		#移动
		move_and_slide()	
	pass
	
func _input(event):
	# 检查是否是技能输入动作
	# 如果事件匹配技能输入动作，不处理移动逻辑
	if event.is_action("skill"):
		# 技能输入不应该影响移动状态
		return
	
	# 处理鼠标左键的移动逻辑
	# 但需要排除技能输入的情况
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果这个鼠标事件也是技能输入的一部分，不处理移动逻辑
		if not event.is_action("skill"):
			if event.is_pressed():
				canMove = false
			else:
				canMove = true
		
	


func _on_stop_mouse_entered() -> void:
	stop = true
	

func _on_stop_mouse_exited() -> void:
	stop = false


func _on_drop_item_area_area_entered(area: Area2D) -> void:
	
	if area.is_in_group("drop_item"):
		area.canMoving = true
		#print("开始移动")
	pass # Replace with function body.


func _on_stop_area_entered(area: Area2D) -> void:
	#print("进入区域")
	if area.is_in_group("drop_item"):
		# 添加金币到全局管理器
		GameMain.add_gold(1)
		
		# 播放拾取音效（可选）
		# $PickupSound.play()
		
		# 删除金币
		area.queue_free()
	pass # Replace with function body.

## 选择职业
func chooseClass(class_id: String) -> void:
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data == null:
		push_error("职业不存在: " + class_id)
		return
	
	current_class = class_data
	class_manager.set_class(class_data)
	
	# 应用职业基础属性
	_apply_class_stats()
	
	print("选择职业: ", class_data.name)
	print("描述: ", class_data.description)
	print("特性: ", class_data.traits)

## 应用职业属性
func _apply_class_stats() -> void:
	if current_class == null:
		return
	
	# 应用血量
	max_hp = base_max_hp + current_class.max_hp - 100  # 减去默认值，加上职业值
	# 如果当前血量超过最大血量，调整当前血量
	if now_hp > max_hp:
		now_hp = max_hp
	
	# 发送血量变化信号（初始化时）
	hp_changed.emit(now_hp, max_hp)
	
	# 应用速度
	speed = base_speed * (current_class.speed / 400.0)  # 相对于基础速度的比例
	
	# 应用防御等其他属性可以在受伤时处理

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
	
	# 应用被动效果
	if class_manager:
		multiplier *= class_manager.get_passive_effect("all_weapon_damage_multiplier", 1.0)
		
		# 检查技能效果（使用安全的访问方式）
		if class_manager.is_skill_active("全面强化"):
			var skill_multiplier = class_manager.get_skill_effect("全面强化_multiplier", 1.0)
			if skill_multiplier > 0:
				multiplier *= skill_multiplier
		if class_manager.is_skill_active("狂暴"):
			multiplier *= class_manager.get_skill_effect("狂暴_damage", 1.0)
	
	return multiplier

## 获取武器类型伤害倍数
func get_weapon_type_multiplier(weapon_type: WeaponData.WeaponType) -> float:
	if not class_manager:
		return 1.0
	
	match weapon_type:
		WeaponData.WeaponType.MELEE:
			return class_manager.get_passive_effect("melee_damage_multiplier", 1.0)
		WeaponData.WeaponType.RANGED:
			return class_manager.get_passive_effect("ranged_damage_multiplier", 1.0)
		WeaponData.WeaponType.MAGIC:
			return class_manager.get_passive_effect("magic_damage_multiplier", 1.0)
	
	return 1.0

## 玩家受伤
func player_hurt(damage: int) -> void:
	# 计算实际伤害（考虑防御）
	var actual_damage = damage
	if current_class:
		actual_damage = max(1, damage - current_class.defense)
	
	# 应用技能减伤
	if class_manager and class_manager.is_skill_active("护盾"):
		var reduction = class_manager.get_skill_effect("护盾_reduction", 0.0)
		actual_damage = int(actual_damage * (1.0 - reduction))
	
	now_hp -= actual_damage
	
	# 确保血量不小于0
	if now_hp < 0:
		now_hp = 0
	
	# 发送血量变化信号
	hp_changed.emit(now_hp, max_hp)
	
	# 显示伤害跳字
	FloatingText.create_floating_text(
		global_position + Vector2(0, -30),  # 在玩家上方显示
		"-" + str(actual_damage),
		Color(1.0, 0.8, 0.2)  # 黄色伤害数字（区别于敌人）
	)
	
	# 检查是否死亡
	if now_hp <= 0:
		now_hp = 0
		# 可以在这里添加死亡逻辑
		print("玩家死亡！")
