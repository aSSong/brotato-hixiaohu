extends Control
class_name VictoryUI

## 胜利UI
## 当玩家达到目标时显示
@onready var return_button: TextureButton = $MainPanel/ReturnButton
@onready var bg_key: TextureRect = $MainPanel/"bg-key"
@onready var poster: TextureRect = $MainPanel/poster

## 背景滚动速度（像素/秒）
@export var scroll_speed: Vector2 = Vector2(100, 100)

## 背景贴图尺寸（用于无缝循环）
var bg_texture_size: Vector2 = Vector2.ZERO
var scroll_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# 确保状态正确
	if GameState.current_state != GameState.State.GAME_VICTORY:
		GameState.change_state(GameState.State.GAME_VICTORY)
	
	# 连接返回按钮
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)
	
	# 初始化背景
	_setup_scrolling_background()
	
	# 更新职业海报
	_update_poster()

## 初始化滚动背景
func _setup_scrolling_background() -> void:
	if not bg_key or not bg_key.texture:
		return
	
	# 获取贴图尺寸
	bg_texture_size = bg_key.texture.get_size()
	
	# 设置背景铺满并可重复
	bg_key.anchor_left = 0
	bg_key.anchor_top = 0
	bg_key.anchor_right = 1
	bg_key.anchor_bottom = 1
	bg_key.offset_left = 0
	bg_key.offset_top = 0
	bg_key.offset_right = 0
	bg_key.offset_bottom = 0
	
	# 扩展背景尺寸以支持无缝滚动（2倍大小）
	bg_key.anchor_right = 0
	bg_key.anchor_bottom = 0
	var viewport_size = get_viewport_rect().size
	bg_key.size = viewport_size + bg_texture_size
	
	# 设置纹理平铺模式
	bg_key.stretch_mode = TextureRect.STRETCH_TILE

func _process(delta: float) -> void:
	if not bg_key or bg_texture_size == Vector2.ZERO:
		return
	
	# 更新滚动偏移（向左下角滚动）
	scroll_offset.x += scroll_speed.x * delta
	scroll_offset.y += scroll_speed.y * delta
	
	# 循环重置（当滚动超过贴图尺寸时重置）
	if scroll_offset.x >= bg_texture_size.x:
		scroll_offset.x -= bg_texture_size.x
	if scroll_offset.y >= bg_texture_size.y:
		scroll_offset.y -= bg_texture_size.y
	
	# 应用位置偏移（向左下移动 = position 向右上移动的负值）
	bg_key.position = -scroll_offset

## 更新职业海报
func _update_poster() -> void:
	if not poster:
		return
	
	var class_id = GameMain.selected_class_id
	if class_id == "":
		class_id = "balanced"
	
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data and class_data.poster:
		poster.texture = class_data.poster

## 返回主菜单
func _on_return_button_pressed() -> void:
	print("[VictoryUI] 返回主菜单...")
	# 使用SceneCleanupManager安全切换场景（会清理所有游戏对象并重置数据）
	SceneCleanupManager.change_scene_safely("res://scenes/UI/main_title.tscn")
