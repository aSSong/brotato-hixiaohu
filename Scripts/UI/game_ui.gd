extends CanvasLayer

## 游戏内HUD界面
## 负责显示玩家状态、资源、波次信息等

# UI组件引用
@onready var gold_counter: ResourceCounter = $gold_counter
@onready var master_key_counter: ResourceCounter = $master_key_counter
@onready var hp_value_bar: ProgressBar = %hp_value_bar
@onready var exp_value_bar: ProgressBar = %exp_value_bar
@onready var skill_icon: Control = %SkillIcon
@onready var wave_label: Label = %WaveLabel
@onready var kpi_label: Label = $KPI
@onready var player_stats_info: PlayerStatsInfo = $PlayerStatsInfo
@onready var damage_flash: DamageFlash = %DamageFlash
@onready var warning_ui: Control = $WarningUi
@onready var warning_animation: AnimationPlayer = $WarningUi/AnimationPlayer
@onready var boss_bar_container: VBoxContainer = $BOSSbar_root/VBoxContainer

## BOSS HP Bar 场景
const BOSS_HP_BAR_SCENE = preload("res://scenes/UI/components/BOSS_HPbar.tscn")

# 内部引用
var hp_label: Label = null  # HP标签
var player_ref: CharacterBody2D = null  # 玩家引用
var wave_manager_ref = null  # 波次管理器引用
var current_mode: BaseGameMode = null  # 当前游戏模式

func _ready() -> void:
	# 获取当前游戏模式
	_setup_game_mode()
	
	# 连接信号（检查是否已连接，防止重复连接）
	if not GameMain.gold_changed.is_connected(_on_gold_changed):
		GameMain.gold_changed.connect(_on_gold_changed)
	if not GameMain.master_key_changed.is_connected(_on_master_key_changed):
		GameMain.master_key_changed.connect(_on_master_key_changed)
	
	# 初始化显示
	if gold_counter:
		gold_counter.set_value(GameMain.gold, 0)
	if master_key_counter:
		master_key_counter.set_value(GameMain.master_key, 0)
		
	# 默认隐藏属性面板（可选）
	if player_stats_info:
		player_stats_info.visible = false
	
	# 初始化各个子系统
	_setup_skill_icon()
	_setup_hp_display()
	_setup_wave_display()
	
	# 初始化 KPI 显示
	_update_kpi_display()

## 设置游戏模式
func _setup_game_mode() -> void:
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"
	
	current_mode = ModeRegistry.get_mode(mode_id)
	if not current_mode:
		push_error("[GameUI] 无法获取游戏模式: %s" % mode_id)

## 设置技能图标
func _setup_skill_icon() -> void:
	if not skill_icon:
		return
	
	# 等待玩家加载完成
	await get_tree().create_timer(0.2).timeout
	
	# 获取玩家和职业数据
	var player = get_tree().get_first_node_in_group("player")
	if player and player.current_class:
		if skill_icon.has_method("set_skill_data"):
			skill_icon.set_skill_data(player.current_class)

## 金币变化回调
func _on_gold_changed(new_amount: int, change: int) -> void:
	if gold_counter:
		gold_counter.set_value(new_amount, change)
	
	# 如果是钥匙胜利条件，更新 KPI
	if current_mode and current_mode.victory_condition_type == "keys":
		_update_kpi_display()

## 设置HP显示
func _setup_hp_display() -> void:
	if not hp_value_bar:
		return
	
	# 查找HP标签（hp_value_bar的子节点）
	for child in hp_value_bar.get_children():
		if child is Label:
			hp_label = child
			break
	
	# 等待玩家加载完成
	await get_tree().create_timer(0.2).timeout
	
	# 获取玩家引用
	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		# 连接玩家血量变化信号
		if not player_ref.hp_changed.is_connected(_on_player_hp_changed):
			player_ref.hp_changed.connect(_on_player_hp_changed)
		
		# 初始化HP显示
		_on_player_hp_changed(player_ref.now_hp, player_ref.max_hp)

## 玩家血量变化回调
func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	if not hp_value_bar:
		return
	
	# 检测是否受伤（血量减少）- 触发闪红效果
	var old_hp = hp_value_bar.value
	if current_hp < old_hp and damage_flash:
		damage_flash.flash()
	
	# 更新ProgressBar
	hp_value_bar.max_value = max_hp
	hp_value_bar.value = current_hp
	
	# 更新Label文本
	if hp_label:
		hp_label.text = "%d / %d" % [current_hp, max_hp]

