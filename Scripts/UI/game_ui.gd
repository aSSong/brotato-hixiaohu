extends CanvasLayer

@onready var gold: Label = %gold
@onready var master_key: Label = %master_key
@onready var hp_value_bar: ProgressBar = %hp_value_bar
@onready var exp_value_bar: ProgressBar = %exp_value_bar
@onready var skill_icon: Control = %SkillIcon
@onready var wave_label: Label = %WaveLabel

var hp_label: Label = null  # HP标签
var player_ref: CharacterBody2D = null  # 玩家引用
var victory_triggered: bool = false  # 是否已触发胜利
var wave_manager_ref = null  # 波次管理器引用（避免类型检查错误）

@export var animate_change: bool = true  # 是否播放动画
@export var show_change_popup: bool = true  # 是否显示 +1 弹窗

var current_tween: Tween = null  # 保存当前动画引用
var original_scale: Vector2  # 保存原始缩放
var skill_icon_script: SkillIcon = null

var goalkeys = 200 # 获得胜利的目标钥匙数目

func _ready() -> void:
	
	# 保存原始缩放
	original_scale = scale
	
	# 连接信号
	GameMain.gold_changed.connect(_on_gold_changed)
	GameMain.master_key_changed.connect(_on_master_key_changed)
	
	# 初始化显示
	update_display(GameMain.gold, 0)
	update_master_key_display(GameMain.master_key, 0)
	
	# 初始化技能图标
	_setup_skill_icon()
	
	# 初始化HP显示
	_setup_hp_display()
	
	# 初始化波次显示
	_setup_wave_display()

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

func _input(_event: InputEvent) -> void:
	# 检测技能输入
	if Input.is_action_just_pressed("skill"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("activate_class_skill"):
			player.activate_class_skill()

func _on_gold_changed(new_amount: int, change: int) -> void:
	# 更新文本
	update_display(new_amount, change)
	
	# 播放动画
	if animate_change and change != 0:
		play_change_animation(change)
	
	# 显示变化弹窗
	if show_change_popup and change > 0:
		show_popup(change)
	
	# 检查是否达到胜利条件
	if new_amount >= goalkeys and not victory_triggered:
		victory_triggered = true
		_trigger_victory()

func update_display(amount: int, _change: int) -> void:
	self.gold.text = "%d" % amount
	# 或者更花哨的显示：
	# text = "💰 %d" % amount

func play_change_animation(change: int) -> void:
	# 数字增加时的闪烁/缩放动画
	#original_scale = scale
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	# 放大 -> 缩回
	tween.tween_property(self.gold, "scale", original_scale * 1.1, 0.1)
	tween.tween_property(self.gold, "scale", original_scale, 0.2)
	
	# 可选：颜色闪烁
	if change > 0:
		self.gold.modulate = Color.YELLOW
		tween.tween_property(self.gold, "modulate", Color.WHITE, 0.2)

func show_popup(change: int) -> void:
	# 创建飘字效果 "+1"
	var popup = Label.new()
	popup.text = "+%d" % change
	popup.add_theme_font_size_override("font_size", 25)
	popup.modulate = Color.YELLOW
	
	# 添加到场景中（相对于金币 UI）
	self.gold.add_child(popup)
	popup.position = Vector2(0, -15)  # 在金币数字旁边
	
	# 动画：向上飘 + 淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 50, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0)
	
	# 动画结束后删除
	tween.finished.connect(popup.queue_free)

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
	
	# 更新ProgressBar
	hp_value_bar.max_value = max_hp
	hp_value_bar.value = current_hp
	
	# 更新Label文本
	if hp_label:
		hp_label.text = "%d / %d" % [current_hp, max_hp]

## 触发胜利
func _trigger_victory() -> void:
	# 延迟一下再跳转
	await get_tree().create_timer(1.0).timeout
	
	# 加载胜利UI场景
	var victory_scene = load("res://scenes/UI/victory_ui.tscn")
	if victory_scene:
		get_tree().change_scene_to_packed(victory_scene)
	else:
		push_error("无法加载胜利UI场景！")

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
		if now_enemies.has("wave_manager"):
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
		if now_enemies and now_enemies.has("wave_manager"):
			wave_manager_ref = now_enemies.wave_manager
			if wave_manager_ref:
				# 连接信号
				if wave_manager_ref.has_signal("enemy_killed"):
					if not wave_manager_ref.enemy_killed.is_connected(_on_wave_enemy_killed):
						wave_manager_ref.enemy_killed.connect(_on_wave_enemy_killed)
				if wave_manager_ref.has_signal("wave_started"):
					if not wave_manager_ref.wave_started.is_connected(_on_wave_started):
						wave_manager_ref.wave_started.connect(_on_wave_started)
				_update_wave_display()
				return
		attempts += 1

## 波次开始回调
func _on_wave_started(_wave_number: int) -> void:
	_update_wave_display()

## 波次敌人击杀回调
func _on_wave_enemy_killed(_wave_number: int, _killed: int, _total: int) -> void:
	_update_wave_display()

## 更新波次显示
func _update_wave_display() -> void:
	if not wave_label or not wave_manager_ref:
		return
	
	var wave_num = wave_manager_ref.current_wave
	var killed = wave_manager_ref.enemies_killed_this_wave
	var total = wave_manager_ref.enemies_total_this_wave
	
	wave_label.text = "Wave: %d    (%d/%d)" % [wave_num, killed, total]

## 主钥数量改变回调
func _on_master_key_changed(new_amount: int, change: int) -> void:
	update_master_key_display(new_amount, change)
	
	# 播放动画
	if animate_change and change != 0:
		play_master_key_change_animation(change)
	
	# 显示变化弹窗
	if show_change_popup and change > 0:
		show_master_key_popup(change)

## 更新主钥显示
func update_master_key_display(amount: int, _change: int) -> void:
	if master_key:
		master_key.text = "%d" % amount

## 主钥变化动画
func play_master_key_change_animation(change: int) -> void:
	if not master_key:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	var original_scale_mk = master_key.scale if master_key else Vector2.ONE
	
	# 放大 -> 缩回
	tween.tween_property(master_key, "scale", original_scale_mk * 1.1, 0.1)
	tween.tween_property(master_key, "scale", original_scale_mk, 0.2)
	
	# 可选：颜色闪烁
	if change > 0:
		master_key.modulate = Color.CYAN
		tween.tween_property(master_key, "modulate", Color.WHITE, 0.2)

## 显示主钥弹窗
func show_master_key_popup(change: int) -> void:
	if not master_key:
		return
	# 创建飘字效果 "+1"
	var popup = Label.new()
	popup.text = "+%d" % change
	popup.add_theme_font_size_override("font_size", 25)
	popup.modulate = Color.CYAN
	
	# 添加到场景中（相对于主钥 UI）
	master_key.add_child(popup)
	popup.position = Vector2(0, -15)  # 在主钥数字旁边
	
	# 动画：向上飘 + 淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 50, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0)
	
	# 动画结束后删除
	tween.finished.connect(popup.queue_free)
