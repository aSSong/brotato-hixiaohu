extends Control
class_name WeaponCompact

## 武器紧凑显示组件
## 用于在各种 UI 中显示武器信息（名称、图片、品质背景）

@onready var bg_lilweapon: TextureRect = $"bg-lilweapon"
@onready var weapon_image: TextureRect = $"bg-lilweapon/weapon-image"
@onready var weapon_name_label: Label = $"bg-lilweapon/weapon-name"

## 武器品质背景贴图（静态缓存）
static var quality_bg_textures: Dictionary = {}

## 初始化品质背景贴图
static func _init_quality_textures() -> void:
	if quality_bg_textures.is_empty():
		quality_bg_textures = {
			1: load("res://assets/UI/common/bg-lilweapon-gray.png"),
			2: load("res://assets/UI/common/bg-lilweapon-green.png"),
			3: load("res://assets/UI/common/bg-lilweapon-blue.png"),
			4: load("res://assets/UI/common/bg-lilweapon-purple.png"),
			5: load("res://assets/UI/common/bg-lilweapon-yellow.png")
		}

func _ready() -> void:
	_init_quality_textures()

## 设置武器数据
## @param weapon_id: 武器ID
## @param weapon_level: 武器等级（1-5）
func setup_weapon(weapon_id: String, weapon_level: int = 1) -> void:
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if not weapon_data:
		push_warning("[WeaponCompact] 找不到武器: " + weapon_id)
		return
	
	setup_weapon_from_data(weapon_data, weapon_level)

## 从 WeaponData 直接设置武器
## @param weapon_data: 武器数据对象
## @param weapon_level: 武器等级（1-5）
func setup_weapon_from_data(weapon_data: WeaponData, weapon_level: int = 1) -> void:
	if not weapon_data:
		return
	
	# 设置武器名称
	if weapon_name_label:
		weapon_name_label.text = weapon_data.weapon_name
	
	# 设置武器图片
	if weapon_image and weapon_data.texture_path:
		var texture = load(weapon_data.texture_path)
		if texture:
			weapon_image.texture = texture
	
	# 根据品质设置背景
	set_quality_level(weapon_level)

## 设置品质等级（仅更新背景）
## @param level: 品质等级（1-5）
func set_quality_level(level: int) -> void:
	_init_quality_textures()
	
	if bg_lilweapon:
		var level_clamped = clamp(level, 1, 5)
		if quality_bg_textures.has(level_clamped):
			bg_lilweapon.texture = quality_bg_textures[level_clamped]

## 手动设置武器名称
func set_weapon_name(weapon_name: String) -> void:
	if weapon_name_label:
		weapon_name_label.text = weapon_name

## 手动设置武器图片
func set_weapon_texture(texture: Texture2D) -> void:
	if weapon_image:
		weapon_image.texture = texture

## 从武器信息字典设置（兼容 GhostData.weapons 格式）
## @param weapon_info: {"id": "weapon_id", "level": 1}
func setup_from_weapon_info(weapon_info: Dictionary) -> void:
	var weapon_id = weapon_info.get("id", "")
	var weapon_level = weapon_info.get("level", 1)
	setup_weapon(weapon_id, weapon_level)

