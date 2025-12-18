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
@onready var timing_text: Label = $timing/timingText
@onready var new_record_sign: Control = $timing/timingText/newRecordSign

## BOSS HP Bar 场景
const BOSS_HP_BAR_SCENE = preload("res://scenes/UI/components/BOSS_HPbar.tscn")

# 内部引用
var hp_label: Label = null  # HP标签
var player_ref: CharacterBody2D = null  # 玩家引用
var wave_manager_ref = null  # 波次管理器引用
var current_mode: BaseGameMode = null  # 当前游戏模式

# ===== Debug Panel（发行版保留，默认隐藏；R键切换）=====
var _debug_panel: PanelContainer = null
var _debug_label: RichTextLabel = null
var _debug_visible: bool = false

# ===== 计时器显示 =====
var _best_record_wave: int = -1  # 历史最佳波次（-1 表示无记录）
var _best_record_time: float = INF  # 历史最佳时间
var _completed_waves: int = 0  # 本局已完成的波次数

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
		
	# 默认隐藏新纪录提示
	new_record_sign.visible = false
	
	# 初始化各个子系统
	_setup_skill_icon()
	_setup_hp_display()
	_setup_wave_display()
	
	# 初始化 KPI 显示
	_update_kpi_display()
	
	# 调试面板（默认隐藏）
	_setup_debug_panel()
	
	# 初始化计时器显示
	_setup_timing_display()

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


func _setup_debug_panel() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.visible = false
	_debug_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_debug_panel)
	
	# 布局：左上角小面板
	_debug_panel.anchor_left = 0.0
	_debug_panel.anchor_top = 0.0
	_debug_panel.anchor_right = 0.0
	_debug_panel.anchor_bottom = 0.0
	_debug_panel.offset_left = 12
	_debug_panel.offset_top = 312
	_debug_panel.offset_right = 520
	_debug_panel.offset_bottom = 580
	
	_debug_label = RichTextLabel.new()
	_debug_label.name = "DebugLabel"
	_debug_label.fit_content = true
	_debug_label.scroll_active = false
	_debug_label.bbcode_enabled = false
	_debug_label.text = ""
	_debug_panel.add_child(_debug_label)

## 设置计时器显示
func _setup_timing_display() -> void:
	# 获取当前模式的历史最佳记录
	var mode_id = GameMain.current_mode_id
	if mode_id.is_empty():
		mode_id = "survival"
	
	if mode_id == "survival":
		var record = LeaderboardManager.get_survival_record()
		if not record.is_empty():
			_best_record_wave = record.get("best_wave", 30)
			_best_record_time = record.get("completion_time_seconds", INF)
	elif mode_id == "multi":
		var record = LeaderboardManager.get_multi_record()
		if not record.is_empty():
			_best_record_wave = record.get("best_wave", 0)
			_best_record_time = INF  # Multi模式不比较时间
	
	# 默认隐藏新纪录标志
	if new_record_sign:
		new_record_sign.visible = false

## 更新计时器显示
func _update_timing_display() -> void:
	if not timing_text:
		return
	
	# 获取当前游戏时间
	var elapsed_time: float = 0.0
	if GameMain.current_session:
		elapsed_time = GameMain.current_session.get_elapsed_time()
	
	# 格式化时间为 "XX分XX秒XX" 格式
	timing_text.text = _format_time_chinese(elapsed_time)
	
	# 检查是否优于历史记录（只有完成波次后才判断）
	if new_record_sign:
		var is_better = false
		
		# 必须至少完成1波才能算新纪录
		if _completed_waves > 0:
			if GameMain.current_mode_id == "survival":
				# Survival模式：已完成波次更高，或波次相同且时间更短
				if _best_record_wave < 0:
					# 无历史记录，当前进度即为新纪录
					is_better = true
				elif _completed_waves > _best_record_wave:
					is_better = true
				elif _completed_waves == _best_record_wave and elapsed_time < _best_record_time:
					is_better = true
			elif GameMain.current_mode_id == "multi":
				# Multi模式：仅已完成波次更高
				if _best_record_wave < 0:
					# 无历史记录，当前进度即为新纪录
					is_better = true
				elif _completed_waves > _best_record_wave:
					is_better = true
		
		new_record_sign.visible = is_better

