extends Resource
class_name UpgradeData

## 升级选项数据

enum UpgradeType {
	HP_MAX,          # HP上限+50
	MOVE_SPEED,      # 移动速度+10
	HEAL_HP,         # 恢复HP100点
	NEW_WEAPON,      # 新武器
	WEAPON_LEVEL_UP  # 武器等级+1
}

@export var upgrade_type: UpgradeType = UpgradeType.HP_MAX
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 5
@export var icon_path: String = ""
@export var weapon_id: String = ""  # 仅用于NEW_WEAPON和WEAPON_LEVEL_UP

func _init(
	p_type: UpgradeType = UpgradeType.HP_MAX,
	p_name: String = "",
	p_cost: int = 5,
	p_icon_path: String = "",
	p_weapon_id: String = ""
) -> void:
	upgrade_type = p_type
	name = p_name
	cost = p_cost
	icon_path = p_icon_path
	weapon_id = p_weapon_id

