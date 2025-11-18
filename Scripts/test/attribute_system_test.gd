extends Node
class_name AttributeSystemTest

## 属性系统测试场景
## 
## 用于验证新属性系统的各项功能是否正常工作

var test_results: Array[Dictionary] = []
var total_tests: int = 0
var passed_tests: int = 0

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("属性系统功能测试")
	print("=".repeat(60) + "\n")
	
	# 运行所有测试
	run_all_tests()
	
	# 打印测试结果
	print_test_summary()

## 运行所有测试
func run_all_tests() -> void:
	# 1. CombatStats 测试
	test_combat_stats_clone()
	
	# 2. AttributeModifier 测试
	test_attribute_modifier_creation()
	
	# 3. AttributeManager 测试
	test_attribute_manager_basic()
	test_attribute_manager_layered_stacking()
	test_attribute_manager_temporary_modifiers()
	
	# 4. DamageCalculator 测试
	test_damage_calculator_weapon_damage()
	test_damage_calculator_critical()
	test_damage_calculator_defense()
	
	# 5. ClassData 测试
	test_class_data_sync()
	
	# 6. UpgradeData 测试
	test_upgrade_data_modifier()
	
	# 7. WeaponData 测试
	test_weapon_data_modifier()
	
	# 8. BuffSystem 测试
	test_buff_system()
	
	# 9. SpecialEffects 测试
	test_special_effects()

## ========== 测试辅助函数 ==========

func test_assert(test_name: String, condition: bool, message: String = "") -> void:
	total_tests += 1
	var result = {
		"name": test_name,
		"passed": condition,
		"message": message
	}
	test_results.append(result)
	
	if condition:
		passed_tests += 1
		print("✅ [PASS] %s" % test_name)
	else:
		print("❌ [FAIL] %s - %s" % [test_name, message])

func test_assert_equal(test_name: String, actual, expected, tolerance: float = 0.01) -> void:
	var passed = false
	var message = ""
	
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		passed = abs(float(actual) - float(expected)) < tolerance
		message = "期望: %.2f, 实际: %.2f" % [float(expected), float(actual)]
	else:
		passed = actual == expected
		message = "期望: %s, 实际: %s" % [str(expected), str(actual)]
	
	test_assert(test_name, passed, message)

## ========== 1. CombatStats 测试 ==========

func test_combat_stats_clone() -> void:
	print("\n--- 测试 CombatStats.clone() ---")
	
	var original = CombatStats.new()
	original.max_hp = 100.0
	original.speed = 400.0
	original.defense = 10.0
	original.crit_chance = 0.2
	
	var cloned = original.clone()
	
	test_assert_equal("CombatStats.clone() - max_hp", cloned.max_hp, 100.0)
	test_assert_equal("CombatStats.clone() - speed", cloned.speed, 400.0)
	test_assert_equal("CombatStats.clone() - defense", cloned.defense, 10.0)
	test_assert_equal("CombatStats.clone() - crit_chance", cloned.crit_chance, 0.2)
	
	# 修改克隆不应影响原始
	cloned.max_hp = 200.0
	test_assert_equal("CombatStats.clone() - 独立性", original.max_hp, 100.0)

## ========== 2. AttributeModifier 测试 ==========

func test_attribute_modifier_creation() -> void:
	print("\n--- 测试 AttributeModifier 创建 ---")
	
	var modifier = AttributeModifier.new()
	modifier.modifier_type = AttributeModifier.ModifierType.UPGRADE
	modifier.modifier_id = "test_upgrade"
	modifier.stats_delta = CombatStats.new()
	modifier.stats_delta.max_hp = 20.0
	modifier.stats_delta.defense = 5.0
	
	test_assert("AttributeModifier - 创建成功", modifier != null)
	test_assert_equal("AttributeModifier - modifier_id", modifier.modifier_id, "test_upgrade")
	test_assert_equal("AttributeModifier - max_hp", modifier.stats_delta.max_hp, 20.0)
	test_assert_equal("AttributeModifier - defense", modifier.stats_delta.defense, 5.0)

