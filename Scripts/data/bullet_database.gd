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
	bullets["normal_bullet"] = normal_bullet
	
	var fast_bullet = BulletData.new("fast_bullet", 3000.0, 2.5, "res://assets/bullet/bullet.png")
	fast_bullet.bullet_name = "高速子弹"
	fast_bullet.scale = Vector2(0.8, 0.8)
	fast_bullet.movement_type = BulletData.MovementType.STRAIGHT
	bullets["fast_bullet"] = fast_bullet
	
	var heavy_bullet = BulletData.new("heavy_bullet", 1500.0, 4.0, "res://assets/bullet/bullet_lightning.png")
	heavy_bullet.bullet_name = "重型子弹"
	heavy_bullet.scale = Vector2(1.0, 1.0)
	heavy_bullet.movement_type = BulletData.MovementType.STRAIGHT
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
	
	var homing_bullet = BulletData.new("homing_bullet", 1000.0, 8.0,"res://assets/weapon/bullet-missle.png")
	homing_bullet.bullet_name = "追踪子弹"
	homing_bullet.scale = Vector2(0.5, 0.5)
	#homing_bullet.modulate = Color(0.5, 0.8, 1.0)
	homing_bullet.movement_type = BulletData.MovementType.HOMING
	homing_bullet.movement_params = {
		"turn_speed": 8.0,        # 降低转向速度，让它转大弯
		"acceleration": 100.0,    # 增加加速度，越飞越快
		"max_speed": 1200.0,      # 稍微降低极速，让玩家看清轨迹
		"homing_delay": 0.2,      # 发射后 0.2秒内直飞，不追踪
		"wobble_amount": 15.0,    # 15度的左右摆动
		"wobble_frequency": 8.0   # 摆动频率
	}
	bullets["homing_bullet"] = homing_bullet
	
	var bounce_bullet = BulletData.new("bounce_bullet", 2000.0, 6.0, "res://assets/bullet/bullet.png")
	bounce_bullet.bullet_name = "弹跳子弹"
	bounce_bullet.scale = Vector2(1.0, 1.0)
	bounce_bullet.modulate = Color(0.8, 1.0, 0.5)
	bounce_bullet.movement_type = BulletData.MovementType.BOUNCE
	bounce_bullet.movement_params = {
		"bounce_count": 3,      # 最大弹跳次数
		"bounce_loss": 0.9,     # 每次弹跳速度保留比例
		"search_range": 300.0   # 弹跳目标搜索范围
	}
	bounce_bullet.destroy_on_hit = false  # 弹跳子弹不会立即销毁
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
	# 可配置火焰轨迹特效
	# fire_bullet.trail_effect_path = "res://scenes/effects/fire_trail.tscn"
	bullets["fire_bullet"] = fire_bullet
	
	var ice_bullet = BulletData.new("ice_bullet", 2000.0, 3.5, "res://assets/bullet/bullet_blue.png")
	ice_bullet.bullet_name = "冰霜子弹"
	ice_bullet.scale = Vector2(1.0, 1.0)
	ice_bullet.modulate = Color(0.5, 0.9, 1.0)
	ice_bullet.movement_type = BulletData.MovementType.STRAIGHT
	bullets["ice_bullet"] = ice_bullet
	
	var poison_bullet = BulletData.new("poison_bullet", 1900.0, 4.0, "res://assets/bullet/bullet.png")
	poison_bullet.bullet_name = "毒液子弹"
	poison_bullet.scale = Vector2(1.0, 1.0)
	poison_bullet.modulate = Color(0.4, 1.0, 0.3)
	poison_bullet.movement_type = BulletData.MovementType.STRAIGHT
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
