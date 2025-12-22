extends Node

## 测试脚本 - 验证波次配置系统
## 在编辑器中运行此脚本以测试配置加载

func _ready() -> void:
	print("\n========== 波次配置系统测试 ==========\n")
	
	# 测试1：加载配置
	print("测试1：加载 default.json 配置...")
	var config_data = WaveConfigLoader.load_config("default")
	
	if config_data.is_empty():
		print("❌ 配置加载失败")
		return
	
	print("✅ 配置加载成功")
	print("   配置ID: ", config_data.config_id)
	print("   总波次: ", config_data.total_waves)
	print("   波次数据数量: ", config_data.waves.size())
	
	# 测试2：检查前5波配置
	print("\n测试2：检查前5波配置...")
	for i in range(min(5, config_data.waves.size())):
		var wave = config_data.waves[i]
		print("   第%d波: 数量=%d, 间隔=%.2f, HP成长=%.1f%%, 伤害成长=%.1f%%" % [
			wave.wave,
			wave.total_count,
			wave.spawn_interval,
			wave.hp_growth * 100,
			wave.damage_growth * 100
		])
		
		# 显示敌人配比
		var enemy_types = []
		for enemy_id in wave.enemies:
			var ratio = wave.enemies[enemy_id]
			enemy_types.append("%s(%.0f%%)" % [enemy_id, ratio * 100])
		print("      敌人配比: ", ", ".join(enemy_types))
		
		# 显示BOSS配置
		if wave.has("boss_config"):
			var boss = wave.boss_config
			print("      BOSS: %dx %s" % [boss.count, boss.enemy_id])
	
	# 测试3：检查第20波配置
	print("\n测试3：检查第20波配置...")
	if config_data.waves.size() >= 20:
		var wave20 = config_data.waves[19]
		print("   第20波: 数量=%d, 间隔=%.2f, HP成长=%.1f%%, 伤害成长=%.1f%%" % [
			wave20.total_count,
			wave20.spawn_interval,
			wave20.hp_growth * 100,
			wave20.damage_growth * 100
		])
		print("   BOSS数量: ", wave20.boss_config.count)
	
	# 测试4：检查第100波配置
	print("\n测试4：检查第100波配置...")
	if config_data.waves.size() >= 100:
		var wave100 = config_data.waves[99]
		print("   第100波: 数量=%d, 间隔=%.2f, HP成长=%.1f%%, 伤害成长=%.1f%%" % [
			wave100.total_count,
			wave100.spawn_interval,
			wave100.hp_growth * 100,
			wave100.damage_growth * 100
		])
		print("   BOSS数量: ", wave100.boss_config.count)
		
		# 检查特殊刷怪
		if wave100.has("special_spawns") and wave100.special_spawns.size() > 0:
			print("   特殊刷怪: ", wave100.special_spawns.size(), " 个")
			for spawn in wave100.special_spawns:
				var chance = spawn.get("spawn_chance", 1.0)
				print("      位置 %d: %s (spawn_chance=%.2f)" % [int(spawn.get("position", 0)), str(spawn.get("enemy_id", "")), float(chance)])
	
	# 测试5：验证敌人数据库
	print("\n测试5：验证敌人数据库...")
	EnemyDatabase.initialize_enemies()
	var enemy_ids = ["basic", "fast", "tank", "elite", "charging_enemy", "shooting_enemy", "exploding_enemy", "last_enemy"]
	var all_found = true
	for enemy_id in enemy_ids:
		var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
		if enemy_data:
			print("   ✅ %s: HP=%d, 伤害=%d, 速度=%.0f" % [
				enemy_data.enemy_name,
				enemy_data.max_hp,
				enemy_data.attack_damage,
				enemy_data.move_speed
			])
		else:
			print("   ❌ %s 未找到" % enemy_id)
			all_found = false
	
	if all_found:
		print("\n✅ 所有测试通过！")
	else:
		print("\n❌ 部分测试失败")
	
	print("\n========== 测试完成 ==========\n")
	
	# 自动退出
	get_tree().quit()