## 设置波次显示
func _setup_wave_display() -> void:
	if not wave_label:
		return
	
	# 等待场景加载完成
	await get_tree().create_timer(0.3).timeout
	
	# 查找波次管理器
	var now_enemies = get_tree().get_first_node_in_group("enemy_spawner")
	if now_enemies and now_enemies.has_method("get_wave_manager"):
		wave_manager_ref = now_enemies.get_wave_manager()
	elif now_enemies:
		# 尝试直接访问wave_manager
		if "wave_manager" in now_enemies:
			wave_manager_ref = now_enemies.wave_manager
	
	# 如果没找到，尝试在场景中查找WaveManager节点
	if wave_manager_ref == null:
		wave_manager_ref = get_tree().get_first_node_in_group("wave_manager")
	
	if wave_manager_ref:
		# 连接信号
		if wave_manager_ref.has_signal("enemy_killed"):
			if not wave_manager_ref.enemy_killed.is_connected(_on_wave_enemy_killed):
				wave_manager_ref.enemy_killed.connect(_on_wave_enemy_killed)
		if wave_manager_ref.has_signal("wave_started"):
			if not wave_manager_ref.wave_started.is_connected(_on_wave_started):
				wave_manager_ref.wave_started.connect(_on_wave_started)
		if wave_manager_ref.has_signal("wave_ended"):
			if not wave_manager_ref.wave_ended.is_connected(_on_wave_ended):
				wave_manager_ref.wave_ended.connect(_on_wave_ended)
		
		# 连接敌人生成信号（用于 BOSS 血条）
		if wave_manager_ref.has_signal("enemy_spawned"):
			if not wave_manager_ref.enemy_spawned.is_connected(_on_enemy_spawned):
				wave_manager_ref.enemy_spawned.connect(_on_enemy_spawned)
		
		# 初始化显示
		_update_wave_display()
	else:
		# 如果找不到，定期查找
		_find_wave_manager_periodically()

## 定期查找波次管理器
func _find_wave_manager_periodically() -> void:
	var attempts = 0
	while wave_manager_ref == null and attempts < 10:
		await get_tree().create_timer(0.5).timeout
		var now_enemies = get_tree().get_first_node_in_group("enemy_spawner")
		if now_enemies and "wave_manager" in now_enemies:
			wave_manager_ref = now_enemies.wave_manager
			if wave_manager_ref:
				# 连接信号
				if wave_manager_ref.has_signal("enemy_killed"):
					if not wave_manager_ref.enemy_killed.is_connected(_on_wave_enemy_killed):
						wave_manager_ref.enemy_killed.connect(_on_wave_enemy_killed)
				if wave_manager_ref.has_signal("wave_started"):
					if not wave_manager_ref.wave_started.is_connected(_on_wave_started):
						wave_manager_ref.wave_started.connect(_on_wave_started)
				if wave_manager_ref.has_signal("wave_ended"):
					if not wave_manager_ref.wave_ended.is_connected(_on_wave_ended):
						wave_manager_ref.wave_ended.connect(_on_wave_ended)
				# 连接敌人生成信号（用于 BOSS 血条）
				if wave_manager_ref.has_signal("enemy_spawned"):
					if not wave_manager_ref.enemy_spawned.is_connected(_on_enemy_spawned):
						wave_manager_ref.enemy_spawned.connect(_on_enemy_spawned)
				_update_wave_display()
				return
		attempts += 1

## 波次开始回调
func _on_wave_started(_wave_number: int) -> void:
	_update_wave_display()
	
	# 播放波次开始警告动画
	_play_wave_begin_animation()
	
	# 如果是波次胜利条件，更新 KPI（波次开始时）
	if current_mode and current_mode.victory_condition_type == "waves":
		_update_kpi_display()

## 播放波次开始警告动画
func _play_wave_begin_animation() -> void:
	if warning_animation and is_instance_valid(warning_animation):
		warning_animation.stop()
		warning_animation.play("wave_begin")

## 波次敌人击杀回调
func _on_wave_enemy_killed(_wave_number: int, _killed: int, _total: int) -> void:
	_update_wave_display()

## 波次结束回调
func _on_wave_ended(_wave_number: int) -> void:
	# 如果是波次胜利条件，更新 KPI（波次结束后，已消灭波数会+1）
	if current_mode and current_mode.victory_condition_type == "waves":
		_update_kpi_display()

## 更新波次显示
func _update_wave_display() -> void:
	if not wave_label or not wave_manager_ref:
		return
	
	var wave_num = wave_manager_ref.current_wave
	var killed = wave_manager_ref.enemies_killed_this_wave
	var total = wave_manager_ref.enemies_total_this_wave
	
	wave_label.text = "第 %d 波 (消灭: %d / 总计: %d )" % [wave_num, killed, total]