## ========== 3. AttributeManager 测试 ==========

func test_attribute_manager_basic() -> void:
	print("\n--- 测试 AttributeManager 基础功能 ---")
	
	var manager = AttributeManager.new()
	manager.base_stats = CombatStats.new()
	manager.base_stats.max_hp = 50.0
	manager.base_stats.defense = 5.0
	
	manager.recalculate()
	
	test_assert_equal("AttributeManager - 基础属性max_hp", manager.final_stats.max_hp, 50.0)
	test_assert_equal("AttributeManager - 基础属性defense", manager.final_stats.defense, 5.0)

func test_attribute_manager_layered_stacking() -> void:
	print("\n--- 测试 AttributeManager 分层加成 ---")
	
	var manager = AttributeManager.new()
	manager.base_stats = CombatStats.new()
	manager.base_stats.max_hp = 50.0
	manager.base_stats.global_damage_mult = 1.0
	
	# 添加加法层修改器（同类相加）
	var mod1 = AttributeModifier.new()
	mod1.modifier_type = AttributeModifier.ModifierType.UPGRADE
	mod1.modifier_id = "upgrade1"
	mod1.stats_delta = CombatStats.new()
	mod1.stats_delta.max_hp = 10.0  # +10 HP
	
	var mod2 = AttributeModifier.new()
	mod2.modifier_type = AttributeModifier.ModifierType.UPGRADE
	mod2.modifier_id = "upgrade2"
	mod2.stats_delta = CombatStats.new()
	mod2.stats_delta.max_hp = 20.0  # +20 HP
	
	manager.add_permanent_modifier(mod1)
	manager.add_permanent_modifier(mod2)
	manager.recalculate()
	
	# 期望：50 + 10 + 20 = 80
	test_assert_equal("分层加成 - 加法层相加", manager.final_stats.max_hp, 80.0)
	
	# 添加乘法层修改器（异类相乘）
	var mod3 = AttributeModifier.new()
	mod3.modifier_type = AttributeModifier.ModifierType.SKILL
	mod3.modifier_id = "skill1"
	mod3.stats_delta = CombatStats.new()
	mod3.stats_delta.global_damage_mult = 1.3  # 1.3倍
	
	var mod4 = AttributeModifier.new()
	mod4.modifier_type = AttributeModifier.ModifierType.UPGRADE
	mod4.modifier_id = "upgrade3"
	mod4.stats_delta = CombatStats.new()
	mod4.stats_delta.global_damage_mult = 1.2  # 1.2倍
	
	manager.add_permanent_modifier(mod3)
	manager.add_permanent_modifier(mod4)
	manager.recalculate()
	
	# 期望：1.0 * 1.3 * 1.2 = 1.56
	test_assert_equal("分层加成 - 乘法层相乘", manager.final_stats.global_damage_mult, 1.56, 0.01)

func test_attribute_manager_temporary_modifiers() -> void:
	print("\n--- 测试 AttributeManager 临时修改器 ---")
	
	var manager = AttributeManager.new()
	manager.base_stats = CombatStats.new()
	manager.base_stats.speed = 400.0
	
	# 添加临时修改器
	var temp_mod = AttributeModifier.new()
	temp_mod.modifier_type = AttributeModifier.ModifierType.BUFF
	temp_mod.modifier_id = "speed_buff"
	temp_mod.stats_delta = CombatStats.new()
	temp_mod.stats_delta.speed = 100.0  # +100速度
	temp_mod.duration = 5.0
	
	manager.add_temporary_modifier(temp_mod)
	manager.recalculate()
	
	# 期望：400 + 100 = 500
	test_assert_equal("临时修改器 - 添加后生效", manager.final_stats.speed, 500.0)
	
	# 移除临时修改器
	manager.remove_modifier("speed_buff")
	manager.recalculate()
	
	# 期望：恢复到 400
	test_assert_equal("临时修改器 - 移除后恢复", manager.final_stats.speed, 400.0)

