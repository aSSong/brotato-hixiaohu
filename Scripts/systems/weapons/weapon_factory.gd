class_name WeaponFactory

## 武器工厂（重构版）
## 
## 统一武器创建流程
## 使用新的行为组合模式，所有武器都使用 BaseWeapon

static var base_weapon_scene = preload("res://scenes/weapons/weapon.tscn")

## 创建武器
## 
## @param weapon_id 武器ID（如 "pistol", "flame_sword"）
## @param level 武器等级（1-5）
## @return 武器实例
static func create_weapon(weapon_id: String, level: int = 1):
	var weapon_data = WeaponDatabase.get_weapon(weapon_id)
	if not weapon_data:
		push_error("[WeaponFactory] 武器不存在: " + weapon_id)
		return null
	
	var weapon_instance = base_weapon_scene.instantiate()
	if not weapon_instance:
		push_error("[WeaponFactory] 无法实例化基础武器场景")
		return null
	
	# 新版：所有武器都使用 BaseWeapon，通过行为组合实现不同攻击方式
	var script = load("res://Scripts/weapons/base_weapon.gd")
	if not script:
		push_error("[WeaponFactory] 无法加载武器脚本: base_weapon.gd")
		weapon_instance.queue_free()
		return null
	
	weapon_instance.set_script(script)
	
	# 使用meta传递数据，让武器的_ready()处理初始化
	weapon_instance.set_meta("weapon_data", weapon_data)
	weapon_instance.set_meta("weapon_level", level)
	
	return weapon_instance

## 创建武器并设置玩家属性
## 
## @param weapon_id 武器ID
## @param level 武器等级
## @param player_stats 玩家属性
## @return 武器实例
static func create_weapon_with_stats(weapon_id: String, level: int, player_stats: CombatStats):
	var weapon = create_weapon(weapon_id, level)
	if weapon and player_stats:
		weapon.set_meta("player_stats", player_stats)
	return weapon
