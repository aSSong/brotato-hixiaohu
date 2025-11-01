extends Resource
class_name GhostData

## Ghost数据结构
## 保存死亡玩家的职业、武器等信息，用于救援复活

## 职业ID
@export var class_id: String = ""

## 武器列表 [{id: "sword", level: 3}, ...]
@export var weapons: Array = []

## 死亡次数（本局第几次死亡）
@export var death_count: int = 0

## 死亡位置（用于墓碑位置）
@export var death_position: Vector2 = Vector2.ZERO

## 从玩家创建Ghost数据
static func from_player(player: CharacterBody2D, death_count: int) -> GhostData:
	var data = GhostData.new()
	
	# 保存职业ID（通过查找匹配的ClassData来获取ID）
	if player.current_class:
		data.class_id = _find_class_id(player.current_class)
	else:
		data.class_id = "balanced"  # 默认职业
	
	# 如果找不到匹配的职业ID，使用GameMain中保存的
	if data.class_id == "":
		data.class_id = GameMain.selected_class_id if "selected_class_id" in GameMain else "balanced"
	
	# 保存武器列表
	data.weapons = []
	var weapons_node = player.get_node_or_null("now_weapons")
	if weapons_node:
		for weapon in weapons_node.get_children():
			if weapon.has_method("get_weapon_data"):
				var weapon_data = weapon.get_weapon_data()
				if weapon_data:
					data.weapons.append({
						"id": weapon_data.id,
						"level": weapon.get("weapon_level") if "weapon_level" in weapon else 1
					})
	
	# 保存死亡信息
	data.death_count = death_count
	data.death_position = player.global_position
	
	return data

## 查找ClassData对应的ID（内部辅助方法）
static func _find_class_id(class_data: ClassData) -> String:
	# 遍历ClassDatabase中的所有职业，找到匹配的
	for class_id in ClassDatabase.classes.keys():
		if ClassDatabase.classes[class_id] == class_data:
			return class_id
	
	# 如果找不到，尝试通过名称匹配
	for class_id in ClassDatabase.classes.keys():
		var stored_class = ClassDatabase.classes[class_id]
		if stored_class.name == class_data.name:
			return class_id
	
	return ""  # 找不到时返回空字符串

## 获取武器描述文本（用于UI显示）
func get_weapons_description() -> String:
	if weapons.is_empty():
		return "无武器"
	
	var desc = ""
	for i in range(weapons.size()):
		var weapon = weapons[i]
		var weapon_data = WeaponDatabase.get_weapon(weapon.id)
		if weapon_data:
			desc += weapon_data.name + " Lv." + str(weapon.level)
			if i < weapons.size() - 1:
				desc += ", "
	
	return desc

## 获取职业名称（用于UI显示）
func get_class_name() -> String:
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data:
		return class_data.name
	return "未知职业"
