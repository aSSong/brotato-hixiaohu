extends BaseWeapon
class_name RangedWeapon

## 远程武器
## 发射子弹攻击敌人

@onready var shoot_pos: Marker2D = $shoot_pos
var bullet_scene = preload("res://scenes/bullets/bullet.tscn")

func _on_weapon_initialized() -> void:
	# 确保有射击位置节点
	# 如果@onready初始化失败，手动获取节点
	if not shoot_pos:
		shoot_pos = get_node_or_null("shoot_pos")
		# 如果节点不存在，创建一个新的
		if not shoot_pos:
			shoot_pos = Marker2D.new()
			shoot_pos.name = "shoot_pos"
			shoot_pos.position = Vector2(16.142859, 1.1428572)
			add_child(shoot_pos)

func _perform_attack() -> void:
	if attack_enemies.is_empty() or weapon_data == null or not shoot_pos:
		if GameMain.current_mode_id == "online" and NetworkManager.is_server():
			print("[RangedWeapon] 攻击条件不满足: enemies=%d, weapon_data=%s, shoot_pos=%s" % [
				attack_enemies.size(), weapon_data != null, shoot_pos != null
			])
		return
	
	var target_enemy = attack_enemies[0]
	if not is_instance_valid(target_enemy):
		if GameMain.current_mode_id == "online" and NetworkManager.is_server():
			print("[RangedWeapon] 目标无效，跳过攻击")
		return
	
	# 计算方向
	var direction = (target_enemy.global_position - shoot_pos.global_position).normalized()
	
	# 获取伤害值
	var damage = get_damage()
	var is_critical = false
	
	# 暴击判定
	if player_stats:
		is_critical = DamageCalculator.roll_critical(player_stats)
		if is_critical:
			damage = DamageCalculator.apply_critical_multiplier(damage, player_stats)
	
	# 联网模式：通过 NetworkPlayerManager 广播
	if GameMain.current_mode_id == "online":
		NetworkPlayerManager.broadcast_spawn_bullet(
			shoot_pos.global_position,
			direction,
			weapon_data.bullet_speed,
			damage,
			is_critical,
			owner_peer_id
		)
	else:
		_spawn_bullet_local(shoot_pos.global_position, direction, damage, is_critical)


## 本地创建子弹（单机模式使用）
func _spawn_bullet_local(start_pos: Vector2, direction: Vector2, damage: int, is_critical: bool) -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	bullet.start(
		start_pos,
		direction,
		weapon_data.bullet_speed,
		damage,
		is_critical,
		player_stats,
		weapon_data,
		owner_peer_id
	)
