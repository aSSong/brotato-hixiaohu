@tool
extends EditorScript

## 升级数据修复工具
## 
## 重新生成所有升级资源文件（修复 stats_modifier 未保存的问题）
## 包含完整的硬编码数据定义

func _run():
	print("=== 开始修复升级数据 ===")
	
	var upgrades = {}
	
	# 价格系数设置
	var base_cost: int = 3
	var tier_multipliers: Array = [1, 2, 4, 8, 16]
	var tier_qualities: Array = [
		UpgradeData.Quality.WHITE,
		UpgradeData.Quality.GREEN,
		UpgradeData.Quality.BLUE,
		UpgradeData.Quality.PURPLE,
		UpgradeData.Quality.ORANGE
	]
	
	# 数值梯度定义
	var s_tier_values: Array = [1.03, 1.05, 1.08, 1.12, 1.18]
	var a_tier_values: Array = [1.05, 1.10, 1.15, 1.22, 1.35]
	var b_tier_values: Array = [1.08, 1.15, 1.25, 1.35, 1.50]
	var c_tier_values: Array = [1.12, 1.20, 1.35, 1.50, 1.70]
	
	var hp_max_values: Array = [5, 10, 20, 30, 50]
	var move_speed_values: Array = [5, 10, 15, 25, 40]
	var luck_values: Array = [5, 10, 20, 30, 50]
	var damage_reduction_values: Array = [0.95, 0.90, 0.85, 0.78, 0.65]
	
	# === 辅助函数：创建干净的 Stats ===
	var create_clean_stats = func() -> CombatStats:
		var stats = CombatStats.new()
		stats.max_hp = 0
		stats.speed = 0.0
		stats.defense = 0
		stats.luck = 0.0
		stats.crit_chance = 0.0
		stats.crit_damage = 0.0
		stats.damage_reduction = 0.0
		return stats
	
	# === 1. 恢复HP ===
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
	
	# === 2. HP上限 ===
	for tier in range(5):
		var hp_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.HP_MAX,
			"HP上限+%d" % hp_max_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/6.png"
		)
		hp_upgrade.description = "增加%d点最大生命值" % hp_max_values[tier]
		var stats = create_clean_stats.call()
		stats.max_hp = hp_max_values[tier]
		hp_upgrade.stats_modifier = stats
		hp_upgrade.quality = tier_qualities[tier]
		hp_upgrade.set_base_attribute_cost()
		upgrades["hp_max_tier%d" % (tier + 1)] = hp_upgrade
	
	# === 3. 移动速度 ===
	for tier in range(5):
		var speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MOVE_SPEED,
			"移动速度+%d" % move_speed_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/11.png"
		)
		speed_upgrade.description = "增加%d点移动速度" % move_speed_values[tier]
		var stats = create_clean_stats.call()
		stats.speed = move_speed_values[tier]
		speed_upgrade.stats_modifier = stats
		speed_upgrade.quality = tier_qualities[tier]
		speed_upgrade.set_base_attribute_cost()
		upgrades["move_speed_tier%d" % (tier + 1)] = speed_upgrade
	
	# === 4. 攻击速度 ===
	for tier in range(5):
		var percentage: int = int((s_tier_values[tier] - 1.0) * 100)
		var attack_speed_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.ATTACK_SPEED,
			"攻击速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		attack_speed_upgrade.description = "所有武器攻击速度提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.global_attack_speed_mult = s_tier_values[tier]
		attack_speed_upgrade.stats_modifier = stats
		attack_speed_upgrade.quality = tier_qualities[tier]
		attack_speed_upgrade.set_base_attribute_cost()
		upgrades["attack_speed_tier%d" % (tier + 1)] = attack_speed_upgrade
	
	# === 5. 减伤 ===
	for tier in range(5):
		var percentage: int = int((1.0 - damage_reduction_values[tier]) * 100)
		var damage_reduction_upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.DAMAGE_REDUCTION,
			"减伤+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		damage_reduction_upgrade.description = "受到的伤害降低%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.damage_reduction = 1.0 - damage_reduction_values[tier]
		damage_reduction_upgrade.stats_modifier = stats
		damage_reduction_upgrade.quality = tier_qualities[tier]
		damage_reduction_upgrade.set_base_attribute_cost()
		upgrades["damage_reduction_tier%d" % (tier + 1)] = damage_reduction_upgrade
	
	# === 6. 近战伤害 ===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_DAMAGE,
			"近战伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "近战武器伤害提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.melee_damage_mult = a_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["melee_damage_tier%d" % (tier + 1)] = upgrade
	
	# === 7. 远程伤害 ===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_DAMAGE,
			"远程伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "远程武器伤害提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.ranged_damage_mult = a_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["ranged_damage_tier%d" % (tier + 1)] = upgrade
	
	# === 8. 魔法伤害 ===
	for tier in range(5):
		var percentage: int = int((a_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_DAMAGE,
			"魔法伤害+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "魔法武器伤害提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.magic_damage_mult = a_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["magic_damage_tier%d" % (tier + 1)] = upgrade
	
	# === 9. 近战速度 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_SPEED,
			"近战速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "近战武器攻击速度提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.melee_speed_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["melee_speed_tier%d" % (tier + 1)] = upgrade
	
	# === 10. 远程速度 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_SPEED,
			"远程速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "远程武器攻击速度提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.ranged_speed_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["ranged_speed_tier%d" % (tier + 1)] = upgrade
	
	# === 11. 魔法速度 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_SPEED,
			"魔法速度+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "魔法武器攻击速度提升%d%%（冷却降低）" % percentage
		var stats = create_clean_stats.call()
		stats.magic_speed_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["magic_speed_tier%d" % (tier + 1)] = upgrade
	
	# === 12. 近战范围 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_RANGE,
			"近战范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "近战武器攻击范围提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.melee_range_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["melee_range_tier%d" % (tier + 1)] = upgrade
	
	# === 13. 远程范围 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.RANGED_RANGE,
			"远程范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "远程武器攻击范围提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.ranged_range_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["ranged_range_tier%d" % (tier + 1)] = upgrade
	
	# === 14. 魔法范围 ===
	for tier in range(5):
		var percentage: int = int((b_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_RANGE,
			"魔法范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "魔法武器攻击范围提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.magic_range_mult = b_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["magic_range_tier%d" % (tier + 1)] = upgrade
	
	# === 15. 近战击退 ===
	for tier in range(5):
		var percentage: int = int((c_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MELEE_KNOCKBACK,
			"近战击退+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "近战武器击退效果提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.melee_knockback_mult = c_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["melee_knockback_tier%d" % (tier + 1)] = upgrade
	
	# === 16. 魔法爆炸范围 ===
	for tier in range(5):
		var percentage: int = int((c_tier_values[tier] - 1.0) * 100)
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.MAGIC_EXPLOSION,
			"爆炸范围+%d%%" % percentage,
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "魔法武器爆炸范围提升%d%%" % percentage
		var stats = create_clean_stats.call()
		stats.magic_explosion_radius_mult = c_tier_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["magic_explosion_tier%d" % (tier + 1)] = upgrade
	
	# === 17. 幸运 ===
	for tier in range(5):
		var upgrade = UpgradeData.new(
			UpgradeData.UpgradeType.LUCK,
			"幸运+%d" % luck_values[tier],
			base_cost * tier_multipliers[tier],
			"res://assets/skillicon/10.png"
		)
		upgrade.description = "增加%d点幸运值（未来影响掉落）" % luck_values[tier]
		var stats = create_clean_stats.call()
		stats.luck = luck_values[tier]
		upgrade.stats_modifier = stats
		upgrade.quality = tier_qualities[tier]
		upgrade.set_base_attribute_cost()
		upgrades["luck_tier%d" % (tier + 1)] = upgrade
	
	# === 保存所有资源 ===
	print("找到 %d 个升级项目，开始保存..." % upgrades.size())
	
	var root_dir = "res://resources/upgrades"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(root_dir):
		dir.make_dir_recursive(root_dir)
	
	var success_count = 0
	for id in upgrades:
		var data: UpgradeData = upgrades[id]
		
		# 根据类型创建子文件夹
		var type_name = UpgradeData.UpgradeType.keys()[data.upgrade_type].to_lower()
		var folder = "res://resources/upgrades/%s" % type_name
		
		if not dir.dir_exists(folder):
			dir.make_dir_recursive(folder)
		
		# 构建文件名
		var safe_id = id.replace(" ", "_").replace(".", "_")
		var filename = "%s/%s.tres" % [folder, safe_id]
		
		# 保存资源
		var error = ResourceSaver.save(data, filename)
		if error != OK:
			print("❌ 保存失败: [%s] -> %s (错误码: %d)" % [id, filename, error])
		else:
			success_count += 1
	
	print("=== 修复完成 ===")
	print("成功: %d" % success_count)
	print("失败: %d" % (upgrades.size() - success_count))