## 格式化时间为中文格式 "XX分XX秒XX"
func _format_time_chinese(seconds: float) -> String:
	var total_seconds = int(seconds)
	var centiseconds = int((seconds - total_seconds) * 100)
	var mins = total_seconds / 60
	var secs = total_seconds % 60
	return "%d分%02d秒%02d" % [mins, secs, centiseconds]


func _unhandled_input(event: InputEvent) -> void:
	# G键切换调试面板（避免改 InputMap，降低发行风险）
	if event is InputEventKey:
		var e := event as InputEventKey
		if e.pressed and not e.echo and e.keycode == KEY_G:
			_debug_visible = not _debug_visible
			if _debug_panel:
				_debug_panel.visible = _debug_visible
			# 立刻刷新一次
			_update_debug_panel()

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
func _on_wave_ended(wave_number: int) -> void:
	# 更新已完成波次数
	_completed_waves = wave_number
	
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


func _process(_delta: float) -> void:
	# 只在面板显示时刷新，避免无谓开销
	if _debug_visible:
		_update_debug_panel()
	
	# 更新计时器显示
	_update_timing_display()


func _ws_state_name(state_id: int) -> String:
	# WaveSystemV3.WaveState: 0 IDLE, 1 SPAWNING, 2 FIGHTING, 3 WAVE_COMPLETE, 4 SHOP_OPEN
	match state_id:
		0: return "IDLE"
		1: return "SPAWNING"
		2: return "FIGHTING"
		3: return "WAVE_COMPLETE"
		4: return "SHOP_OPEN"
		_: return "UNKNOWN"


func _update_debug_panel() -> void:
	if not _debug_panel or not _debug_label:
		return
	
	var tree = get_tree()
	var paused = tree.paused if tree else false
	
	# GameState
	var gs_id = GameState.current_state
	var gs_name = str(gs_id)
	if GameState.has_method("_state_name"):
		gs_name = GameState._state_name(gs_id)
	
	# DeathManager
	var dm = tree.get_first_node_in_group("death_manager") if tree else null
	var is_dead = false
	if dm and "is_dead" in dm:
		is_dead = bool(dm.is_dead)
	
	# Shop
	var shop = tree.get_first_node_in_group("upgrade_shop") if tree else null
	var shop_exists = shop != null and is_instance_valid(shop)
	var shop_visible = shop_exists and shop.visible
	
	# Rescue UI
	var rescue_nodes = tree.get_nodes_in_group("rescue_ui") if tree else []
	var rescue_exists = false
	var rescue_visible = false
	for n in rescue_nodes:
		if n and is_instance_valid(n):
			rescue_exists = true
			if n.visible:
				rescue_visible = true
				break
	
	# Wave system
	var ws = wave_manager_ref
	if ws == null and tree:
		ws = tree.get_first_node_in_group("wave_manager")
	
	var wave_num = 0
	var killed = 0
	var total = 0
	var spawned = 0
	var active = -1
	var ws_state_id = -1
	var ws_state = ""
	var in_progress = false
	
	if ws and is_instance_valid(ws):
		if "current_wave" in ws: wave_num = int(ws.current_wave)
		if "enemies_killed_this_wave" in ws: killed = int(ws.enemies_killed_this_wave)
		if "enemies_total_this_wave" in ws: total = int(ws.enemies_total_this_wave)
		if "enemies_spawned_this_wave" in ws: spawned = int(ws.enemies_spawned_this_wave)
		if "active_enemies" in ws: active = int((ws.active_enemies as Array).size())
		if "current_state" in ws:
			ws_state_id = int(ws.current_state)
			ws_state = "%s(%d)" % [_ws_state_name(ws_state_id), ws_state_id]
		if "is_wave_in_progress" in ws:
			in_progress = bool(ws.is_wave_in_progress)
	
	_debug_label.text = (
		"[Debug]\n" +
		"paused: %s\n" % str(paused) +
		"GameState: %s\n" % gs_name +
		"DeathManager.is_dead: %s\n" % str(is_dead) +
		"Shop: exists=%s visible=%s\n" % [str(shop_exists), str(shop_visible)] +
		"RescueUI: exists=%s visible=%s\n" % [str(rescue_exists), str(rescue_visible)] +
		"Wave: %d  killed=%d total=%d spawned=%d active=%d in_progress=%s state=%s\n" % [
			wave_num, killed, total, spawned, active, str(in_progress), ws_state
		]
	)

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
