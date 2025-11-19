@tool
extends EditorScript

func _run():
	print("=== 开始验证资源文件 (Luck) ===")
	
	var luck_values = [5, 10, 20, 30, 50]
	var base_cost = 3
	var tier_multipliers = [1, 2, 4, 8, 16]
	
	for i in range(5):
		var tier = i + 1
		var path = "res://resources/upgrades/luck/luck_tier%d.tres" % tier
		var res = ResourceLoader.load(path) as UpgradeData
		if res:
			print("检查 Tier %d: %s" % [tier, path])
			print("  Name: %s" % res.name)
			if res.stats_modifier:
				print("  Stats Luck: %.1f" % res.stats_modifier.luck)
			else:
				print("  Stats Luck: NULL")
			print("  Cost: %d" % res.actual_cost)
			
			var expected_luck = float(luck_values[i])
			var expected_cost = base_cost * tier_multipliers[i]
			
			if res.stats_modifier and res.stats_modifier.luck != expected_luck:
				print("  ❌ 属性错误！期望: %.1f, 实际: %.1f" % [expected_luck, res.stats_modifier.luck])
			if res.actual_cost != expected_cost:
				print("  ❌ 价格错误！期望: %d, 实际: %d" % [expected_cost, res.actual_cost])
		else:
			print("❌ 无法加载: %s" % path)

	print("=== 验证结束 ===")
