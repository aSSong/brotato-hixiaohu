extends Node
class_name EnemyBulletDatabase

## 敌人子弹数据库
## 预定义多种子弹类型

static var bullets: Dictionary = {}

## 初始化所有子弹
static func initialize_bullets() -> void:
	if not bullets.is_empty():
		return
	
	# 基础子弹 - 标准属性
	var basic_bullet = EnemyBulletData.new(
		"基础子弹",
		400.0,  # speed
		10,     # damage
		3.0,    # life_time
		"res://assets/bullet/bullet.png"
	)
	basic_bullet.description = "标准子弹，平衡的属性"
	bullets["basic"] = basic_bullet
	
	# 快速子弹 - 高速度，低伤害
	var fast_bullet = EnemyBulletData.new(
		"快速子弹",
		600.0,  # speed（更快）
		5,      # damage（更低）
		2.5,    # life_time
		"res://assets/bullet/bullet.png"
	)
	fast_bullet.description = "快速但伤害较低的子弹"
	bullets["fast"] = fast_bullet
	
	# 重型子弹 - 低速度，高伤害
	var heavy_bullet = EnemyBulletData.new(
		"重型子弹",
		250.0,  # speed（更慢）
		25,     # damage（更高）
		4.0,    # life_time
		"res://assets/bullet/bullet.png"
	)
	heavy_bullet.description = "缓慢但伤害很高的子弹"
	heavy_bullet.scale = Vector2(0.6, 0.6)  # 更大
	bullets["heavy"] = heavy_bullet
	
	# 穿透子弹 - 可以穿透多个敌人
	var pierce_bullet = EnemyBulletData.new(
		"穿透子弹",
		450.0,  # speed
		15,     # damage
		3.5,    # life_time
		"res://assets/bullet/bullet.png"
	)
	pierce_bullet.description = "可以穿透敌人的子弹"
	pierce_bullet.pierce_count = 2  # 穿透2个敌人
	bullets["pierce"] = pierce_bullet

## 获取子弹数据
static func get_bullet_data(bullet_id: String) -> EnemyBulletData:
	if bullets.is_empty():
		initialize_bullets()
	return bullets.get(bullet_id, bullets["basic"])

## 获取所有子弹ID
static func get_all_bullet_ids() -> Array:
	if bullets.is_empty():
		initialize_bullets()
	return bullets.keys()

