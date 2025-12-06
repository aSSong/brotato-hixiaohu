extends Resource
class_name UpgradeData

## 升级选项数据（重构版）
## 
## 使用新的CombatStats系统表示属性变化
## 保留旧的attribute_changes字段以兼容现有代码

## 品质等级枚举
enum Quality {
	WHITE = 1,    # 白色 - 普通（Common）
	GREEN = 2,    # 绿色 - 优秀（Uncommon）
	BLUE = 3,     # 蓝色 - 稀有（Rare）
	PURPLE = 4,   # 紫色 - 史诗（Epic）
	ORANGE = 5    # 橙色 - 传奇（Legendary）
}

enum UpgradeType {
	HP_MAX,          # HP上限+50
	MOVE_SPEED,      # 移动速度+10
	HEAL_HP,         # 恢复HP100点
	NEW_WEAPON,      # 新武器
	WEAPON_LEVEL_UP, # 武器等级+1
	
	# 战斗属性
	DAMAGE_REDUCTION,  # 减伤+10%
	LUCK,              # 幸运+10
	
	# 武器通用
	ATTACK_SPEED,      # 攻击速度+10%
	
	# 近战武器
	MELEE_DAMAGE,      # 近战伤害+10%
	MELEE_RANGE,       # 近战范围+10%
	MELEE_SPEED,       # 近战速度+10%
	MELEE_KNOCKBACK,   # 近战击退+10%
	
	# 远程武器
	RANGED_DAMAGE,     # 远程伤害+10%
	RANGED_RANGE,      # 远程范围+10%
	RANGED_SPEED,      # 远程速度+10%
	
	# 魔法武器
	MAGIC_DAMAGE,      # 魔法伤害+10%
	MAGIC_RANGE,       # 魔法范围+10%
	MAGIC_SPEED,       # 魔法速度+10%
	MAGIC_EXPLOSION,   # 魔法爆炸范围+10%
}

@export var upgrade_type: UpgradeType = UpgradeType.HP_MAX
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 5  # 基础价格（用于非武器升级）
@export var icon_path: String = ""
@export var weapon_id: String = ""  # 仅用于NEW_WEAPON和WEAPON_LEVEL_UP

## 品质相关（运行时动态设置）
@export var quality: int = Quality.WHITE  # 品质等级
@export var base_cost: int = 5  # 武器升级的基础价格
@export var actual_cost: int = 5  # 实际价格（根据品质计算或使用cost）
@export var locked_cost: int = -1  # 锁定时的价格（-1表示未锁定）
@export var current_price: int = -1  # 当前波次下的最终售价（包含波次修正，生成时确定）
@export var weight: int = 100  # 出现权重（用于加权随机，默认100，权重越高越容易出现）

## 自定义值（用于特殊效果，如HEAL_HP的恢复量）
@export var custom_value: float = 0.0

## 新属性系统：使用CombatStats表示属性变化
@export var stats_modifier: CombatStats = null

## 旧属性系统（已废弃，保留以兼容）
## 格式：{"attribute_name": {"op": "add|multiply", "value": number}}
var attribute_changes: Dictionary = {}

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
	
	# 初始化品质和价格
	quality = Quality.WHITE
	actual_cost = cost
	weight = 100  # 默认权重100
	
	# 初始化新属性系统
	stats_modifier = CombatStats.new()
	# ⭐ 清零默认值，防止污染
	stats_modifier.max_hp = 0
	stats_modifier.speed = 0.0
	stats_modifier.crit_damage = 0.0
	attribute_changes = {}

## 创建AttributeModifier
## 
## 将这个升级数据转换为可以应用到AttributeManager的修改器
## 
## @return 属性修改器
func create_modifier() -> AttributeModifier:
	var modifier = AttributeModifier.new()
	modifier.modifier_type = AttributeModifier.ModifierType.UPGRADE
	
	if not stats_modifier:
		push_warning("[UpgradeData] 警告：stats_modifier 为 null！(Name: %s)" % name)
	
	modifier.stats_delta = stats_modifier
	modifier.modifier_id = "upgrade_" + name
	return modifier

## 创建副本
func clone(subresources: bool = false) -> UpgradeData:
	var copy = UpgradeData.new(
		upgrade_type,
		name,
		cost,
		icon_path,
		weapon_id
	)
	copy.description = description
	copy.quality = quality
	copy.base_cost = base_cost
	copy.actual_cost = actual_cost
	copy.locked_cost = locked_cost
	copy.current_price = current_price
	copy.weight = weight
	copy.custom_value = custom_value
	
	# 复制旧属性系统字典
	copy.attribute_changes = attribute_changes.duplicate(true)
	
	# 复制新属性系统数据
	if stats_modifier:
		# 假设 CombatStats 也有 clone() 或类似方法，或者如果是 Resource 可以用 duplicate()
		if stats_modifier.has_method("clone"):
			copy.stats_modifier = stats_modifier.clone()
		else:
			copy.stats_modifier = stats_modifier.duplicate(subresources)
	
	return copy

## 获取品质价格倍率
static func get_quality_price_multiplier(quality_level: int) -> float:
	match quality_level:
		Quality.WHITE: return 1.0    # 1x（基础属性用）
		Quality.GREEN: return 2.0    # 1x（1级→2级）
		Quality.BLUE: return 4.0     # 2x（2级→3级）
		Quality.PURPLE: return 8.0   # 4x（3级→4级）
		Quality.ORANGE: return 16.0   # 8x（4级→5级）
		_: return 1.0

## 计算武器升级的实际价格（根据品质）
func calculate_weapon_upgrade_cost() -> void:
	actual_cost = int(base_cost * get_quality_price_multiplier(quality))

## 设置基础属性升级价格（使用配置的cost）
func set_base_attribute_cost() -> void:
	actual_cost = cost

## 获取品质颜色（复用 weapon 的颜色规则）
static func get_quality_color(quality_level: int) -> Color:
	match quality_level:
		Quality.WHITE: return Color("#FFFFFF")   # 白色
		Quality.GREEN: return Color("#00FF00")   # 绿色
		Quality.BLUE: return Color("#0000FF")    # 蓝色（与 weapon level_3 一致）
		Quality.PURPLE: return Color("#FF00FF")  # 紫色（与 weapon level_4 一致）
		Quality.ORANGE: return Color("#FF0000")  # 红色/橙色（与 weapon level_5 一致）
		_: return Color.WHITE

## 获取品质名称
static func get_quality_name(quality_level: int) -> String:
	match quality_level:
		Quality.WHITE: return "普通"
		Quality.GREEN: return "优秀"
		Quality.BLUE: return "稀有"
		Quality.PURPLE: return "史诗"
		Quality.ORANGE: return "传奇"
		_: return "未知"
