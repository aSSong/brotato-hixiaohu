extends Node
class_name BulletDatabase

## 子弹数据库
## 
## 预定义各种子弹类型，供武器配置使用

static var bullets: Dictionary = {}

## 初始化所有子弹
static func initialize_bullets() -> void:
	if not bullets.is_empty():
		return
	
	# ========== 基础子弹 ==========
	
	var normal_bullet = BulletData.new("normal_bullet", 2000.0, 3.0, "res://assets/bullet/bullet.png")
	normal_bullet.bullet_name = "普通子弹"
	normal_bullet.scale = Vector2(1.0, 1.0)
	normal_bullet.movement_type = BulletData.MovementType.STRAIGHT
	#normal_bullet.movement_params = {
		#"rotate_to_direction": true  # 朝向飞行方向
	#}
	bullets["normal_bullet"] = normal_bullet
	
	var fast_bullet = BulletData.new("fast_bullet", 3000.0, 2.5, "res://assets/bullet/bullet.png")
	fast_bullet.bullet_name = "高速子弹"
	fast_bullet.scale = Vector2(0.8, 0.8)
	fast_bullet.modulate = Color(0.0, 0.866, 0.867, 1.0)
	fast_bullet.movement_type = BulletData.MovementType.STRAIGHT
	#fast_bullet.movement_params = {
		#"rotate_to_direction": true  # 朝向飞行方向
	#}
	bullets["fast_bullet"] = fast_bullet
	
	# 机枪子弹（基于 fast_bullet 参数，带枪口和击中特效）
	var mg_bullet = BulletData.new("mg_bullet", 3000.0, 2.5, "res://assets/weapon/machinegun/mg-bullet.png")
	mg_bullet.bullet_name = "机枪子弹"
	mg_bullet.scale = Vector2(0.3, 0.3)
	mg_bullet.movement_type = BulletData.MovementType.STRAIGHT
	mg_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	# 序列帧动画配置：横3竖3，20fps
	mg_bullet.hframes = 3
	mg_bullet.vframes = 3
	mg_bullet.animation_speed = 20.0
	mg_bullet.loop_animation = true
	# 枪口特效配置
	mg_bullet.muzzle_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	mg_bullet.muzzle_effect_ani_name = "mg_muzzle"
	mg_bullet.muzzle_effect_scale = 2.5
	# 击中特效配置
	mg_bullet.hit_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	mg_bullet.hit_effect_ani_name = "mg_hit"
	mg_bullet.hit_effect_scale = 1.0
	bullets["mg_bullet"] = mg_bullet
	
	# ----闪电长矛的子弹---------
	
	var ls_bullet = BulletData.new("ls_bullet", 1500.0, 4.0, "res://assets/weapon/lighitningspear/ls-bullet.png")
	ls_bullet.bullet_name = "闪电长矛子弹"
	ls_bullet.scale = Vector2(1.0, 1.0)
	ls_bullet.movement_type = BulletData.MovementType.STRAIGHT
	ls_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	# 序列帧动画配置：横2竖4，10fps
	ls_bullet.hframes = 2
	ls_bullet.vframes = 4
	ls_bullet.animation_speed = 10.0
	ls_bullet.loop_animation = true
	# 枪口特效配置
	ls_bullet.muzzle_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	ls_bullet.muzzle_effect_ani_name = "ls_fx"
	ls_bullet.muzzle_effect_scale = 1.5
	# 击中特效配置
	ls_bullet.hit_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	ls_bullet.hit_effect_ani_name = "ls_hit"
	ls_bullet.hit_effect_scale = 1.0
	# 拖尾特效（需要单独的拖尾场景）
	ls_bullet.trail_effect_path = "res://scenes/effects/ls_trail.tscn"
	bullets["ls_bullet"] = ls_bullet
	
	# ----旧版重型子弹（保留兼容）---------
	
	var heavy_bullet = BulletData.new("heavy_bullet", 1500.0, 4.0, "res://FX/fx-spark-Sheet-01.png")
	heavy_bullet.bullet_name = "重型子弹"
	heavy_bullet.scale = Vector2(1.0, 1.0)
	heavy_bullet.movement_type = BulletData.MovementType.STRAIGHT
	heavy_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	# 序列帧动画配置
	heavy_bullet.hframes = 3           # 水平帧数（3列）
	heavy_bullet.vframes = 1           # 垂直帧数（1行）
	heavy_bullet.animation_speed = 10.0  # 播放速度 10fps
	heavy_bullet.loop_animation = true   # 循环播放（默认就是true，可省略）
	bullets["heavy_bullet"] = heavy_bullet
	
	# ========== 手动新子弹 ==========
	var shuriken_bullet = BulletData.new("shuriken_bullet", 800.0, 4.0, "res://assets/bullet/bullet-shuriken.png")
	shuriken_bullet.bullet_name = "手里剑子弹"
	shuriken_bullet.scale = Vector2(0.5, 0.5)
	shuriken_bullet.movement_type = BulletData.MovementType.STRAIGHT
	# 新增：手里剑自转
	shuriken_bullet.movement_params = {
		"self_rotation_speed": 720.0
	}
	bullets["shuriken_bullet"] = shuriken_bullet
	
	# ========== 特殊子弹 ==========
	
	## 追踪导弹子弹
	var ms_bullet = BulletData.new("ms_bullet", 1000.0, 8.0, "res://assets/weapon/missle/ms-bullet.png")
	ms_bullet.bullet_name = "追踪导弹子弹"
	ms_bullet.scale = Vector2(0.5, 0.5)
	ms_bullet.movement_type = BulletData.MovementType.HOMING
	ms_bullet.movement_params = {
		"turn_speed": 8.0,        # 转向速度
		"acceleration": 100.0,    # 加速度
		"max_speed": 1200.0,      # 最大速度
		"homing_delay": 0.2,      # 发射后延迟追踪
		"wobble_amount": 15.0,    # 左右摆动幅度
		"wobble_frequency": 8.0   # 摆动频率
	}
	# 序列帧动画配置：横4竖4，10fps
	ms_bullet.hframes = 4
	ms_bullet.vframes = 4
	ms_bullet.animation_speed = 26.0
	ms_bullet.loop_animation = true
	# 枪口特效配置
	ms_bullet.muzzle_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	ms_bullet.muzzle_effect_ani_name = "ms_muzzle"
	ms_bullet.muzzle_effect_scale = 2.0
	# 击中特效配置
	ms_bullet.hit_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	ms_bullet.hit_effect_ani_name = "ms_hit"
	ms_bullet.hit_effect_scale = 1.8
	ms_bullet.trail_effect_path = "res://scenes/effects/ms_trail.tscn"
	bullets["ms_bullet"] = ms_bullet
	
	# 旧版追踪子弹（保留兼容）
	var homing_bullet = BulletData.new("homing_bullet", 1000.0, 8.0,"res://FX/fx-missle-Sheet-01.png")
	homing_bullet.bullet_name = "追踪子弹"
	homing_bullet.scale = Vector2(2.5, 2.5)
	homing_bullet.modulate = Color(1.0, 1.0, 1.0, 1.0)
	homing_bullet.movement_type = BulletData.MovementType.HOMING
	homing_bullet.movement_params = {
		"turn_speed": 8.0,
		"acceleration": 100.0,
		"max_speed": 1200.0,
		"homing_delay": 0.2,
		"wobble_amount": 15.0,
		"wobble_frequency": 8.0
	}
	homing_bullet.hframes = 4
	homing_bullet.vframes = 1
	homing_bullet.animation_speed = 10.0
	homing_bullet.loop_animation = true
	bullets["homing_bullet"] = homing_bullet
	
	
	var arcane_bullet = BulletData.new("arcane_bullet", 600.0, 8.0,"res://FX/fx-arcane-Sheet-01.png")
	arcane_bullet.bullet_name = "奥术飞弹"
	arcane_bullet.scale = Vector2(1.0, 1.0)
	#arcane_bullet.modulate = Color(0.645, 0.51, 1.0, 1.0)
	arcane_bullet.movement_type = BulletData.MovementType.HOMING
	arcane_bullet.movement_params = {
		"turn_speed": 8.0,        # 降低转向速度，让它转大弯
		"acceleration": 50.0,    # 增加加速度，越飞越快
		"max_speed": 1200.0,      # 稍微降低极速，让玩家看清轨迹
		"homing_delay": 0.2,      # 发射后 0.2秒内直飞，不追踪
		"wobble_amount": 15.0,    # 15度的左右摆动
		"wobble_frequency": 8.0   # 摆动频率
	}
	arcane_bullet.hframes = 10           # 水平帧数（4列）
	arcane_bullet.vframes = 1           # 垂直帧数（1行）
	arcane_bullet.animation_speed = 10.0  # 播放速度 10fps
	arcane_bullet.loop_animation = true   # 循环播放（默认就是true，可省略）
	# 紫色魔法拖尾特效
	arcane_bullet.trail_effect_path = "res://scenes/effects/arcane_trail.tscn"
	bullets["arcane_bullet"] = arcane_bullet
	
	## 连锁闪电子弹
	var lc_bullet = BulletData.new("lc_bullet", 1200.0, 6.0, "res://assets/weapon/lightningchain/lc-bullet.png")
	lc_bullet.bullet_name = "连锁闪电子弹"
	lc_bullet.scale = Vector2(0.8, 0.8)
	lc_bullet.movement_type = BulletData.MovementType.BOUNCE
	lc_bullet.movement_params = {
		"rotate_to_direction": true,  # 朝向飞行方向
		"bounce_count": 3,      # 最大弹跳次数
		"bounce_loss": 0.9,     # 每次弹跳速度保留比例
		"search_range": 800.0   # 弹跳目标搜索范围
	}
	# 序列帧动画配置：横4竖4，10fps
	lc_bullet.hframes = 4
	lc_bullet.vframes = 4
	lc_bullet.animation_speed = 10.0
	lc_bullet.loop_animation = true
	lc_bullet.destroy_on_hit = false  # 弹跳子弹不会立即销毁
	# 枪口特效配置
	lc_bullet.muzzle_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	lc_bullet.muzzle_effect_ani_name = "lc_fx"
	lc_bullet.muzzle_effect_scale = 1.5
	# 击中特效配置
	lc_bullet.hit_effect_scene_path = "res://scenes/effects/weapon_FX_sprites.tscn"
	lc_bullet.hit_effect_ani_name = "lc_hit"
	lc_bullet.hit_effect_scale = 1.0
	# 拖尾特效（需要单独的拖尾场景）
	lc_bullet.trail_effect_path = "res://scenes/effects/lc_trail.tscn"
	bullets["lc_bullet"] = lc_bullet
	
	# 旧版弹跳子弹（保留兼容）
	var bounce_bullet = BulletData.new("bounce_bullet", 1200.0, 6.0, "res://FX/fx-ligntningchain-Sheet-01.png")
	bounce_bullet.bullet_name = "弹跳子弹"
	bounce_bullet.scale = Vector2(1.0, 1.0)
	bounce_bullet.movement_type = BulletData.MovementType.BOUNCE
	bounce_bullet.movement_params = {
		"rotate_to_direction": true,
		"bounce_count": 3,
		"bounce_loss": 0.9,
		"search_range": 800.0
	}
	bounce_bullet.hframes = 10
	bounce_bullet.vframes = 1
	bounce_bullet.animation_speed = 10.0
	bounce_bullet.loop_animation = true
	bounce_bullet.destroy_on_hit = false
	bullets["bounce_bullet"] = bounce_bullet
	
	var wave_bullet = BulletData.new("wave_bullet", 1800.0, 4.0, "res://assets/bullet/bullet.png")
	wave_bullet.bullet_name = "波浪子弹"
	wave_bullet.scale = Vector2(0.9, 0.9)
	wave_bullet.modulate = Color(1.0, 0.7, 1.0)
	wave_bullet.movement_type = BulletData.MovementType.WAVE
	wave_bullet.movement_params = {
		"amplitude": 40.0,     # 波浪振幅
		"frequency": 4.0       # 波浪频率
	}
	bullets["wave_bullet"] = wave_bullet
	
	# ========== 元素子弹 ==========
	
	var fire_bullet = BulletData.new("fire_bullet", 2200.0, 3.0, "res://assets/bullet/bullet.png")
	fire_bullet.bullet_name = "火焰子弹"
	fire_bullet.scale = Vector2(1.2, 1.2)
	fire_bullet.modulate = Color(1.0, 0.5, 0.2)
	fire_bullet.movement_type = BulletData.MovementType.STRAIGHT
	fire_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	# 可配置火焰轨迹特效
	# fire_bullet.trail_effect_path = "res://scenes/effects/fire_trail.tscn"
	bullets["fire_bullet"] = fire_bullet
	
	var ice_bullet = BulletData.new("ice_bullet", 2000.0, 3.5, "res://assets/bullet/bullet_blue.png")
	ice_bullet.bullet_name = "冰霜子弹"
	ice_bullet.scale = Vector2(1.0, 1.0)
	ice_bullet.modulate = Color(0.5, 0.9, 1.0)
	ice_bullet.movement_type = BulletData.MovementType.STRAIGHT
	ice_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	bullets["ice_bullet"] = ice_bullet
	
	var poison_bullet = BulletData.new("poison_bullet", 1900.0, 4.0, "res://assets/bullet/bullet.png")
	poison_bullet.bullet_name = "毒液子弹"
	poison_bullet.scale = Vector2(1.0, 1.0)
	poison_bullet.modulate = Color(0.4, 1.0, 0.3)
	poison_bullet.movement_type = BulletData.MovementType.STRAIGHT
	poison_bullet.movement_params = {
		"rotate_to_direction": true  # 朝向飞行方向
	}
	bullets["poison_bullet"] = poison_bullet

## 获取子弹数据
static func get_bullet(bullet_id: String) -> BulletData:
	if bullets.is_empty():
		initialize_bullets()
	return bullets.get(bullet_id, bullets.get("normal_bullet"))

## 获取所有子弹ID
static func get_all_bullet_ids() -> Array:
	if bullets.is_empty():
		initialize_bullets()
	return bullets.keys()

## 根据移动类型获取子弹列表
static func get_bullets_by_movement_type(movement_type: BulletData.MovementType) -> Array:
	if bullets.is_empty():
		initialize_bullets()
	
	var result = []
	for bullet_id in bullets.keys():
		var bullet = bullets[bullet_id]
		if bullet.movement_type == movement_type:
			result.append(bullet_id)
	return result
