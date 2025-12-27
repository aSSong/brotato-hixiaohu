extends Control
class_name EnemyDirectManager

## 离屏怪物指示器管理器
## - 只使用 WaveSystemV3.active_enemies（不全局扫 enemy 组）
## - 固定间隔刷新（不每帧刷新，不创建Timer）
## - 支持多种怪物 id 配置对应头像

const ENEMY_DIRECT_SCENE: PackedScene = preload("res://scenes/UI/components/enemy_dircet.tscn")

## 配置表：enemy_id -> 配置
## 后续扩展只需增加一行映射即可
const ENEMY_DIRECT_CONFIG: Dictionary = {
	"mashroom_xmas": {
		"portrait": preload("res://assets/UI/enemydirect_ui/partrit_mashroom_xmas.png")
	},
}

const REFRESH_INTERVAL: float = 0.033  #刷新时间间隔
const EDGE_PADDING: float = 20.0 #边缘距离

var _wave_manager_cache: Node = null
var _acc: float = 0.0

## key: Enemy实例(value: indicator Control)
var _indicators_by_enemy: Dictionary = {}

func _ready() -> void:
	# 确保在屏幕坐标系下使用 TopLeft 锚点
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH_INTERVAL:
		return
	_acc = fmod(_acc, REFRESH_INTERVAL)
	_refresh()


func _refresh() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var view_size: Vector2 = vp.get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return

	# 缓存 wave_manager（WaveSystemV3）
	if _wave_manager_cache == null or not is_instance_valid(_wave_manager_cache):
		var tree := get_tree()
		if tree:
			_wave_manager_cache = tree.get_first_node_in_group("wave_manager")

	if _wave_manager_cache == null or not is_instance_valid(_wave_manager_cache):
		_hide_all()
		return

	if not ("active_enemies" in _wave_manager_cache):
		_hide_all()
		return

	var active_v: Variant = _wave_manager_cache.get("active_enemies")
	if not (active_v is Array):
		_hide_all()
		return
	var active: Array = active_v

	var screen_rect := Rect2(Vector2.ZERO, view_size)
	var screen_center := view_size * 0.5

	var seen: Dictionary = {}

	for e in active:
		if not is_instance_valid(e):
			continue
		# 兼容 Enemy.gd：is_dead 字段
		if e.get("is_dead"):
			continue
		if not (e is Node2D):
			continue

		var enemy := e as Node2D
		var enemy_id := str(enemy.get("enemy_id"))
		if not ENEMY_DIRECT_CONFIG.has(enemy_id):
			continue

		seen[enemy] = true

		# 世界坐标 -> 屏幕坐标（Godot 4.x）：使用 CanvasItem 的全局画布变换
		var screen_pos: Vector2 = enemy.get_global_transform_with_canvas().origin
		var is_on_screen := screen_rect.has_point(screen_pos)

		var indicator := _get_or_create_indicator(enemy, enemy_id)
		if indicator == null:
			continue

		if is_on_screen:
			indicator.visible = false
			continue

		# 贴边：考虑图标尺寸，保证完整显示
		var icon_size := _get_indicator_icon_size(indicator)
		var half := icon_size * 0.5
		var inner_rect := _make_inner_rect(view_size, half, EDGE_PADDING)

		var edge_point := _ray_intersect_rect_border(screen_center, screen_pos, inner_rect)
		indicator.position = edge_point - half
		indicator.visible = true

	# 清理：不在本次扫描中的、或已经失效的敌人
	_cleanup_indicators(seen)


func _get_or_create_indicator(enemy: Node2D, enemy_id: String) -> Control:
	if _indicators_by_enemy.has(enemy):
		var existing = _indicators_by_enemy[enemy]
		if is_instance_valid(existing):
			return existing as Control
		_indicators_by_enemy.erase(enemy)

	var inst = ENEMY_DIRECT_SCENE.instantiate()
	if not (inst is Control):
		if is_instance_valid(inst):
			inst.queue_free()
		return null
	var indicator := inst as Control
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(indicator)
	_indicators_by_enemy[enemy] = indicator

	_apply_indicator_config(indicator, enemy_id)
	indicator.visible = false
	return indicator


