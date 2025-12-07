class_name UpgradeManager
extends Node

## 升级管理器
##
## 负责处理升级的应用逻辑，包括属性加成、武器添加、治疗等
## 将业务逻辑从 UI (UpgradeShop) 中分离出来

## 应用升级效果
static func apply_upgrade(upgrade: UpgradeData, tree: SceneTree) -> void:
	if not upgrade or not tree:
		push_error("[UpgradeManager] 无效的参数: upgrade=%s, tree=%s" % [upgrade, tree])
		return

	# 特殊处理：武器相关和恢复HP
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.HEAL_HP:
			_apply_heal_upgrade(upgrade, tree)
		UpgradeData.UpgradeType.NEW_WEAPON:
			await _apply_new_weapon_upgrade(upgrade.weapon_id, tree)
		UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
			_apply_weapon_level_upgrade(upgrade.weapon_id, tree)
		_:
			# 使用新属性系统应用升级
			_apply_attribute_upgrade(upgrade, tree)

static func _apply_heal_upgrade(upgrade: UpgradeData, tree: SceneTree) -> void:
	var heal_amount = 10 # Default
	
	# Try to get heal amount from custom_value (preferred)
	if upgrade.custom_value > 0:
		heal_amount = int(upgrade.custom_value)
	# Fallback: Try to get heal amount from stats_modifier.max_hp (legacy/compatibility)
	elif upgrade.stats_modifier and upgrade.stats_modifier.max_hp > 0:
		heal_amount = upgrade.stats_modifier.max_hp
	
	var player = tree.get_first_node_in_group("player")
	if player:
		var old_hp = player.now_hp
		player.now_hp = min(player.now_hp + heal_amount, player.max_hp)
		var actual_heal = player.now_hp - old_hp
		
		# 显示HP恢复的浮动文字（使用统一方法）
		if actual_heal > 0:
			SpecialEffects.show_heal_floating_text(player, actual_heal)
		
		player.hp_changed.emit(player.now_hp, player.max_hp)
		print("[UpgradeManager] 应用治疗: %s, 恢复量: %d (实际: %d)" % [upgrade.name, heal_amount, actual_heal])

static func _apply_new_weapon_upgrade(weapon_id: String, tree: SceneTree) -> void:
	var weapons_manager = _get_weapons_manager(tree)
	
	if weapons_manager and weapons_manager.has_method("add_weapon"):
		await weapons_manager.add_weapon(weapon_id, 1)  # 新武器固定1级，必须等待完成

static func _apply_weapon_level_upgrade(weapon_id: String, tree: SceneTree) -> void:
	var weapons_manager = _get_weapons_manager(tree)
	
	if weapons_manager and weapons_manager.has_method("get_lowest_level_weapon_of_type"):
		var weapon = weapons_manager.get_lowest_level_weapon_of_type(weapon_id)
		if weapon and weapon.has_method("upgrade_level"):
			weapon.upgrade_level()

## 应用属性升级（新系统）
## 
## 使用AttributeManager添加永久属性加成
static func _apply_attribute_upgrade(upgrade: UpgradeData, tree: SceneTree) -> void:
	var player = tree.get_first_node_in_group("player")
	if not player:
		push_error("[UpgradeManager] 无法找到玩家节点")
		return
	
	# 检查是否使用新属性系统
	if player.has_node("AttributeManager"):
		# 新系统：使用AttributeModifier
		if upgrade.stats_modifier:
			var modifier = upgrade.create_modifier()
			player.attribute_manager.add_permanent_modifier(modifier)
			print("[UpgradeManager] 使用新系统应用升级: %s" % upgrade.name)
		else:
			# 如果升级还没有stats_modifier，尝试使用旧系统
			push_warning("[UpgradeManager] 升级 %s 没有stats_modifier，降级到旧系统" % upgrade.name)
			_apply_attribute_changes_old(upgrade, tree)
	else:
		# 降级方案：使用旧系统
		_apply_attribute_changes_old(upgrade, tree)

## 通用属性变化应用函数（旧系统兼容）
## 
## 根据 upgrade.attribute_changes 配置应用属性变化
static func _apply_attribute_changes_old(upgrade: UpgradeData, tree: SceneTree) -> void:
	if upgrade.attribute_changes.is_empty():
		print("[UpgradeManager] 警告: 升级 %s 没有配置属性变化" % upgrade.name)
		return
	
	var player = tree.get_first_node_in_group("player")
	if not player:
		push_error("[UpgradeManager] 无法找到玩家节点")
		return
	
	var class_data = player.current_class
	if not class_data:
		push_error("[UpgradeManager] 玩家没有职业数据")
		return
	
	var need_reapply_weapons = false
	
	# 遍历所有属性变化配置
	for attr_name in upgrade.attribute_changes.keys():
		var change_config = upgrade.attribute_changes[attr_name]
		if not change_config.has("op") or not change_config.has("value"):
			push_error("[UpgradeManager] 属性变化配置格式错误: %s" % attr_name)
			continue
		
		var op = change_config["op"]
		var value = change_config["value"]
		
		# 特殊处理：max_hp 和 speed（在 player 上）
		if attr_name == "max_hp":
			if op == "add":
				player.max_hp += int(value)
				# player.now_hp += int(value)  # 同时恢复HP
				player.hp_changed.emit(player.now_hp, player.max_hp)
				print("[UpgradeManager] %s: max_hp += %d (当前: %d)" % [upgrade.name, int(value), player.max_hp])
			continue
		
		if attr_name == "speed":
			if op == "add":
				player.base_speed += value
				player.speed += value
				print("[UpgradeManager] %s: speed += %.1f (当前: %.1f)" % [upgrade.name, value, player.speed])
			continue
		
		# 其他属性在 class_data 上
		# 检查属性是否存在（Resource 没有 has() 方法，需要检查 property_list）
		var property_exists = false
		for prop in class_data.get_property_list():
			if prop.name == attr_name:
				property_exists = true
				break
		
		if not property_exists:
			push_error("[UpgradeManager] 属性不存在: %s" % attr_name)
			continue
		
		var current_value = class_data.get(attr_name)
		var new_value
		
		match op:
			"add":
				new_value = current_value + value
			"multiply":
				new_value = current_value * value
			_:
				push_error("[UpgradeManager] 不支持的操作类型: %s" % op)
				continue
		
		class_data.set(attr_name, new_value)
		
		# 检查是否需要重新应用武器加成
		if attr_name.contains("multiplier") or attr_name == "luck":
			need_reapply_weapons = true
		
		print("[UpgradeManager] %s: %s %s %.2f (%.2f -> %.2f)" % [
			upgrade.name,
			attr_name,
			op,
			value,
			current_value,
			new_value
		])
	
	# 如果修改了武器相关属性，重新应用武器加成
	if need_reapply_weapons:
		_reapply_weapon_bonuses(tree)

## 重新应用武器加成（当属性改变时）
static func _reapply_weapon_bonuses(tree: SceneTree) -> void:
	var weapons_manager = _get_weapons_manager(tree)
	
	if weapons_manager and weapons_manager.has_method("reapply_all_bonuses"):
		weapons_manager.reapply_all_bonuses()

## 辅助函数：获取武器管理器
static func _get_weapons_manager(tree: SceneTree) -> Node:
	var weapons_manager = tree.get_first_node_in_group("weapons_manager")
	if not weapons_manager:
		weapons_manager = tree.get_first_node_in_group("weapons")
	return weapons_manager
