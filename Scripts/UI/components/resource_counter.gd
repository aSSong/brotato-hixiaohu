extends Control
class_name ResourceCounter

## 通用资源计数器组件
## 支持动画和弹窗效果，可复用于金币、钥匙等资源显示

@export var icon_texture: Texture2D
@export var animate_changes: bool = true
@export var show_popup: bool = true

@onready var label: Label = $Label
@onready var icon: Sprite2D = $Control/Sprite2D

var original_scale: Vector2 = Vector2.ONE
var current_value: int = 0

func _ready() -> void:
	original_scale = label.scale
	
	# 设置图标
	if icon and icon_texture:
		icon.texture = icon_texture

## 设置数值
func set_value(value: int, change: int = 0) -> void:
	current_value = value
	label.text = str(value)
	
	if change != 0:
		if animate_changes:
			_play_animation(change)
		
		if show_popup and change > 0:
			_show_popup(change)

## 播放变化动画
func _play_animation(change: int) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	# 放大 -> 缩回
	tween.tween_property(label, "scale", original_scale * 1.1, 0.1)
	tween.tween_property(label, "scale", original_scale, 0.2)
	
	# 可选：颜色闪烁
	if change > 0:
		label.modulate = Color.YELLOW
		tween.tween_property(label, "modulate", Color.WHITE, 0.2)

## 显示弹窗飘字
func _show_popup(change: int) -> void:
	# 创建飘字效果 "+X"
	var popup = Label.new()
	popup.text = "+%d" % change
	popup.add_theme_font_size_override("font_size", 25)
	popup.modulate = Color.YELLOW
	
	# 添加到label中（相对于数字旁边）
	label.add_child(popup)
	popup.position = Vector2(0, -15)
	
	# 动画：向上飘 + 淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 50, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0)
	
	# 动画结束后删除
	tween.finished.connect(popup.queue_free)
