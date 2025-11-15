extends EnemyBehavior
class_name ShootingBehavior

## 射击技能行为
## 敌人在射程内时，定时向玩家发射子弹

## 配置参数（从config字典读取）
var shoot_range: float = 600.0        # 射击范围
var shoot_interval: float = 2.0       # 射击间隔（秒）
var bullet_speed: float = 400.0      # 子弹速度
var bullet_damage: int = 10           # 子弹伤害
var bullet_id: String = "basic"       # 子弹ID（从数据库获取）
var bullet_scene_path: String = ""   # 子弹场景路径（可选，优先使用）

## 射击相关
var shoot_timer: float = 0.0
var bullet_scene: PackedScene = null

## 射击位置偏移（相对于敌人中心）
var shoot_offset: Vector2 = Vector2(0, -30)

func _on_initialize() -> void:
	# 从配置中读取参数
	shoot_range = config.get("shoot_range", 600.0)
	shoot_interval = config.get("shoot_interval", 2.0)
	bullet_speed = config.get("bullet_speed", 400.0)
	bullet_damage = config.get("bullet_damage", 10)
	bullet_id = config.get("bullet_id", "basic")
	bullet_scene_path = config.get("bullet_scene_path", "")
	
	# 加载子弹场景
	if bullet_scene_path != "":
		bullet_scene = load(bullet_scene_path) as PackedScene
	else:
		# 使用默认的敌人子弹场景
		bullet_scene = load("res://scenes/bullets/enemy_bullet.tscn") as PackedScene
	
	if not bullet_scene:
		push_error("[ShootingBehavior] 无法加载子弹场景")
	
	shoot_timer = 0.0

func _on_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return
	
	shoot_timer -= delta
	
	# 检查是否在射程内
	var player = get_player()
	if not player:
		return
	
	var distance = get_distance_to_player()
	if distance <= shoot_range:
		# 在射程内，检查是否可以射击
		if shoot_timer <= 0:
			_shoot_at_player()

func _shoot_at_player() -> void:
	if not bullet_scene or not enemy:
		return
	
	var player = get_player()
	if not player:
		return
	
	# 创建子弹实例
	var bullet = bullet_scene.instantiate()
	if not bullet:
		push_error("[ShootingBehavior] 无法实例化子弹")
		return
	
	# 添加到场景树
	get_tree().root.add_child(bullet)
	
	# 计算射击位置和方向
	var shoot_pos = enemy.global_position + shoot_offset
	var direction = get_direction_to_player()
	
	# 初始化子弹
	if bullet.has_method("start"):
		# 使用start方法（兼容旧接口）
		bullet.start(shoot_pos, direction, bullet_speed, bullet_damage)
	elif bullet.has_method("initialize_with_data"):
		# 使用子弹数据初始化（推荐）
		var bullet_data = EnemyBulletDatabase.get_bullet_data(bullet_id)
		if bullet_data:
			# 覆盖配置的伤害和速度
			bullet_data.damage = bullet_damage
			bullet_data.speed = bullet_speed
			bullet.initialize_with_data(shoot_pos, direction, bullet_data)
		else:
			# 回退到start方法
			bullet.start(shoot_pos, direction, bullet_speed, bullet_damage)
	else:
		push_error("[ShootingBehavior] 子弹没有start或initialize_with_data方法")
		bullet.queue_free()
		return
	
	# 重置射击计时器
	shoot_timer = shoot_interval
	
	print("[ShootingBehavior] 射击 | 位置:", shoot_pos, " 方向:", direction, " 伤害:", bullet_damage)

