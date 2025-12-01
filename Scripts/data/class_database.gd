extends Node
class_name ClassDatabase

## 职业数据库（重构版）
## 预定义多个职业及其属性和技能
## 
## 使用新的CombatStats系统管理职业属性

static var classes: Dictionary = {}

## 初始化所有职业
static func initialize_classes() -> void:
	if not classes.is_empty():
		return
	
		# 小美 - 实习生
	var betty = ClassData.new(
		"小美 Betty",
		50,  # max_hp
		400.0,  # speed
		1.15,  # attack_multiplier（所有武器伤害+15%）
		2,  # defense
		0.1,  # crit_chance
		1.8,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	betty.description = "均衡发展的职业，适合所有武器类型"
	# 平衡者已经通过 attack_multiplier 设置了所有武器伤害+15%
	# speed 保持 400.0（移动速度0%）
	# 加载技能数据（新系统）
	betty.skill_data = load("res://resources/skills/all_stats.tres") as SkillData
	# 设置皮肤 (需要先在编辑器创建 SpriteFrames 资源)
	betty.skin_frames = load("res://resources/class_skin/betty01.tres")
	betty.scale = Vector2(0.6, 0.6)
	# 同步到新系统
	betty.sync_to_base_stats()
	# 自动生成特性描述
	betty.generate_traits_description()
	classes["betty"] = betty
	
	
	# 战士 - 高血量、近战加成
	var warrior = ClassData.new(
		"雅加婆婆 Baba Yaga",
		60,  # max_hp
		350.0,  # speed (稍慢)
		1.2,  # attack_multiplier
		5,  # defense
		0.1,  # crit_chance
		2.0,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	warrior.description = "高血量的近战职业，擅长使用近战武器"
	# 设置近战加成
	warrior.melee_damage_multiplier = 1.3  # 近战武器伤害+30%
	warrior.melee_knockback_multiplier = 1.2  # 近战击退+20%
	# 加载技能数据（新系统）
	warrior.skill_data = load("res://resources/skills/berserk.tres") as SkillData
	warrior.skin_frames = load("res://resources/class_skin/babayaga01.tres")
	warrior.scale = Vector2(0.7, 0.7)
	# 同步到新系统
	warrior.sync_to_base_stats()
	# 自动生成特性描述
	warrior.generate_traits_description()
	classes["warrior"] = warrior
	
	# 射手 - 高攻击速度、远程加成
	var ranger = ClassData.new(
		"KeyPerson-射手",
		40,  # max_hp
		450.0,  # speed (较快)
		1.0,  # attack_multiplier
		0,  # defense
		0.2,  # crit_chance (高暴击)
		2.5,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	ranger.description = "高敏捷的远程职业，擅长使用远程武器"
	# 设置远程加成
	ranger.ranged_damage_multiplier = 1.25  # 远程武器伤害+25%
	ranger.attack_speed_multiplier = 1.2  # 攻击速度+20%
	# 加载技能数据（新系统）
	ranger.skill_data = load("res://resources/skills/precision.tres") as SkillData
	# 同步到新系统
	ranger.sync_to_base_stats()
	# 自动生成特性描述
	ranger.generate_traits_description()
	classes["ranger"] = ranger
	
	# 法师 - 低血量、魔法加成、范围伤害
	var mage = ClassData.new(
		"大壮-Armstrong",
		30,  # max_hp (低血量)
		400.0,  # speed
		0.9,  # attack_multiplier (基础攻击稍低)
		0,  # defense
		0.15,  # crit_chance
		2.0,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	mage.description = "高智力的魔法职业，擅长使用魔法武器造成范围伤害"
	# 设置魔法加成
	mage.magic_damage_multiplier = 1.4  # 魔法武器伤害+40%
	mage.magic_explosion_radius_multiplier = 1.3  # 爆炸范围+30%
	mage.magic_speed_multiplier = 0.8  # 魔法冷却-20%（速度降低=冷却减少）
	# 加载技能数据（新系统）
	mage.skill_data = load("res://resources/skills/magic_burst.tres") as SkillData
	mage.skin_frames = load("res://resources/class_skin/armstrong01.tres")
	mage.scale = Vector2(0.6, 0.6)
	# 同步到新系统
	mage.sync_to_base_stats()
	# 自动生成特性描述
	mage.generate_traits_description()
	classes["mage"] = mage
	
	# 平衡者 - 均衡属性
	var balanced = ClassData.new(
		"KeyPerson-平衡者",
		50,  # max_hp
		400.0,  # speed
		1.15,  # attack_multiplier（所有武器伤害+15%）
		2,  # defense
		0.1,  # crit_chance
		1.8,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	balanced.description = "均衡发展的职业，适合所有武器类型"
	# 平衡者已经通过 attack_multiplier 设置了所有武器伤害+15%
	# speed 保持 400.0（移动速度0%）
	# 加载技能数据（新系统）
	balanced.skill_data = load("res://resources/skills/all_stats.tres") as SkillData
	# 同步到新系统
	balanced.sync_to_base_stats()
	# 自动生成特性描述
	balanced.generate_traits_description()
	classes["balanced"] = balanced
	
	# 坦克 - 超高血量、防御
	var tank = ClassData.new(
		"KeyPerson-坦克",
		80,  # max_hp (超高)
		300.0,  # speed (慢)
		0.8,  # attack_multiplier (低攻击)
		10,  # defense (高防御)
		0.05,  # crit_chance
		1.5,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	tank.description = "超高血量和防御的职业，生存能力强"
	# 设置坦克加成
	tank.damage_reduction_multiplier = 0.8  # 受到伤害-20%（减伤系数0.8）
	# 加载技能数据（新系统）
	tank.skill_data = load("res://resources/skills/shield.tres") as SkillData
	# 同步到新系统
	tank.sync_to_base_stats()
	# 自动生成特性描述
	tank.generate_traits_description()
	classes["tank"] = tank
	
	# Boss
	register_boss_class()

	# Player 1-4
	var colors = [
		Color(1.0, 0.4, 0.4),   # 红
		Color(1.0, 0.8, 0.2),   # 黄
		Color(0.2, 0.6, 1.0),   # 蓝
		Color(0.4, 1.0, 0.4),   # 绿
	]
	for i in colors.size():
		register_player_class(i + 1, colors[i])

static func register_boss_class() -> void:
	var boss = ClassData.new(
		"KeyPerson-Boss",
		100,  # max_hp
		500.0,  # speed
		1.5,  # attack_multiplier（所有武器伤害+50%）
		5,  # defense
		0.1,  # crit_chance
		1.8,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	boss.description = "均衡发展的职业，适合所有武器类型"
	# 加载技能数据（新系统）
	boss.skill_data = load("res://resources/skills/all_stats.tres") as SkillData
	boss.skin_frames = boss_sprite_frames()
	boss.scale = Vector2(1.2, 1.2)
	boss.color = Color(0.4, 1.0, 0.4)
	# 同步到新系统
	boss.sync_to_base_stats()
	# 自动生成特性描述
	boss.generate_traits_description()
	classes["boss"] = boss

static func register_player_class(n: int, color: Color) -> void:
	var player = ClassData.new(
		"KeyPerson-Player%d" % n,
		50,  # max_hp
		400.0,  # speed
		1.15,  # attack_multiplier（所有武器伤害+15%）
		2,  # defense
		0.1,  # crit_chance
		1.8,  # crit_damage
		"",  # skill_name (已废弃，使用 skill_data)
		{}  # skill_params (已废弃，使用 skill_data)
	)
	player.description = "均衡发展的职业，适合所有武器类型"
	# 平衡者已经通过 attack_multiplier 设置了所有武器伤害+15%
	# speed 保持 400.0（移动速度0%）
	# 加载技能数据（新系统）
	player.skill_data = load("res://resources/skills/all_stats.tres") as SkillData
	player.skin_frames = player_sprite_frames("player%d" % n)
	player.color = color
	# 同步到新系统
	player.sync_to_base_stats()
	# 自动生成特性描述
	player.generate_traits_description()
	classes["player%d" % n] = player

static func player_sprite_frames(skin: String) -> SpriteFrames:
	var player_path = "res://assets/player/"
	
	var sprite_frame_custom = SpriteFrames.new()
	var texture_size = Vector2(520, 240)
	var sprite_size = Vector2(130, 240)
	var full_texture: Texture = load(player_path + skin + "-sheet.png")
	
	var num_columns = int(texture_size.x / sprite_size.x)
	var num_row = int(texture_size.y / sprite_size.y)
	
	for x in range(num_columns):
		for y in range(num_row):
			var frame = AtlasTexture.new()
			frame.atlas = full_texture
			frame.region = Rect2(Vector2(x, y) * sprite_size, sprite_size)
			sprite_frame_custom.add_frame("default", frame)
	
	return sprite_frame_custom

static func boss_sprite_frames() -> SpriteFrames:
	var boss_path = "res://assets/enemy/boss01-sheet.png"
	
	var sprite_frame_custom = SpriteFrames.new()
	var frame_width = 360
	var frame_height = 240
	var frame_count = 4
	var full_texture: Texture = load(boss_path)
	
	for i in range(frame_count):
		var frame = AtlasTexture.new()
		frame.atlas = full_texture
		frame.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		sprite_frame_custom.add_frame("default", frame)
	
	return sprite_frame_custom

## 获取职业（重命名以避免与Node.get_class()冲突）
static func get_class_data(class_id: String) -> ClassData:
	if classes.is_empty():
		initialize_classes()
	return classes.get(class_id, classes["balanced"])

## 获取所有职业ID
static func get_all_class_ids() -> Array:
	if classes.is_empty():
		initialize_classes()
	return classes.keys()
