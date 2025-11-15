extends Area2D

## 敌人子弹脚本
## 只对玩家造成伤害，不伤害敌人

@export var speed := 400.0      # 子弹速度
@export var life_time := 3.0    # 最长存活时间（秒）
@export var damage := 10        # 伤害值
var hurt := 1
var dir: Vector2
var _velocity := Vector2.ZERO

## 子弹数据（可选，如果使用数据库）
var bullet_data: EnemyBulletData = null

## 穿透相关
var pierce_count: int = 0  # 剩余穿透次数
var hit_targets: Array = []  # 已命中的目标（用于穿透）

func start(pos: Vector2, _dir: Vector2, _speed: float, _hurt: int, _life_time: float = 3.0) -> void:
	global_position = pos
	dir = _dir
	speed = _speed
	hurt = _hurt
	life_time = _life_time
	_velocity = dir * speed
	get_tree().create_timer(life_time).timeout.connect(queue_free)

## 使用子弹数据初始化
func initialize_with_data(pos: Vector2, _dir: Vector2, data: EnemyBulletData) -> void:
	if data == null:
		push_error("[EnemyBullet] 子弹数据为空")
		return
	
	bullet_data = data
	global_position = pos
	dir = _dir
	speed = data.speed
	hurt = data.damage
	life_time = data.life_time
	pierce_count = data.pierce_count
	_velocity = dir * speed
	
	# 应用外观
	if has_node("AnimatedSprite2D"):
		var sprite = $AnimatedSprite2D
		if data.texture_path != "":
			var texture = load(data.texture_path)
			if texture:
				sprite.texture = texture
		sprite.scale = data.scale
	
	# 应用碰撞大小
	if has_node("CollisionShape2D"):
		var collision = $CollisionShape2D
		if collision.shape is CircleShape2D:
			collision.shape.radius = data.collision_radius
	
	get_tree().create_timer(life_time).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	# 只对玩家造成伤害
	if body.is_in_group("player"):
		# 检查是否已经命中过（穿透逻辑）
		if pierce_count > 0 and body in hit_targets:
			return
		
		# 对玩家造成伤害
		if body.has_method("player_hurt"):
			body.player_hurt(hurt)
		
		# 记录命中的目标
		if pierce_count > 0:
			hit_targets.append(body)
			pierce_count -= 1
			# 如果还有穿透次数，不销毁子弹
			if pierce_count > 0:
				return
		
		queue_free()
		return
	
	# 如果碰撞到其他物体（如墙壁），也销毁
	# 这里可以根据需要添加更多碰撞检测
