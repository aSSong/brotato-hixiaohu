extends CanvasLayer

@onready var gold: Label = %gold
@onready var hp_value_bar: ProgressBar = %hp_value_bar
@onready var exp_value_bar: ProgressBar = %exp_value_bar
@onready var skill_icon: Control = %SkillIcon

@export var animate_change: bool = true  # 是否播放动画
@export var show_change_popup: bool = true  # 是否显示 +1 弹窗

var current_tween: Tween = null  # 保存当前动画引用
var original_scale: Vector2  # 保存原始缩放
var skill_icon_script: SkillIcon = null

func _ready() -> void:
	
	# 保存原始缩放
	original_scale = scale
	
	# 连接信号
	GameMain.gold_changed.connect(_on_gold_changed)
	
	# 初始化显示
	update_display(GameMain.gold, 0)
	
	# 初始化技能图标
	_setup_skill_icon()

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

func _input(event: InputEvent) -> void:
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

func update_display(amount: int, change: int) -> void:
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
