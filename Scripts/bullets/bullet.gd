extends Area2D

@export var speed := 400.0      # 子弹速度
@export var life_time := 3.0    # 最长存活时间（秒）
@export var damage := 10        # 伤害值
var hurt := 1
var dir: Vector2
var _velocity := Vector2.ZERO
var is_critical: bool = false  # 是否暴击
var player_stats: CombatStats = null  # 玩家属性（用于特效）
var weapon_data: WeaponData = null  # 武器数据（用于特殊效果）
var is_visual_only: bool = false  # 客户端视觉子弹（碰撞时只消失，不处理伤害）
var owner_peer_id: int = 0

func start(pos: Vector2, _dir: Vector2, _speed: float, _hurt: int, _is_critical: bool = false, _player_stats: CombatStats = null, _weapon_data: WeaponData = null, _owner_peer_id: int = 0) -> void:
	global_position = pos
	dir = _dir
	speed = _speed
	hurt = _hurt
	is_critical = _is_critical
	player_stats = _player_stats
	weapon_data = _weapon_data
	owner_peer_id = _owner_peer_id

	_velocity = dir * speed
	
	# 如果是暴击，可以改变子弹颜色或大小
	if is_critical:
		modulate = Color(1.5, 1.5, 1.5)  # 变亮
		scale *= 1.2
		
	get_tree().create_timer(life_time).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta


func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if GameMain.current_mode_id == "online":
		_handle_collision_online(body)
	else:
		_handle_collision_offline(body)


## 联网模式：使用 NetworkPlayerManager 统一处理碰撞
func _handle_collision_online(body: Node2D) -> void:
	var result = NetworkPlayerManager.handle_bullet_collision(owner_peer_id, body, hurt, is_critical, is_visual_only)
	
	match result:
		NetworkPlayerManager.BulletHitResult.IGNORE:
			# 忽略碰撞，继续飞行
			return
		
		NetworkPlayerManager.BulletHitResult.DESTROY:
			# 销毁子弹（视觉效果或无效目标）
			queue_free()
			return
		
		NetworkPlayerManager.BulletHitResult.HIT_PLAYER:
			# 命中玩家，伤害已处理，应用武器特效
			_apply_weapon_effects(body)
			queue_free()
			return
		
		NetworkPlayerManager.BulletHitResult.HIT_ENEMY:
			# 命中敌人，处理伤害和特效
			_deal_damage_to_enemy(body)
			queue_free()
			return
	
	# 默认销毁
	queue_free()


## 单机模式：直接处理敌人碰撞
func _handle_collision_offline(body: Node2D) -> void:
	# 忽略玩家（单机模式下不应碰到玩家就消失）
	if body.is_in_group("player"):
		return
	
	if body.is_in_group("enemy"):
		_deal_damage_to_enemy(body)
	
	# 碰撞后销毁子弹
	queue_free()


## 处理敌人伤害
func _deal_damage_to_enemy(enemy: Node2D) -> void:
	if enemy.has_method("enemy_hurt"):
		enemy.enemy_hurt(hurt, is_critical, owner_peer_id)
	
	# 应用武器特效
	_apply_weapon_effects(enemy)


## 应用武器特效到目标（敌人或玩家）
func _apply_weapon_effects(target: Node2D) -> void:
	if not player_stats:
		return
	
	# 优先使用weapon_data中的特殊效果配置
	var effect_configs: Array = []
	if weapon_data and weapon_data.special_effects:
		if weapon_data.special_effects is Dictionary and weapon_data.special_effects.has("effects"):
			effect_configs = weapon_data.special_effects.get("effects", [])
	
	# 应用每个效果
	for effect_config in effect_configs:
		if not effect_config is Dictionary:
			continue
		
		var effect_type = effect_config.get("type", "")
		var effect_params = effect_config.get("params", {})
		
		# 如果是吸血效果，需要传递伤害和攻击者
		if effect_type == "lifesteal":
			var attacker = NetworkPlayerManager.get_player_by_peer_id(owner_peer_id)
			if not attacker:
				attacker = get_tree().get_first_node_in_group("player")
			effect_params["damage_dealt"] = hurt
			effect_params["attacker"] = attacker
		
		# 应用效果
		SpecialEffects.try_apply_status_effect(player_stats, target, effect_type, effect_params)
	
	# 如果没有weapon_data配置，使用旧的player_stats逻辑（兼容性）
	if effect_configs.is_empty():
		# 吸血效果
		if player_stats.lifesteal_percent > 0:
			var attacker = NetworkPlayerManager.get_player_by_peer_id(owner_peer_id)
			if not attacker:
				attacker = get_tree().get_first_node_in_group("player")
			SpecialEffects.try_apply_status_effect(player_stats, null, "lifesteal", {
				"attacker": attacker,
				"damage_dealt": hurt,
				"percent": player_stats.lifesteal_percent
			})
		
		# 状态效果（使用统一方法）
		if player_stats.burn_chance > 0:
			SpecialEffects.try_apply_status_effect(player_stats, target, "burn", {
				"chance": player_stats.burn_chance,
				"tick_interval": 1.0,
				"damage": player_stats.burn_damage_per_second,
				"duration": 3.0
			})
		
		if player_stats.freeze_chance > 0:
			SpecialEffects.try_apply_status_effect(player_stats, target, "freeze", {
				"chance": player_stats.freeze_chance,
				"duration": 2.0
			})
		
		if player_stats.poison_chance > 0:
			SpecialEffects.try_apply_status_effect(player_stats, target, "poison", {
				"chance": player_stats.poison_chance,
				"tick_interval": 1.0,
				"damage": 5.0,
				"duration": 5.0
			})
