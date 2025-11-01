extends Node
class_name UpgradeDatabase

## 升级数据库
## 预定义各种升级选项及其属性

static var upgrades: Dictionary = {}

## 初始化所有基础升级选项
static func initialize_upgrades() -> void:
	if not upgrades.is_empty():
		return
	
	# 1. HP上限+50
	var hp_max_upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.HP_MAX,
		"HP上限+50",
		5,
		"res://assets/skillicon/6.png"
	)
	hp_max_upgrade.description = "增加50点最大生命值"
	upgrades["hp_max"] = hp_max_upgrade
	
	# 2. 移动速度+10
	var move_speed_upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.MOVE_SPEED,
		"移动速度+10",
		5,
		"res://assets/skillicon/11.png"
	)
	move_speed_upgrade.description = "增加10点移动速度"
	upgrades["move_speed"] = move_speed_upgrade
	
	# 3. 恢复HP100点
	var heal_hp_upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.HEAL_HP,
		"恢复HP100点",
		3,
		"res://assets/items/5.png"
	)
	heal_hp_upgrade.description = "立即恢复100点生命值"
	upgrades["heal_hp"] = heal_hp_upgrade
	
	# 可以在这里添加更多基础升级选项
	# 例如：
	# var attack_damage_upgrade = UpgradeData.new(
	# 	UpgradeData.UpgradeType.ATTACK_DAMAGE,
	# 	"攻击力+10",
	# 	8,
	# 	"res://assets/items/xxx.png"
	# )
	# attack_damage_upgrade.description = "永久增加10点攻击力"
	# upgrades["attack_damage"] = attack_damage_upgrade

## 获取基础升级数据
static func get_upgrade_data(upgrade_id: String) -> UpgradeData:
	if upgrades.is_empty():
		initialize_upgrades()
	return upgrades.get(upgrade_id, null)

## 获取所有基础升级ID（不包括动态生成的）
static func get_all_upgrade_ids() -> Array:
	if upgrades.is_empty():
		initialize_upgrades()
	return upgrades.keys()

## 获取指定类型的所有基础升级
static func get_upgrades_by_type(type: UpgradeData.UpgradeType) -> Array[UpgradeData]:
	if upgrades.is_empty():
		initialize_upgrades()
	
	var result: Array[UpgradeData] = []
	for upgrade_id in upgrades.keys():
		var upgrade = upgrades[upgrade_id]
		if upgrade and upgrade.upgrade_type == type:
			result.append(upgrade)
	return result
