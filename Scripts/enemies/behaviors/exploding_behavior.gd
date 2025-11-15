extends EnemyBehavior
class_name ExplodingBehavior

## 自爆技能行为
## 根据触发条件（低血量/距离玩家/死亡时）触发爆炸

## 触发条件枚举
enum ExplodeTrigger {
	LOW_HP,      # 低血量时
	DISTANCE,    # 距离玩家一定距离内
	ON_DEATH     # 死亡时
}

var trigger_condition: ExplodeTrigger = ExplodeTrigger.LOW_HP

## 配置参数（从config字典读取）
var explosion_range: float = 200.0     # 爆炸范围
var explosion_damage: int = 30         # 爆炸伤害
var low_hp_threshold: float = 0.3      # 低血量阈值（百分比，如0.3表示30%）
var trigger_distance: float = 150.0    # 触发距离（用于DISTANCE条件）
var has_exploded: bool = false         # 是否已经爆炸过（防止重复）

## 爆炸效果场景（可选）
var explosion_effect_scene: PackedScene = null
var explosion_effect_path: String = ""

func _on_initialize() -> void:
	# 从配置中读取参数
	explosion_range = config.get("explosion_range", 200.0)
	explosion_damage = config.get("explosion_damage", 30)
	low_hp_threshold = config.get("low_hp_threshold", 0.3)
	trigger_distance = config.get("trigger_distance", 150.0)
	explosion_effect_path = config.get("explosion_effect_path", "")
	
	# 解析触发条件
	var trigger_str = config.get("trigger_condition", "low_hp")
	match trigger_str:
		"low_hp", "LOW_HP":
			trigger_condition = ExplodeTrigger.LOW_HP
		"distance", "DISTANCE":
			trigger_condition = ExplodeTrigger.DISTANCE
		"on_death", "ON_DEATH":
			trigger_condition = ExplodeTrigger.ON_DEATH
		_:
			trigger_condition = ExplodeTrigger.LOW_HP
	
	# 加载爆炸效果场景
	if explosion_effect_path != "":
		explosion_effect_scene = load(explosion_effect_path) as PackedScene
	
	has_exploded = false

func _on_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return
	
	if has_exploded:
		return
	
	# 根据触发条件检查
	match trigger_condition:
		ExplodeTrigger.LOW_HP:
			_check_low_hp_trigger()
		
		ExplodeTrigger.DISTANCE:
			_check_distance_trigger()
		
		ExplodeTrigger.ON_DEATH:
			# 死亡时触发在enemy_dead中处理
			pass

## 检查低血量触发
func _check_low_hp_trigger() -> void:
	if not enemy:
		return
	
	var hp_percentage = float(enemy.enemyHP) / float(enemy.max_enemyHP)
	if hp_percentage <= low_hp_threshold:
		_explode()

## 检查距离触发
func _check_distance_trigger() -> void:
	var distance = get_distance_to_player()
	if distance <= trigger_distance:
		_explode()

## 执行爆炸
func _explode() -> void:
	if has_exploded or not enemy:
		return
	
	has_exploded = true
	var explode_pos = enemy.global_position
	
	print("[ExplodingBehavior] 触发爆炸 | 位置:", explode_pos, " 范围:", explosion_range, " 伤害:", explosion_damage)
	
	# 创建爆炸效果
	_create_explosion_effect(explode_pos)
	
	# 对范围内玩家造成伤害
	_damage_players_in_range(explode_pos)
	
	# 如果触发条件是死亡时，不在这里杀死敌人
	# 否则，爆炸后敌人死亡
	if trigger_condition != ExplodeTrigger.ON_DEATH:
		if enemy and not enemy.is_dead:
			enemy.enemy_dead()

## 创建爆炸效果
func _create_explosion_effect(pos: Vector2) -> void:
	if explosion_effect_scene:
		var effect = explosion_effect_scene.instantiate()
		if effect:
			effect.global_position = pos
			get_tree().root.add_child(effect)
	else:
		# 使用默认的死亡动画作为爆炸效果
		if GameMain.animation_scene_obj:
			GameMain.animation_scene_obj.run_animation({
				"ani_name": "enemies_dead",
				"position": pos,
				"scale": Vector2(1.5, 1.5)  # 稍大的效果
			})
	
	# 震动屏幕
	CameraShake.shake(0.3, 15.0)

## 对范围内玩家造成伤害
func _damage_players_in_range(center: Vector2) -> void:
	var player = get_player()
	if not player:
		return
	
	var distance = center.distance_to(player.global_position)
	if distance <= explosion_range:
		# 玩家在爆炸范围内
		if player.has_method("player_hurt"):
			player.player_hurt(explosion_damage)
			print("[ExplodingBehavior] 爆炸命中玩家 | 距离:", distance, " 伤害:", explosion_damage)
		
		# 显示伤害跳字
		FloatingText.create_floating_text(
			player.global_position + Vector2(0, -30),
			"-" + str(explosion_damage),
			Color(1.0, 0.5, 0.0)  # 橙色伤害数字
		)

## 敌人死亡时调用（用于ON_DEATH触发条件）
func on_enemy_death() -> void:
	if trigger_condition == ExplodeTrigger.ON_DEATH and not has_exploded:
		_explode()

