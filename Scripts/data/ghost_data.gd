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
		print("[GhostData] 玩家职业:", player.current_class.name, " -> ID:", data.class_id)
	else:
		data.class_id = "balanced"  # 默认职业
		print("[GhostData] 玩家无职业，使用默认: balanced")
	
	# 如果找不到匹配的职业ID，使用GameMain中保存的
	if data.class_id == "":
		data.class_id = GameMain.selected_class_id if "selected_class_id" in GameMain else "balanced"
		print("[GhostData] 职业ID为空，使用GameMain.selected_class_id:", data.class_id)
	
	# 保存武器列表
	data.weapons = []
	var weapons_node = player.get_node_or_null("now_weapons")
	if weapons_node:
		print("[GhostData] 检查玩家武器节点，子节点数量:", weapons_node.get_child_count())
		for weapon in weapons_node.get_children():
			# 尝试获取weapon_data属性
			var weapon_data_obj = weapon.get("weapon_data") if "weapon_data" in weapon else null
			var weapon_level_val = weapon.get("weapon_level") if "weapon_level" in weapon else 1
			
			if weapon_data_obj:
				# 通过WeaponData反向查找ID
				var weapon_id = _find_weapon_id(weapon_data_obj)
				if weapon_id != "":
					data.weapons.append({
						"id": weapon_id,
						"level": weapon_level_val
					})
					print("[GhostData] 记录武器: ", weapon_id, " (", weapon_data_obj.weapon_name, ") Lv.", weapon_level_val)
				else:
					print("[GhostData] 找不到武器ID:", weapon_data_obj.weapon_name)
			else:
				print("[GhostData] 武器无weapon_data:", weapon)
	else:
		print("[GhostData] 找不到now_weapons节点")
	
	print("[GhostData] 总共记录武器数量:", data.weapons.size())
	
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

## 查找WeaponData对应的ID（内部辅助方法）
static func _find_weapon_id(weapon_data: WeaponData) -> String:
	# 遍历WeaponDatabase中的所有武器，找到匹配的
	var all_weapon_ids = WeaponDatabase.get_all_weapon_ids()
	for weapon_id in all_weapon_ids:
		var stored_weapon = WeaponDatabase.get_weapon(weapon_id)
		if stored_weapon == weapon_data:
			return weapon_id
	
	# 如果引用匹配失败，尝试通过名称匹配
	for weapon_id in all_weapon_ids:
		var stored_weapon = WeaponDatabase.get_weapon(weapon_id)
		if stored_weapon.weapon_name == weapon_data.weapon_name:
			return weapon_id
	
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
			desc += weapon_data.weapon_name + " Lv." + str(weapon.level)
			if i < weapons.size() - 1:
				desc += ", "
	
	return desc

## 获取职业名称（用于UI显示）
func get_class_name() -> String:
	var class_data = ClassDatabase.get_class_data(class_id)
	if class_data:
		return class_data.name
	return "未知职业"
