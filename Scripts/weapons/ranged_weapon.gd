extends BaseWeapon
class_name RangedWeapon

## 远程武器
## 发射子弹攻击敌人

@onready var shoot_pos: Marker2D = $shoot_pos
var bullet_scene = preload("res://scenes/bullets/bullet.tscn")

func _on_weapon_initialized() -> void:
	# 确保有射击位置节点
	if not shoot_pos:
		shoot_pos = Marker2D.new()
		shoot_pos.name = "shoot_pos"
		shoot_pos.position = Vector2(16.142859, 1.1428572)
		add_child(shoot_pos)

func _perform_attack() -> void:
	if attack_enemies.is_empty() or weapon_data == null or not shoot_pos:
		return
	
	var target_enemy = attack_enemies[0]
	if not is_instance_valid(target_enemy):
		return
	
	# 创建子弹
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	
	# 计算方向
	var direction = (target_enemy.global_position - shoot_pos.global_position).normalized()
	
	# 获取伤害值
	var damage = get_damage()
	
	# 发射子弹
	bullet.start(
		shoot_pos.global_position,
		direction,
		weapon_data.bullet_speed,
		damage
	)