## ========== 4. DamageCalculator 测试 ==========

func test_damage_calculator_weapon_damage() -> void:
	print("\n--- 测试 DamageCalculator 武器伤害计算 ---")
	
	var stats = CombatStats.new()
	stats.global_damage_mult = 1.2
	stats.melee_damage_mult = 1.5
	
	var base_damage = 10
	var weapon_level_mult = 1.3  # 2级武器
	
	var final_damage = DamageCalculator.calculate_weapon_damage(
		base_damage,
		weapon_level_mult,
		stats,
		DamageCalculator.WeaponType.MELEE
	)
	
	# 期望：10 * 1.3 * 1.2 * 1.5 = 23.4
	test_assert_equal("DamageCalculator - 近战伤害计算", final_damage, 23.4, 0.1)

func test_damage_calculator_critical() -> void:
	print("\n--- 测试 DamageCalculator 暴击计算 ---")
	
	var stats = CombatStats.new()
	stats.crit_chance = 1.0  # 100%暴击率
	stats.crit_mult = 2.0  # 2倍暴击伤害
	
	# 100%暴击率应该总是暴击
	var is_crit = DamageCalculator.roll_critical(stats)
	test_assert("DamageCalculator - 100%暴击率触发", is_crit)
	
	# 暴击伤害计算
	var base_damage = 100
	var crit_damage = DamageCalculator.apply_critical_multiplier(base_damage, stats)
	
	# 期望：100 * 2.0 = 200
	test_assert_equal("DamageCalculator - 暴击伤害倍数", crit_damage, 200)

func test_damage_calculator_defense() -> void:
	print("\n--- 测试 DamageCalculator 防御减伤 ---")
	
	var stats = CombatStats.new()
	stats.defense = 10.0
	stats.damage_reduction = 0.2  # 20%减伤
	
	var incoming_damage = 100
	var reduced_damage = DamageCalculator.calculate_defense_reduction(incoming_damage, stats)
	
	# 期望：(100 - 10) * (1 - 0.2) = 90 * 0.8 = 72
	test_assert_equal("DamageCalculator - 防御减伤", reduced_damage, 72)

## ========== 5. ClassData 测试 ==========

func test_class_data_sync() -> void:
	print("\n--- 测试 ClassData.sync_to_base_stats() ---")
	
	var class_data = ClassData.new(
		"测试职业",
		60,  # max_hp
		400.0,  # speed
		1.2,  # attack_multiplier
		5,  # defense
		0.1,  # crit_chance
		2.0,  # crit_damage
		"测试技能",
		{}
	)
	
	class_data.melee_damage_multiplier = 1.3
	class_data.sync_to_base_stats()
	
	test_assert("ClassData - base_stats存在", class_data.base_stats != null)
	test_assert_equal("ClassData - max_hp同步", class_data.base_stats.max_hp, 60.0)
	test_assert_equal("ClassData - speed同步", class_data.base_stats.speed, 400.0)
	test_assert_equal("ClassData - defense同步", class_data.base_stats.defense, 5.0)
	test_assert_equal("ClassData - melee_damage_mult同步", class_data.base_stats.melee_damage_mult, 1.3)

## ========== 6. UpgradeData 测试 ==========

func test_upgrade_data_modifier() -> void:
	print("\n--- 测试 UpgradeData.create_modifier() ---")
	
	var upgrade = UpgradeData.new()
	upgrade.name = "力量提升"
	upgrade.stats_modifier = CombatStats.new()
	upgrade.stats_modifier.global_damage_mult = 1.15
	upgrade.stats_modifier.max_hp = 10.0
	
	var modifier = upgrade.create_modifier()
	
	test_assert("UpgradeData - modifier创建成功", modifier != null)
	test_assert_equal("UpgradeData - 伤害倍数", modifier.stats_delta.global_damage_mult, 1.15)
	test_assert_equal("UpgradeData - 生命值", modifier.stats_delta.max_hp, 10.0)

## ========== 7. WeaponData 测试 ==========

