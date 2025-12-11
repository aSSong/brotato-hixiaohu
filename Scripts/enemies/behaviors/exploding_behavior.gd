extends EnemyBehavior
class_name ExplodingBehavior

## 自爆技能行为
## 根据触发条件（低血量/距离玩家/死亡时）触发爆炸
## 触发后会进入倒数状态，显示范围警示，敌人闪烁，倒数结束后爆炸

## 状态枚举
enum ExplodeState {
	IDLE,       # 待机状态
	COUNTDOWN,  # 倒数状态
	EXPLODED    # 已爆炸
}

## 触发条件枚举
enum ExplodeTrigger {
	LOW_HP,      # 低血量时
	DISTANCE,    # 距离玩家一定距离内
	ON_DEATH     # 死亡时
}

var state: ExplodeState = ExplodeState.IDLE
var trigger_condition: ExplodeTrigger = ExplodeTrigger.LOW_HP

## 配置参数（从config字典读取）
var explosion_range: float = 200.0     # 爆炸范围
var explosion_damage: int = 30         # 爆炸伤害
var low_hp_threshold: float = 0.3      # 低血量阈值（百分比，如0.3表示30%）
var trigger_distance: float = 150.0    # 触发距离（用于DISTANCE条件）
var countdown_duration: float = 3.0    # 倒数时长（秒）

## 倒数相关
var countdown_timer: float = 0.0
var is_invincible: bool = false  # 倒数期间无敌

## 范围指示器
var range_indicator: Sprite2D = null
## 预加载的范围圈纹理（与grave_rescue_manager共用资源）
static var _range_circle_texture = preload("res://assets/skill_indicator/explosion_range_circle.png")

## 闪烁相关
var flash_timer: float = 0.0
var flash_interval: float = 0.1  # 闪烁间隔（秒）
var is_flashing: bool = false

## 爆炸效果场景
var explosion_effect_scene: PackedScene = null
var explosion_effect_path: String = "res://scenes/effects/meteor_explosion.tscn"

func _on_initialize() -> void:
	# 从配置中读取参数
	explosion_range = config.get("explosion_range", 200.0)
	explosion_damage = config.get("explosion_damage", 30)
	low_hp_threshold = config.get("low_hp_threshold", 0.3)
	trigger_distance = config.get("trigger_distance", 150.0)
	countdown_duration = config.get("countdown_duration", 3.0)
	explosion_effect_path = config.get("explosion_effect_path", "res://scenes/effects/meteor_explosion.tscn")
	
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
	
	state = ExplodeState.IDLE
	countdown_timer = 0.0
	is_invincible = false
	
	# 延迟创建范围指示器（确保enemy已经添加到场景树）
	call_deferred("_create_range_indicator")

func _on_update(delta: float) -> void:
	if not enemy or enemy.is_dead:
		return
	
	match state:
		ExplodeState.IDLE:
			# 根据触发条件检查
			match trigger_condition:
				ExplodeTrigger.LOW_HP:
					_check_low_hp_trigger()
				
				ExplodeTrigger.DISTANCE:
					_check_distance_trigger()
				
				ExplodeTrigger.ON_DEATH:
					# 死亡时触发在enemy_dead中处理
					pass
		
		ExplodeState.COUNTDOWN:
			_update_countdown(delta)
		
		ExplodeState.EXPLODED:
			pass  # 已爆炸，什么都不做

## 检查低血量触发
func _check_low_hp_trigger() -> void:
	if not enemy:
		return
	
	var hp_percentage = float(enemy.enemyHP) / float(enemy.max_enemyHP)
	if hp_percentage <= low_hp_threshold:
		_start_countdown()

## 检查距离触发
func _check_distance_trigger() -> void:
	var distance = get_distance_to_player()
	if distance <= trigger_distance:
		_start_countdown()

## 开始倒数
func _start_countdown() -> void:
	if state != ExplodeState.IDLE or not enemy:
		return
	
	state = ExplodeState.COUNTDOWN
	countdown_timer = countdown_duration
	is_invincible = true  # 进入无敌状态
	is_flashing = true  # 立即开始闪烁
	flash_timer = 0.0
	
	# 显示范围指示器
	_show_range_indicator()
	
	# 立即更新闪烁效果
	_update_flash_effect()
	
	# 阻止敌人死亡（通过设置一个标记，在Enemy类中检查）
	# 注意：我们需要在Enemy类中添加对is_invincible的检查
	if enemy.has_method("set_invincible"):
		enemy.set_invincible(true)
	
	# 播放自爆准备动画
	enemy.play_animation("skill_prepare")
	enemy.play_skill_animation("explode_countdown")
	
	print("[ExplodingBehavior] 开始倒数 | 时长:", countdown_duration, "秒")

