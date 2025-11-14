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
		"res://assets/skillicon/5.png"
	)
	heal_hp_upgrade.description = "立即恢复100点生命值"
	upgrades["heal_hp"] = heal_hp_upgrade
	
	# === 战斗属性 ===
	# 4. 减伤+10%
	var damage_reduction = UpgradeData.new(
		UpgradeData.UpgradeType.DAMAGE_REDUCTION,
		"减伤+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	damage_reduction.description = "受到的伤害降低10%"
	upgrades["damage_reduction"] = damage_reduction
	
	# 5. 幸运+10
	var luck = UpgradeData.new(
		UpgradeData.UpgradeType.LUCK,
		"幸运+10",
		5,
		"res://assets/skillicon/10.png"
	)
	luck.description = "增加10点幸运值（未来影响掉落）"
	upgrades["luck"] = luck
	
	# === 武器通用 ===
	# 6. 攻击速度+10%
	var attack_speed = UpgradeData.new(
		UpgradeData.UpgradeType.ATTACK_SPEED,
		"攻击速度+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	attack_speed.description = "所有武器攻击速度提升10%"
	upgrades["attack_speed"] = attack_speed
	
	# === 近战武器 ===
	# 7. 近战伤害+10%
	var melee_damage = UpgradeData.new(
		UpgradeData.UpgradeType.MELEE_DAMAGE,
		"近战伤害+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	melee_damage.description = "近战武器伤害提升10%"
	upgrades["melee_damage"] = melee_damage
	
	# 8. 近战范围+10%
	var melee_range = UpgradeData.new(
		UpgradeData.UpgradeType.MELEE_RANGE,
		"近战范围+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	melee_range.description = "近战武器攻击范围提升10%"
	upgrades["melee_range"] = melee_range
	
	# 9. 近战速度+10%
	var melee_speed = UpgradeData.new(
		UpgradeData.UpgradeType.MELEE_SPEED,
		"近战速度+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	melee_speed.description = "近战武器攻击速度提升10%"
	upgrades["melee_speed"] = melee_speed
	
	# 10. 近战击退+10%
	var melee_knockback = UpgradeData.new(
		UpgradeData.UpgradeType.MELEE_KNOCKBACK,
		"近战击退+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	melee_knockback.description = "近战武器击退效果提升10%"
	upgrades["melee_knockback"] = melee_knockback
	
	# === 远程武器 ===
	# 11. 远程伤害+10%
	var ranged_damage = UpgradeData.new(
		UpgradeData.UpgradeType.RANGED_DAMAGE,
		"远程伤害+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	ranged_damage.description = "远程武器伤害提升10%"
	upgrades["ranged_damage"] = ranged_damage
	
	# 12. 远程范围+10%
	var ranged_range = UpgradeData.new(
		UpgradeData.UpgradeType.RANGED_RANGE,
		"远程范围+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	ranged_range.description = "远程武器攻击范围提升10%"
	upgrades["ranged_range"] = ranged_range
	
	# 13. 远程速度+10%
	var ranged_speed = UpgradeData.new(
		UpgradeData.UpgradeType.RANGED_SPEED,
		"远程速度+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	ranged_speed.description = "远程武器攻击速度提升10%"
	upgrades["ranged_speed"] = ranged_speed
	
	# === 魔法武器 ===
	# 14. 魔法伤害+10%
	var magic_damage = UpgradeData.new(
		UpgradeData.UpgradeType.MAGIC_DAMAGE,
		"魔法伤害+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	magic_damage.description = "魔法武器伤害提升10%"
	upgrades["magic_damage"] = magic_damage
	
	# 15. 魔法范围+10%
	var magic_range = UpgradeData.new(
		UpgradeData.UpgradeType.MAGIC_RANGE,
		"魔法范围+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	magic_range.description = "魔法武器攻击范围提升10%"
	upgrades["magic_range"] = magic_range
	
	# 16. 魔法速度+10%
	var magic_speed = UpgradeData.new(
		UpgradeData.UpgradeType.MAGIC_SPEED,
		"魔法速度+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	magic_speed.description = "魔法武器攻击速度提升10%（冷却降低）"
	upgrades["magic_speed"] = magic_speed
	
	# 17. 魔法爆炸范围+10%
	var magic_explosion = UpgradeData.new(
		UpgradeData.UpgradeType.MAGIC_EXPLOSION,
		"爆炸范围+10%",
		5,
		"res://assets/skillicon/10.png"
	)
	magic_explosion.description = "魔法武器爆炸范围提升10%"
	upgrades["magic_explosion"] = magic_explosion
	
	# === 设置所有基础属性升级的品质和价格 ===
	for upgrade_id in upgrades.keys():
		var upgrade = upgrades[upgrade_id]
		# 基础属性升级（非武器）都设置为白色品质
		if upgrade.upgrade_type != UpgradeData.UpgradeType.NEW_WEAPON and \
		   upgrade.upgrade_type != UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			upgrade.quality = UpgradeData.Quality.WHITE
			upgrade.set_base_attribute_cost()
			print("[UpgradeDatabase] 设置 %s 为白色品质，价格=%d" % [upgrade.name, upgrade.actual_cost])

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
