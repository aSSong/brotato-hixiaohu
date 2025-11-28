extends TextureRect
class_name DamageFlash

## 受击屏幕闪红效果
## 放在 game_ui 下，当玩家受伤时触发淡入淡出的红色闪烁

@export var flash_duration: float = 0.3  ## 闪烁总时长
@export var fade_in_ratio: float = 0.3   ## 淡入占比 (0.3 = 30% 时间用于淡入)

var tween: Tween = null

func _ready() -> void:
	# 初始化为完全透明
	modulate.a = 0.0
	# 确保覆盖整个屏幕
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 不阻挡鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 触发闪红效果
func flash() -> void:
	# 如果有正在进行的动画，先停止
	if tween and tween.is_valid():
		tween.kill()
	
	# 创建新的 Tween
	tween = create_tween()
	
	# 计算淡入和淡出时间
	var fade_in_time = flash_duration * fade_in_ratio
	var fade_out_time = flash_duration * (1.0 - fade_in_ratio)
	
	# 淡入（从透明到显示）
	tween.tween_property(self, "modulate:a", 1.0, fade_in_time).set_ease(Tween.EASE_OUT)
	# 淡出（从显示到透明）
	tween.tween_property(self, "modulate:a", 0.0, fade_out_time).set_ease(Tween.EASE_IN)

