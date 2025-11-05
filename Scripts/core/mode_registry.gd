extends Node
class_name ModeRegistry

## 游戏模式注册表
## 集中管理所有可用的游戏模式

## 已注册的模式
static var registered_modes: Dictionary = {}

## 初始化标志
static var _initialized: bool = false

## 初始化注册表（注册所有模式）
static func initialize() -> void:
	if _initialized:
		return
	
	print("[ModeRegistry] 初始化模式注册表")
	
	# 注册内置模式
	register_mode("survival", SurvivalMode)
	
	# 未来可以添加更多模式：
	# register_mode("time_attack", TimeAttackMode)
	# register_mode("endless", EndlessMode)
	# register_mode("boss_rush", BossRushMode)
	
	_initialized = true
	print("[ModeRegistry] 已注册 %d 个模式" % registered_modes.size())

## 注册模式
## @param mode_id: 模式ID
## @param mode_script: 模式脚本（继承自BaseGameMode）
static func register_mode(mode_id: String, mode_script: Script) -> void:
	if registered_modes.has(mode_id):
		push_warning("[ModeRegistry] 模式已存在，覆盖: %s" % mode_id)
	
	registered_modes[mode_id] = mode_script
	print("[ModeRegistry] 注册模式: %s" % mode_id)

## 创建模式实例
## @param mode_id: 模式ID
## @return: 模式实例，如果不存在返回null
static func create_mode(mode_id: String) -> BaseGameMode:
	if not _initialized:
		initialize()
	
	if not registered_modes.has(mode_id):
		push_error("[ModeRegistry] 模式不存在: %s" % mode_id)
		return null
	
	var mode_script = registered_modes[mode_id]
	var mode = mode_script.new()
	
	if not mode is BaseGameMode:
		push_error("[ModeRegistry] 模式脚本必须继承自BaseGameMode: %s" % mode_id)
		mode.free()
		return null
	
	print("[ModeRegistry] 创建模式: %s" % mode_id)
	return mode

## 获取所有模式ID
static func get_all_mode_ids() -> Array[String]:
	if not _initialized:
		initialize()
	
	var ids: Array[String] = []
	for key in registered_modes.keys():
		ids.append(key)
	return ids

## 检查模式是否存在
static func has_mode(mode_id: String) -> bool:
	if not _initialized:
		initialize()
	
	return registered_modes.has(mode_id)

## 获取模式信息
static func get_mode_info(mode_id: String) -> Dictionary:
	if not has_mode(mode_id):
		return {}
	
	# 临时创建模式实例来获取信息
	var mode = create_mode(mode_id)
	if not mode:
		return {}
	
	var info = mode.get_mode_info()
	mode.free()
	
	return info

## 获取所有模式信息
static func get_all_mode_infos() -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	
	for mode_id in get_all_mode_ids():
		var info = get_mode_info(mode_id)
		if not info.is_empty():
			infos.append(info)
	
	return infos

## 打印所有注册的模式
static func print_registered_modes() -> void:
	print("[ModeRegistry] 已注册的模式:")
	for mode_id in get_all_mode_ids():
		var info = get_mode_info(mode_id)
		print("  - %s: %s" % [mode_id, info.get("name", "Unknown")])
		print("    描述: %s" % info.get("description", "无描述"))