func _apply_indicator_config(indicator: Control, enemy_id: String) -> void:
	var cfg: Dictionary = ENEMY_DIRECT_CONFIG.get(enemy_id, {})
	var portrait = cfg.get("portrait", null)
	if portrait:
		var tr = indicator.get_node_or_null("enemy")
		if tr and tr is TextureRect:
			(tr as TextureRect).texture = portrait


func _get_indicator_icon_size(indicator: Control) -> Vector2:
	# 优先使用子节点 TextureRect(enemy) 的实际尺寸（该场景里默认 40x40）
	var tr = indicator.get_node_or_null("enemy")
	if tr and tr is TextureRect:
		var s := (tr as TextureRect).size
		if s.x > 0.0 and s.y > 0.0:
			return s
	# 兜底：用 Control.size
	var cs := indicator.size
	if cs.x > 0.0 and cs.y > 0.0:
		return cs
	# 最终兜底：与当前 enemy_dircet.tscn 默认一致
	return Vector2(40.0, 40.0)


func _make_inner_rect(view_size: Vector2, half: Vector2, padding: float) -> Rect2:
	var left := half.x + padding
	var top := half.y + padding
	var right := view_size.x - half.x - padding
	var bottom := view_size.y - half.y - padding

	# 防止半径过大导致反向
	if right < left:
		right = left
	if bottom < top:
		bottom = top

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


## 从 center 发射到 target 的射线，与 rect 边界交点（确保点落在 rect 边界上）
func _ray_intersect_rect_border(center: Vector2, target: Vector2, rect: Rect2) -> Vector2:
	var dir := target - center
	if dir.length_squared() < 0.000001:
		dir = Vector2.RIGHT

	var best_t := INF
	var best_point := center

	var left := rect.position.x
	var right := rect.position.x + rect.size.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y

	# 与左右边界求交
	if absf(dir.x) > 0.000001:
		var t1 := (left - center.x) / dir.x
		if t1 > 0.0:
			var y1 := center.y + dir.y * t1
			if y1 >= top and y1 <= bottom and t1 < best_t:
				best_t = t1
				best_point = Vector2(left, y1)

		var t2 := (right - center.x) / dir.x
		if t2 > 0.0:
			var y2 := center.y + dir.y * t2
			if y2 >= top and y2 <= bottom and t2 < best_t:
				best_t = t2
				best_point = Vector2(right, y2)

	# 与上下边界求交
	if absf(dir.y) > 0.000001:
		var t3 := (top - center.y) / dir.y
		if t3 > 0.0:
			var x3 := center.x + dir.x * t3
			if x3 >= left and x3 <= right and t3 < best_t:
				best_t = t3
				best_point = Vector2(x3, top)

		var t4 := (bottom - center.y) / dir.y
		if t4 > 0.0:
			var x4 := center.x + dir.x * t4
			if x4 >= left and x4 <= right and t4 < best_t:
				best_t = t4
				best_point = Vector2(x4, bottom)

	# 理论不会走到这里；兜底用 clamp
	if best_t == INF:
		best_point.x = clampf(target.x, left, right)
		best_point.y = clampf(target.y, top, bottom)

	return best_point


func _cleanup_indicators(seen: Dictionary) -> void:
	var keys := _indicators_by_enemy.keys()
	for k in keys:
		if not is_instance_valid(k):
			_remove_indicator_for_key(k)
			continue
		if not seen.has(k):
			# 本次扫描没出现：隐藏并移除
			_remove_indicator_for_key(k)


func _remove_indicator_for_key(key) -> void:
	if not _indicators_by_enemy.has(key):
		return
	var ind = _indicators_by_enemy[key]
	_indicators_by_enemy.erase(key)
	if is_instance_valid(ind):
		(ind as Node).queue_free()


func _hide_all() -> void:
	for key in _indicators_by_enemy.keys():
		var ind = _indicators_by_enemy.get(key, null)
		if is_instance_valid(ind):
			(ind as CanvasItem).visible = false
