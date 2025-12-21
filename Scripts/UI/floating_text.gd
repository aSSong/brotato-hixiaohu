extends Control
class_name FloatingText

## 浮动文字（对象池优化版）
## 显示伤害数字等浮动文字效果
## 使用对象池避免频繁实例化造成的性能问题

@onready var label: Label = $Label

var text: String = ""
var duration: float = 0.8
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 800.0
var start_scale: float = 0.1
var peak_scale: float = 2.0
var end_scale: float = 1.0
var is_critical: bool = false
var initial_color: Color = Color.WHITE

## 当前的 Tween 引用（用于复用时取消）
var _current_tween: Tween = null

## ========== 对象池系统 ==========

## 对象池（静态，所有实例共享）
static var _pool: Array = []

## 活跃的浮动文字数量
static var _active_count: int = 0

## 对象池最大大小（同时显示的最大数量）
const POOL_MAX_SIZE: int = 300

## 预加载的场景
static var _scene: PackedScene = null

## 是否已初始化
static var _initialized: bool = false

## 初始化对象池（预热）
static func initialize_pool(preheat_count: int = 50) -> void:
	if _initialized:
		return
	
	_scene = preload("res://scenes/UI/floating_text.tscn")
	_initialized = true
	
	# 预热：创建一些实例放入池中
	for i in range(preheat_count):
		var instance = _scene.instantiate()
		instance.visible = false
		_pool.append(instance)
	
	print("[FloatingText] 对象池初始化完成，预热 %d 个实例" % preheat_count)

## 从池中获取实例
static func _get_from_pool() -> FloatingText:
	if _pool.size() > 0:
		var instance = _pool.pop_back()
		return instance
	
	# 池为空，创建新实例
	if not _scene:
		_scene = preload("res://scenes/UI/floating_text.tscn")
	
	return _scene.instantiate()

## 归还实例到池中
static func _return_to_pool(instance: FloatingText) -> void:
	if not is_instance_valid(instance):
		return
	
	_active_count -= 1
	
	# 如果池已满，直接销毁
	if _pool.size() >= POOL_MAX_SIZE:
		instance.queue_free()
		return
	
	# 重置状态并归还
	instance._reset_state()
	instance.visible = false
	
	# 从父节点移除（但不销毁）
	if instance.get_parent():
		instance.get_parent().remove_child(instance)
	
	_pool.append(instance)

func _ready() -> void:
	# 添加到组（用于调试统计）
	add_to_group("floating_text")
	
	if label:
		label.text = text
		label.modulate = initial_color
		label.modulate.a = 1.0
		
		if is_critical:
			label.add_theme_font_size_override("font_size", 56)
			peak_scale = 2.0
			velocity.y -= 100
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
		else:
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 2)
	
	z_index = 99
	scale = Vector2(start_scale, start_scale)
	
	_start_animation()

func _process(delta: float) -> void:
	velocity.y += gravity * delta
	global_position += velocity * delta

## 重置状态（用于对象池复用）
func _reset_state() -> void:
	# 取消当前动画
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	
	# 重置属性
	text = ""
	velocity = Vector2.ZERO
	is_critical = false
	initial_color = Color.WHITE
	scale = Vector2(start_scale, start_scale)
	
	if label:
		label.modulate.a = 1.0

## 设置新的显示内容（复用时调用）
func setup(_world_pos: Vector2, damage_text: String, color: Color, critical: bool) -> void:
	text = damage_text
	is_critical = critical
	initial_color = color
	
	# 设置初始速度
	var up_speed = randf_range(300, 500)
	var side_speed = randf_range(-200, 200)
	velocity = Vector2(side_speed, -up_speed)
	
	if label:
		label.text = text
		label.modulate = initial_color
		label.modulate.a = 1.0
		
		if is_critical:
			label.add_theme_font_size_override("font_size", 56)
			peak_scale = 2.0
			velocity.y -= 100
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
		else:
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 2)
	
	z_index = 99
	scale = Vector2(start_scale, start_scale)
	visible = true

func _start_animation() -> void:
	# 取消之前的动画
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	# 缩放动画：先放大(pop)再缩小
	_current_tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), duration * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(self, "scale", Vector2(end_scale, end_scale), duration * 0.4).set_delay(duration * 0.2)
	
	# 淡出
	if label:
		_current_tween.tween_property(label, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7)
	
	# 动画结束后归还到池
	_current_tween.finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	FloatingText._return_to_pool(self)

## 静态方法：创建浮动文字（使用对象池）
static func create_floating_text(world_pos: Vector2, damage_text: String, color: Color = Color.WHITE, critical: bool = false) -> void:
	# 忽略0伤害
	if damage_text == "-0" or damage_text == "0":
		return
	
	# 检查是否超过最大活跃数量（避免过多文字导致卡顿）
	if _active_count >= POOL_MAX_SIZE:
		return
	
	# 从池中获取实例
	var floating_text = _get_from_pool()
	if not floating_text:
		return
	
	_active_count += 1
	
	# 添加到世界场景（使用世界坐标，这样摄像机移动时文字不会跟着飘）
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		# 优先使用 GameMain.duplicate_node（专门用于动态生成的特效/UI）
		var parent_node = null
		if GameMain and GameMain.duplicate_node:
			parent_node = GameMain.duplicate_node
		else:
			# 降级：添加到场景根节点
			parent_node = tree.root
		
		parent_node.add_child(floating_text)
		# 直接使用世界坐标
		floating_text.global_position = world_pos
	
	# 设置内容并启动动画
	floating_text.setup(world_pos, damage_text, color, critical)
	floating_text._start_animation()

## 获取对象池统计信息（调试用）
static func get_pool_stats() -> Dictionary:
	return {
		"pool_size": _pool.size(),
		"active_count": _active_count,
		"max_size": POOL_MAX_SIZE
	}
