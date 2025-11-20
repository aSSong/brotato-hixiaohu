extends Control
class_name PlayerSpeechBubble

## Player的说话气泡组件
## 手动添加到player.tscn中，控制显示和隐藏

@onready var background: Panel = $Background
@onready var label: Label = $Background/Label
@onready var pointer: Polygon2D = $Pointer  # 气泡下方的小尖尖

## 气泡显示持续时间
var duration: float = 5.0

## 当前显示时间
var elapsed_time: float = 0.0

## 淡入淡出时间
var fade_in_time: float = 0.2
var fade_out_time: float = 0.3

## 是否正在显示
var is_showing: bool = false

func _ready() -> void:
	# 设置z_index确保显示在角色上方
	z_index = 98
	
	# 初始隐藏
	visible = false
	modulate.a = 0.0
	
	# 设置初始大小
	size = Vector2(200, 60)
	
	# 初始化指针（如果存在）
	if pointer:
		pointer.visible = false
		# 设置指针颜色与背景一致
		pointer.color = Color(0.2, 0.2, 0.2, 0.9)

func _process(delta: float) -> void:
	if not is_showing:
		return
	
	# 更新显示时间
	elapsed_time += delta
	
	# 检查是否需要淡出
	if elapsed_time >= duration - fade_out_time:
		_start_fade_out()
	
	# 检查是否应该消失
	if elapsed_time >= duration:
		_hide_bubble()


## 设置文本大小
func set_font_size(size: int) -> void:
	if label:
		label.add_theme_font_size_override("font_size", size)

## 显示气泡
func show_speech(text: String, duration_override: float = 3.0) -> void:
	print("[PlayerSpeechBubble] show_speech被调用，文本: ", text)
	
	if not label:
		push_error("[PlayerSpeechBubble] Label未找到！")
		return
	
	# 设置文本
	label.text = text
	duration = duration_override
	elapsed_time = 0.0
	is_showing = true
	
	print("[PlayerSpeechBubble] 文本已设置，is_showing=true")
	
	# 等待一帧让Label计算文本大小
	await get_tree().process_frame
	
	# 根据文本长度调整气泡大小
	if label:
		var font = label.get_theme_font("font")
		var font_size = label.get_theme_font_size("font_size")
		if font:
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			# 添加内边距
			var padding = Vector2(40, 20)
			size = text_size + padding
			
			# 更新背景大小
			if background:
				background.size = size
			
			# 更新三角形指针位置（在气泡底部中央）
			if pointer:
				pointer.position = Vector2(size.x / 2.0, size.y)
	
	# 显示并开始淡入
	visible = true
	# 显示指针
	if pointer:
		pointer.visible = true
	print("[PlayerSpeechBubble] visible设置为true，位置: ", position, " 大小: ", size)
	_start_fade_in()

## 隐藏气泡
func _hide_bubble() -> void:
	is_showing = false
	visible = false
	modulate.a = 0.0
	elapsed_time = 0.0
	# 同时隐藏指针
	if pointer:
		pointer.visible = false

## 开始淡入动画
func _start_fade_in() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_time)

## 开始淡出动画
func _start_fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
