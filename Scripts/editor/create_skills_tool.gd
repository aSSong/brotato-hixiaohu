@tool
extends EditorScript

## 技能资源生成工具
## 
## 自动创建预定义的技能资源文件
## 使用方法：在编辑器中打开此脚本，点击 "File > Run" (或 Ctrl+Shift+X)

func _run():
	print("=== 开始创建技能资源 ===")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("resources/skills"):
		dir.make_dir_recursive("resources/skills")
	
	_create_berserk()
	_create_precision()
	_create_magic_burst()
	_create_all_stats()
	_create_shield()
	
	print("=== 技能资源创建完成 ===")

func _create_berserk():
	var skill = SkillData.new()
	skill.name = "狂暴"
	skill.description = "短时间内大幅提升攻击速度(+50%)和伤害(+30%)"
	skill.cooldown = 10.0
	skill.duration = 5.0
	
	var stats = StatsModifier.new()
	stats.global_attack_speed_mult = 1.5
	stats.global_damage_mult = 1.3
	skill.stats_modifier = stats
	
	_save(skill, "berserk")

func _create_precision():
	var skill = SkillData.new()
	skill.name = "精准射击"
	skill.description = "短时间内大幅提升暴击率(+50%)"
	skill.cooldown = 12.0
	skill.duration = 6.0
	
	var stats = StatsModifier.new()
	stats.crit_chance = 0.5
	skill.stats_modifier = stats
	
	_save(skill, "precision")

func _create_magic_burst():
	var skill = SkillData.new()
	skill.name = "魔法爆发"
	skill.description = "短时间内提升魔法伤害(+50%)和爆炸范围(x2)"
	skill.cooldown = 15.0
	skill.duration = 4.0
	
	var stats = StatsModifier.new()
	stats.magic_damage_mult = 1.5
	stats.magic_explosion_radius_mult = 2.0
	skill.stats_modifier = stats
	
	_save(skill, "magic_burst")

func _create_all_stats():
	var skill = SkillData.new()
	skill.name = "全面强化"
	skill.description = "短时间内提升所有属性(+20%)"
	skill.cooldown = 20.0
	skill.duration = 8.0
	
	var stats = StatsModifier.new()
	stats.global_damage_mult = 1.2
	stats.global_attack_speed_mult = 1.2
	stats.speed = 80.0 # 400 * 0.2
	skill.stats_modifier = stats
	
	_save(skill, "all_stats")

func _create_shield():
	var skill = SkillData.new()
	skill.name = "护盾"
	skill.description = "短时间内减少受到的伤害(50%)"
	skill.cooldown = 15.0
	skill.duration = 5.0
	
	var stats = StatsModifier.new()
	# damage_reduction 现为“点数”
	stats.damage_reduction = 50.0
	skill.stats_modifier = stats
	
	_save(skill, "shield")

func _save(resource: Resource, name: String):
	var path = "res://resources/skills/%s.tres" % name
	var error = ResourceSaver.save(resource, path)
	if error == OK:
		print("✅ 已创建: %s" % path)
	else:
		print("❌ 创建失败: %s (错误码: %d)" % [path, error])
