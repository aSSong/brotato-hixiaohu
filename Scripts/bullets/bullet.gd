extends Area2D

@export var speed := 400.0      # 子弹速度
@export var life_time := 3.0    # 最长存活时间（秒）
@export var damage := 10        # 伤害值
var hurt := 1
var dir: Vector2
var _velocity := Vector2.ZERO
var is_critical: bool = false  # 是否暴击
var player_stats: CombatStats = null  # 玩家属性（用于特效）

func start(pos: Vector2, _dir: Vector2, _speed: float, _hurt: int, _is_critical: bool = false, _player_stats: CombatStats = null) -> void:
	global_position = pos
	dir = _dir
	speed = _speed
	hurt = _hurt
	is_critical = _is_critical
	player_stats = _player_stats
	_velocity = dir * speed
	
	# 如果是暴击，可以改变子弹颜色或大小
	if is_critical:
		modulate = Color(1.5, 1.5, 1.5)  # 变亮
		scale *= 1.2
		
	get_tree().create_timer(life_time).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta


func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	#print("Collided with: ", body.name, " (type: ", body.get_class(), ")")
	if body.is_in_group("enemy"):
		if body.has_method("enemy_hurt"):
			body.enemy_hurt(hurt, is_critical)
			
			# 命中后的特效处理（吸血、燃烧等）
			if player_stats:
				# 吸血效果
				if player_stats.lifesteal_percent > 0:
					var player = get_tree().get_first_node_in_group("player")
					SpecialEffects.apply_lifesteal(player, hurt, player_stats.lifesteal_percent)
				
				# 状态效果
				SpecialEffects.try_apply_burn(player_stats, body)
				SpecialEffects.try_apply_freeze(player_stats, body)
				SpecialEffects.try_apply_poison(player_stats, body)
	
		#if body is TileMapLayer:
		#var tile_data := body.get_cell_tile_data(0, body.local_to_map(body.to_local(global_position)))
		#if tile_data and tile_data.get_custom_data("is_wall"):
			#queue_free()
	## 如果还有静态物体（StaticBody2D）做的箱子、柱子，也可一起判断
	#elif body is StaticBody2D:
		#queue_free()
	queue_free()
	pass # Replace with function body.
