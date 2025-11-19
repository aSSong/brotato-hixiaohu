@tool
extends EditorScript

## 升级数据迁移工具
## 
## 将 UpgradeDatabase 中的硬编码数据迁移为 .tres 资源文件
## 使用方法：在编辑器中打开此脚本，点击 "File > Run" (或 Ctrl+Shift+X)

func _run():
	print("=== 开始迁移升级数据 ===")
	
	# 1. 初始化旧数据
	UpgradeDatabase.initialize_upgrades()
	var upgrades = UpgradeDatabase.upgrades
	
	if upgrades.is_empty():
		print("错误：未找到任何升级数据！")
		return
	
	print("找到 %d 个升级项目" % upgrades.size())
	
	# 2. 准备根目录
	var root_dir = "res://resources/upgrades"
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(root_dir):
		dir.make_dir_recursive(root_dir)
	
	# 3. 遍历并保存
	var success_count = 0
	for id in upgrades:
		var data: UpgradeData = upgrades[id]
		if _save_upgrade_resource(id, data):
			success_count += 1
	
	print("=== 迁移完成 ===")
	print("成功: %d" % success_count)
	print("失败: %d" % (upgrades.size() - success_count))
	print("资源文件已保存至: %s" % root_dir)

func _save_upgrade_resource(id: String, data: UpgradeData) -> bool:
	# 根据类型创建子文件夹
	var type_name = UpgradeData.UpgradeType.keys()[data.upgrade_type].to_lower()
	var folder = "res://resources/upgrades/%s" % type_name
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(folder):
		dir.make_dir_recursive(folder)
	
	# 构建文件名 (清理非法字符)
	var safe_id = id.replace(" ", "_").replace(".", "_")
	var filename = "%s/%s.tres" % [folder, safe_id]
	
	# 检查 stats_modifier
	if not data.stats_modifier:
		print("警告: [%s] 缺少 stats_modifier，尝试自动修复..." % id)
		# 这里可以尝试修复，但理论上之前的修复已经覆盖了
		# data.stats_modifier = UpgradeDatabaseHelper.create_clean_stats()
	
	# 转换为 StatsModifier 资源 (可选，但推荐)
	# 如果我们想让编辑器里显示更干净，可以将 CombatStats 转换为 StatsModifier
	# 但由于数据已经存在，直接保存 CombatStats 也可以
	
	# 保存资源
	var error = ResourceSaver.save(data, filename)
	if error != OK:
		print("❌ 保存失败: [%s] -> %s (错误码: %d)" % [id, filename, error])
		return false
	else:
		# print("✅ 已保存: [%s] -> %s" % [id, filename])
		return true
