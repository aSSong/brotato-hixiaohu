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
			
			# 应用特殊效果（统一方法）
			if player_stats:
				# 吸血效果
				if player_stats.lifesteal_percent > 0:
					var player = get_tree().get_first_node_in_group("player")
					SpecialEffects.try_apply_status_effect(player_stats, null, "lifesteal", {
						"attacker": player,
						"damage_dealt": hurt,
						"percent": player_stats.lifesteal_percent
					})
				
				# 状态效果（使用统一方法）
				if player_stats.burn_chance > 0:
					SpecialEffects.try_apply_status_effect(player_stats, body, "burn", {
						"chance": player_stats.burn_chance,
						"tick_interval": 1.0,
						"damage": player_stats.burn_damage_per_second,
						"duration": 3.0
					})
				
				if player_stats.freeze_chance > 0:
					SpecialEffects.try_apply_status_effect(player_stats, body, "freeze", {
						"chance": player_stats.freeze_chance,
						"duration": 2.0
					})
				
				if player_stats.poison_chance > 0:
					SpecialEffects.try_apply_status_effect(player_stats, body, "poison", {
						"chance": player_stats.poison_chance,
						"tick_interval": 1.0,
						"damage": 5.0,
						"duration": 5.0
					})
	
	# 碰撞后销毁子弹
	queue_free()