## 主钥数量改变回调
func _on_master_key_changed(new_amount: int, change: int) -> void:
	if master_key_counter:
		master_key_counter.set_value(new_amount, change)

## 更新 KPI 显示
func _update_kpi_display() -> void:
	if not kpi_label or not current_mode:
		return
	
	kpi_label.text = current_mode.get_kpi_text()

## 切换属性面板显示/隐藏
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("info"):
		if player_stats_info:
			player_stats_info.toggle_visibility()

## ==================== BOSS 血条管理 ====================

## 敌人生成回调（用于显示 BOSS 血条）
func _on_enemy_spawned(enemy: Enemy) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	
	# 检查是否是需要显示 BOSS 血条的敌人
	if not BossHPBar.is_boss_enemy(enemy.enemy_id):
		return
	
	# 创建 BOSS 血条
	_create_boss_hp_bar(enemy)

## 创建 BOSS 血条
func _create_boss_hp_bar(enemy: Enemy) -> void:
	if not boss_bar_container:
		push_warning("[GameUI] boss_bar_container 未找到")
		return
	
	# 实例化 BOSS 血条
	var boss_bar = BOSS_HP_BAR_SCENE.instantiate()
	boss_bar_container.add_child(boss_bar)
	
	# 获取 BossHPBar 脚本（如果有的话）
	if boss_bar.has_method("set_enemy"):
		boss_bar.set_enemy(enemy, enemy.enemy_id)
	else:
		# 手动设置（兜底方案）
		_setup_boss_bar_manually(boss_bar, enemy)
	
	print("[GameUI] 创建 BOSS 血条: ", enemy.enemy_id)

## 手动设置 BOSS 血条（兜底方案，如果场景没有脚本）
func _setup_boss_bar_manually(boss_bar: Control, enemy: Enemy) -> void:
	var partrit = boss_bar.get_node_or_null("Control/partrit")
	var progress_bar = boss_bar.get_node_or_null("Control/partrit/ProgressBar")
	
	if not partrit or not progress_bar:
		return
	
	# 设置纹理
	match enemy.enemy_id:
		"monitor":
			partrit.texture = load("res://assets/UI/BOSSHP_ui/parrit-monitor.png")
		"ent":
			partrit.texture = load("res://assets/UI/BOSSHP_ui/partrit-ent.png")
	
	# 设置血量
	progress_bar.max_value = enemy.max_enemyHP
	progress_bar.value = enemy.enemyHP
	
	# 显示血条
	boss_bar.visible = true
	
	# 创建更新计时器
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	boss_bar.add_child(timer)
	
	timer.timeout.connect(func():
		if not is_instance_valid(enemy) or enemy.is_dead:
			boss_bar.queue_free()
			return
		progress_bar.value = enemy.enemyHP
	)
	
	# 监听敌人死亡
	if enemy.has_signal("enemy_killed"):
		enemy.enemy_killed.connect(func(_e): boss_bar.queue_free())

## 节点退出时断开信号连接（防止信号残留）
func _exit_tree() -> void:
	# 断开GameMain信号
	if GameMain.gold_changed.is_connected(_on_gold_changed):
		GameMain.gold_changed.disconnect(_on_gold_changed)
	if GameMain.master_key_changed.is_connected(_on_master_key_changed):
		GameMain.master_key_changed.disconnect(_on_master_key_changed)
	
	# 断开玩家信号
	if player_ref and is_instance_valid(player_ref):
		if player_ref.hp_changed.is_connected(_on_player_hp_changed):
			player_ref.hp_changed.disconnect(_on_player_hp_changed)
	
	# 断开波次管理器信号
	if wave_manager_ref and is_instance_valid(wave_manager_ref):
		if wave_manager_ref.has_signal("enemy_killed") and wave_manager_ref.enemy_killed.is_connected(_on_wave_enemy_killed):
			wave_manager_ref.enemy_killed.disconnect(_on_wave_enemy_killed)
		if wave_manager_ref.has_signal("wave_started") and wave_manager_ref.wave_started.is_connected(_on_wave_started):
			wave_manager_ref.wave_started.disconnect(_on_wave_started)
		if wave_manager_ref.has_signal("wave_ended") and wave_manager_ref.wave_ended.is_connected(_on_wave_ended):
			wave_manager_ref.wave_ended.disconnect(_on_wave_ended)
		if wave_manager_ref.has_signal("enemy_spawned") and wave_manager_ref.enemy_spawned.is_connected(_on_enemy_spawned):
			wave_manager_ref.enemy_spawned.disconnect(_on_enemy_spawned)