## 更新倒数状态
func _update_countdown(delta: float) -> void:
	if not enemy:
		return
	
	countdown_timer -= delta
	
	# 更新范围指示器位置（跟随敌人）
	if range_indicator:
		range_indicator.global_position = enemy.global_position
	
	# 更新闪烁效果
	flash_timer += delta
	if flash_timer >= flash_interval:
		flash_timer = 0.0
		is_flashing = !is_flashing
		_update_flash_effect()
	
	# 检查倒数是否结束
	if countdown_timer <= 0:
		_explode()

## 更新闪烁效果
func _update_flash_effect() -> void:
	if not enemy or not enemy.has_node("AnimatedSprite2D"):
		return
	
	var sprite = enemy.get_node("AnimatedSprite2D")
	if is_flashing:
		# 黄色闪烁（使用flash_opacity参数）
		sprite.material.set_shader_parameter("flash_color",Color(0.826, 0.766, 0.0, 1.0) )
		sprite.material.set_shader_parameter("flash_opacity", 1.0)
	else:
		# 恢复正常
		sprite.material.set_shader_parameter("flash_color",Color(1.0, 1.0, 1.0, 1.0) )
		sprite.material.set_shader_parameter("flash_opacity", 0.0)

## 执行爆炸
func _explode() -> void:
	if state == ExplodeState.EXPLODED or not enemy:
		return
	
	state = ExplodeState.EXPLODED
	is_invincible = false
	
	# 恢复闪烁效果
	if enemy.has_node("AnimatedSprite2D"):
		var sprite = enemy.get_node("AnimatedSprite2D")
		sprite.modulate = Color.WHITE
	
	# 隐藏范围指示器
	_hide_range_indicator()
	
	var explode_pos = enemy.global_position
	
	print("[ExplodingBehavior] 爆炸！| 位置:", explode_pos, " 范围:", explosion_range, " 伤害:", explosion_damage)
	
	# 创建爆炸效果
	_create_explosion_effect(explode_pos)
	
	# 对范围内玩家造成伤害
	_damage_players_in_range(explode_pos)
	
	# 如果触发条件是死亡时，不在这里杀死敌人
	# 否则，爆炸后敌人死亡
	if trigger_condition != ExplodeTrigger.ON_DEATH:
		if enemy and not enemy.is_dead:
			# 取消无敌状态
			if enemy.has_method("set_invincible"):
				enemy.set_invincible(false)
			enemy.enemy_dead()

## 创建范围指示器节点（使用预加载的纹理，与grave_rescue_manager一致）
func _create_range_indicator() -> void:
	if range_indicator:
		return
	
	range_indicator = Sprite2D.new()
	range_indicator.texture = _range_circle_texture
	
	# 根据explosion_range调整缩放（与grave_rescue_manager相同的计算方式）
	var target_diameter = explosion_range * 2
	var texture_size = _range_circle_texture.get_size().x  # 假设图片是正方形
	if texture_size > 0:
		range_indicator.scale = Vector2.ONE * (target_diameter / texture_size)
	
	range_indicator.visible = false
	range_indicator.z_index = 1  # 在敌人下方
	range_indicator.modulate = Color(1.0, 0.0, 0.0, 0.5)  # 红色，50%透明度
	
	# 添加到场景树（作为敌人的兄弟节点，这样不会随敌人旋转）
	if enemy and enemy.get_parent():
		enemy.get_parent().add_child(range_indicator)
	else:
		# 如果还没有父节点，延迟添加
		call_deferred("_add_range_indicator_to_scene")

## 延迟添加范围指示器到场景
func _add_range_indicator_to_scene() -> void:
	if not range_indicator:
		return
	
	if enemy and enemy.get_parent():
		enemy.get_parent().add_child(range_indicator)
	else:
		get_tree().root.add_child(range_indicator)

## 显示范围指示器
func _show_range_indicator() -> void:
	if range_indicator:
		range_indicator.visible = true
		if enemy:
			range_indicator.global_position = enemy.global_position

## 隐藏范围指示器
func _hide_range_indicator() -> void:
	if range_indicator:
		range_indicator.visible = false

## 创建爆炸效果
func _create_explosion_effect(pos: Vector2) -> void:
	# 使用统一的特效管理器
	CombatEffectManager.play_enemy_death(pos, 1.5)
	
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
	if trigger_condition == ExplodeTrigger.ON_DEATH and state == ExplodeState.IDLE:
		_start_countdown()

## 清理资源
func _exit_tree() -> void:
	if range_indicator and is_instance_valid(range_indicator):
		range_indicator.queue_free()

## 检查敌人是否在倒数状态（供Enemy类查询）
func is_in_countdown() -> bool:
	return state == ExplodeState.COUNTDOWN

## 检查敌人是否无敌（供Enemy类查询）
func is_enemy_invincible() -> bool:
	return is_invincible