func test_weapon_data_modifier() -> void:
	print("\n--- 测试 WeaponData.create_weapon_modifier() ---")
	
	var weapon_data = WeaponData.new()
	weapon_data.weapon_name = "测试武器"
	weapon_data.crit_chance_bonus = 0.1  # +10%暴击率
	weapon_data.lifesteal_percent = 0.15  # 15%吸血
	weapon_data.burn_chance = 0.3  # 30%燃烧几率
	
	var modifier = weapon_data.create_weapon_modifier("test_weapon")
	
	test_assert("WeaponData - modifier创建成功", modifier != null)
	test_assert_equal("WeaponData - 暴击率", modifier.stats_delta.crit_chance, 0.1)
	test_assert_equal("WeaponData - 吸血", modifier.stats_delta.lifesteal_percent, 0.15)
	test_assert_equal("WeaponData - 燃烧几率", modifier.stats_delta.burn_chance, 0.3)

## ========== 8. BuffSystem 测试 ==========

func test_buff_system() -> void:
	print("\n--- 测试 BuffSystem ---")
	
	var buff_system = BuffSystem.new()
	add_child(buff_system)  # 需要在场景树中才能工作
	
	var buff_modifier = AttributeModifier.new()
	buff_modifier.modifier_type = AttributeModifier.ModifierType.BUFF
	buff_modifier.modifier_id = "test_buff"
	buff_modifier.stats_delta = CombatStats.new()
	buff_modifier.stats_delta.speed = 50.0
	buff_modifier.duration = 3.0
	
	buff_system.add_buff("test_buff", buff_modifier, 3.0)
	
	test_assert("BuffSystem - Buff添加成功", buff_system.active_buffs.has("test_buff"))
	
	# 移除Buff
	buff_system.remove_buff("test_buff")
	test_assert("BuffSystem - Buff移除成功", not buff_system.active_buffs.has("test_buff"))
	
	remove_child(buff_system)
	buff_system.queue_free()

## ========== 9. SpecialEffects 测试 ==========

func test_special_effects() -> void:
	print("\n--- 测试 SpecialEffects ---")
	
	# 创建模拟的玩家和敌人节点
	var mock_player = Node2D.new()
	mock_player.set_script(load("res://Scripts/players/player.gd"))
	mock_player.name = "MockPlayer"
	add_child(mock_player)
	
	var mock_enemy = Node2D.new()
	mock_enemy.name = "MockEnemy"
	mock_enemy.set_script(load("res://Scripts/enemy/enemy.gd"))
	add_child(mock_enemy)
	
	# 测试吸血计算
	var damage = 100
	var lifesteal_percent = 0.2  # 20%吸血
	var heal_amount = SpecialEffects.calculate_lifesteal(damage, lifesteal_percent)
	test_assert_equal("SpecialEffects - 吸血计算", heal_amount, 20.0)
	
	# 清理
	remove_child(mock_player)
	remove_child(mock_enemy)
	mock_player.queue_free()
	mock_enemy.queue_free()

## ========== 测试结果输出 ==========

func print_test_summary() -> void:
	print("\n" + "=".repeat(60))
	print("测试总结")
	print("=".repeat(60))
	print("总测试数: %d" % total_tests)
	print("通过: %d" % passed_tests)
	print("失败: %d" % (total_tests - passed_tests))
	print("通过率: %.1f%%" % (float(passed_tests) / float(total_tests) * 100.0))
	
	# 失败的测试详情
	var failed_tests = test_results.filter(func(r): return not r.passed)
	if failed_tests.size() > 0:
		print("\n失败的测试:")
		for test in failed_tests:
			print("  ❌ %s: %s" % [test.name, test.message])
	
	print("\n" + "=".repeat(60))
	
	if passed_tests == total_tests:
		print("🎉 所有测试通过！属性系统工作正常！")
	else:
		print("⚠️  有 %d 个测试失败，请检查问题。" % (total_tests - passed_tests))
	
	print("=".repeat(60) + "\n")

