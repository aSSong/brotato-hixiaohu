extends Node
class_name UpgradeDatabase

## 升级数据库
## 预定义各种升级选项及其属性

static var upgrades: Dictionary = {}




## 初始化所有基础升级选项
static func initialize_upgrades() -> void:
	if not upgrades.is_empty():
		return
	
	# 价格系数设置
	var base_cost: int = 5
	var tier_multipliers: Array = [1, 2, 4, 8, 16]  # 5个品质的价格系数
	var tier_qualities: Array = [
		UpgradeData.Quality.WHITE,
		UpgradeData.Quality.GREEN,
		UpgradeData.Quality.BLUE,
		UpgradeData.Quality.PURPLE,
		UpgradeData.Quality.ORANGE
	]
	
	# 数值梯度定义
	# S级：攻击速度（通用性最强）
	var s_tier_values: Array = [1.03, 1.05, 1.08, 1.12, 1.18]  # +3%, +5%, +8%, +12%, +18%
	# A级：伤害、减伤（大类通用）
	var a_tier_values: Array = [1.05, 1.10, 1.15, 1.22, 1.35]  # +5%, +10%, +15%, +22%, +35%
	# B级：单类速度、范围（功能性）
	var b_tier_values: Array = [1.08, 1.15, 1.25, 1.35, 1.50]  # +8%, +15%, +25%, +35%, +50%
	# C级：特殊效果
	var c_tier_values: Array = [1.12, 1.20, 1.35, 1.50, 1.70]  # +12%, +20%, +35%, +50%, +70%
	
	# 固定值梯度
	var hp_max_values: Array = [5, 10, 20, 30, 50]
	var move_speed_values: Array = [5, 10, 15, 25, 40]
	var luck_values: Array = [5, 10, 20, 30, 50]
	
	# 减伤需要特殊处理（是减少受到的伤害）
	var damage_reduction_values: Array = [0.95, 0.90, 0.85, 0.78, 0.65]  # 受伤减少5%, 10%, 15%, 22%, 35%
	
	# === 1. 恢复HP（保持单一项目）===
	var heal_hp_upgrade = UpgradeData.new(
		UpgradeData.UpgradeType.HEAL_HP,
		"恢复HP10点",
		base_cost,
		"res://assets/skillicon/5.png"
	)
	heal_hp_upgrade.description = "立即恢复10点生命值"
	heal_hp_upgrade.quality = UpgradeData.Quality.WHITE
	heal_hp_upgrade.set_base_attribute_cost()
	upgrades["heal_hp"] = heal_hp_upgrade
	
	# === 2. HP上限（5个品质）===
	for tier in range(5):
		var hp_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.HP_MAX,
			"HP上限+%d" % hp_max_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/6.png"
		)
		hp_upgrade.description = "增加%d点最大生命值" % hp_max_values[tier]
		hp_upgrade.attribute_changes = {
			"max_hp": {"op": "add", "value": hp_max_values[tier]}
		}
		hp_upgrade.quality = tier_qualities[tier]
		hp_upgrade.set_base_attribute_cost()
		upgrades["hp_max_tier%d" % (tier + 1)] = hp_upgrade
	
	# === 3. 移动速度（5个品质）===
	for tier in range(5):
		var speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MOVE_SPEED,
			"移动速度+%d" % move_speed_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/11.png"
		)
		speed_upgrade.description = "增加%d点移动速度" % move_speed_values[tier]
		speed_upgrade.attribute_changes = {
			"speed": {"op": "add", "value": move_speed_values[tier]}
		}
		speed_upgrade.quality = tier_qualities[tier]
		speed_upgrade.set_base_attribute_cost()
		upgrades["move_speed_tier%d" % (tier + 1)] = speed_upgrade
	
	# === 4. 攻击速度（S级，5个品质）===
	for tier in range(5):
		var percentage: int = int((s_tier_values[tier] - 1.0) * 100)
		var attack_speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.ATTACK_SPEED,
			"攻击速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		attack_speed_upgrade.description = "所有武器攻击速度提升%d%%" % percentage
		attack_speed_upgrade.attribute_changes = {
			"attack_speed_multiplier": {"op": "multiply", "value": s_tier_values[tier]}
		}
		attack_speed_upgrade.quality = tier_qualities[tier]
		attack_speed_upgrade.set_base_attribute_cost()
		upgrades["attack_speed_tier%d" % (tier + 1)] = attack_speed_upgrade
	
	# === 5. 减伤（A级，5个品质）===
	for tier in range(5):
		var percentage: int = int((1.0 - damage_reduction_values[tier]) * 100)
		var damage_reduction_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.DAMAGE_REDUCTION,
			"减伤+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		damage_reduction_upgrade.description = "受到的伤害降低%d%%" % percentage
		damage_reduction_upgrade.attribute_changes = {
			"damage_reduction_multiplier": {"op": "multiply", "value": damage_reduction_values[tier]}
		}
		damage_reduction_upgrade.quality = tier_qualities[tier]
		damage_reduction_upgrade.set_base_attribute_cost()
		upgrades["damage_reduction_tier%d" % (tier + 1)] = damage_reduction_upgrade
	
	# === 6. 近战伤害（A级，5个品质）===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var melee_damage_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_DAMAGE,
			"近战伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		melee_damage_upgrade.description = "近战武器伤害提升%d%%" % percentage
		melee_damage_upgrade.attribute_changes = {
			"melee_damage_multiplier": {"op": "multiply", "value": a_tier_values[tier]}
		}
		melee_damage_upgrade.quality = tier_qualities[tier]
		melee_damage_upgrade.set_base_attribute_cost()
		upgrades["melee_damage_tier%d" % (tier + 1)] = melee_damage_upgrade
	
	# === 7. 远程伤害（A级，5个品质）===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var ranged_damage_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_DAMAGE,
			"远程伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		ranged_damage_upgrade.description = "远程武器伤害提升%d%%" % percentage
		ranged_damage_upgrade.attribute_changes = {
			"ranged_damage_multiplier": {"op": "multiply", "value": a_tier_values[tier]}
		}
		ranged_damage_upgrade.quality = tier_qualities[tier]
		ranged_damage_upgrade.set_base_attribute_cost()
		upgrades["ranged_damage_tier%d" % (tier + 1)] = ranged_damage_upgrade
	
	# === 8. 魔法伤害（A级，5个品质）===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var magic_damage_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_DAMAGE,
			"魔法伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		magic_damage_upgrade.description = "魔法武器伤害提升%d%%" % percentage
		magic_damage_upgrade.attribute_changes = {
			"magic_damage_multiplier": {"op": "multiply", "value": a_tier_values[tier]}
		}
		magic_damage_upgrade.quality = tier_qualities[tier]
		magic_damage_upgrade.set_base_attribute_cost()
		upgrades["magic_damage_tier%d" % (tier + 1)] = magic_damage_upgrade
	
	# === 9. 近战速度（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var melee_speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_SPEED,
			"近战速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		melee_speed_upgrade.description = "近战武器攻击速度提升%d%%" % percentage
		melee_speed_upgrade.attribute_changes = {
			"melee_speed_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		melee_speed_upgrade.quality = tier_qualities[tier]
		melee_speed_upgrade.set_base_attribute_cost()
		upgrades["melee_speed_tier%d" % (tier + 1)] = melee_speed_upgrade
	
	# === 10. 远程速度（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var ranged_speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_SPEED,
			"远程速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		ranged_speed_upgrade.description = "远程武器攻击速度提升%d%%" % percentage
		ranged_speed_upgrade.attribute_changes = {
			"ranged_speed_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		ranged_speed_upgrade.quality = tier_qualities[tier]
		ranged_speed_upgrade.set_base_attribute_cost()
		upgrades["ranged_speed_tier%d" % (tier + 1)] = ranged_speed_upgrade
	
	# === 11. 魔法速度（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var magic_speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_SPEED,
			"魔法速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		magic_speed_upgrade.description = "魔法武器攻击速度提升%d%%（冷却降低）" % percentage
		magic_speed_upgrade.attribute_changes = {
			"magic_speed_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		magic_speed_upgrade.quality = tier_qualities[tier]
		magic_speed_upgrade.set_base_attribute_cost()
		upgrades["magic_speed_tier%d" % (tier + 1)] = magic_speed_upgrade
	
	# === 12. 近战范围（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var melee_range_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_RANGE,
			"近战范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		melee_range_upgrade.description = "近战武器攻击范围提升%d%%" % percentage
		melee_range_upgrade.attribute_changes = {
			"melee_range_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		melee_range_upgrade.quality = tier_qualities[tier]
		melee_range_upgrade.set_base_attribute_cost()
		upgrades["melee_range_tier%d" % (tier + 1)] = melee_range_upgrade
	
	# === 13. 远程范围（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var ranged_range_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_RANGE,
			"远程范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		ranged_range_upgrade.description = "远程武器攻击范围提升%d%%" % percentage
		ranged_range_upgrade.attribute_changes = {
			"ranged_range_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		ranged_range_upgrade.quality = tier_qualities[tier]
		ranged_range_upgrade.set_base_attribute_cost()
		upgrades["ranged_range_tier%d" % (tier + 1)] = ranged_range_upgrade
	
	# === 14. 魔法范围（B级，5个品质）===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var magic_range_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_RANGE,
			"魔法范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		magic_range_upgrade.description = "魔法武器攻击范围提升%d%%" % percentage
		magic_range_upgrade.attribute_changes = {
			"magic_range_multiplier": {"op": "multiply", "value": b_tier_values[tier]}
		}
		magic_range_upgrade.quality = tier_qualities[tier]
		magic_range_upgrade.set_base_attribute_cost()
		upgrades["magic_range_tier%d" % (tier + 1)] = magic_range_upgrade
	
	# === 15. 近战击退（C级，5个品质）===
	for tier in range(5):
		var percentage: int = int((c_tier_values[tier] - 1.0) * 100)
		var melee_knockback_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_KNOCKBACK,
			"近战击退+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		melee_knockback_upgrade.description = "近战武器击退效果提升%d%%" % percentage
		melee_knockback_upgrade.attribute_changes = {
			"melee_knockback_multiplier": {"op": "multiply", "value": c_tier_values[tier]}
		}
		melee_knockback_upgrade.quality = tier_qualities[tier]
		melee_knockback_upgrade.set_base_attribute_cost()
		upgrades["melee_knockback_tier%d" % (tier + 1)] = melee_knockback_upgrade
	
	# === 16. 魔法爆炸范围（C级，5个品质）===
	for tier in range(5):
		var percentage: int = int((c_tier_values[tier] - 1.0) * 100)
		var magic_explosion_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_EXPLOSION,
			"爆炸范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		magic_explosion_upgrade.description = "魔法武器爆炸范围提升%d%%" % percentage
		magic_explosion_upgrade.attribute_changes = {
			"magic_explosion_radius_multiplier": {"op": "multiply", "value": c_tier_values[tier]}
		}
		magic_explosion_upgrade.quality = tier_qualities[tier]
		magic_explosion_upgrade.set_base_attribute_cost()
		upgrades["magic_explosion_tier%d" % (tier + 1)] = magic_explosion_upgrade
	
	# === 17. 幸运（固定值，5个品质）===
	for tier in range(5):
		var luck_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.LUCK,
			"幸运+%d" % luck_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		luck_upgrade.description = "增加%d点幸运值（未来影响掉落）" % luck_values[tier]
		luck_upgrade.attribute_changes = {
			"luck": {"op": "add", "value": luck_values[tier]}
		}
		luck_upgrade.quality = tier_qualities[tier]
		luck_upgrade.set_base_attribute_cost()
		upgrades["luck_tier%d" % (tier + 1)] = luck_upgrade

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
