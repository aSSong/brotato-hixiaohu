extends RefCounted
class_name FloorConfig

## 楼层配置管理器
## 统一管理楼层定义和解析，便于各处复用
## 
## floor_id 含义：
##   - 1-38: 对应真实楼层 "1F" 到 "38F"
##   - 99: 表示 "不在漕河泾"
##   - -1 或其他: 无效/未选择

## 可选楼层配置：{floor_id: 显示名称}
## 要删除某个楼层选项，只需从这里移除即可，不影响其他楼层的 floor_id
const AVAILABLE_FLOORS: Dictionary = {
	6: "6 楼",
	7: "7 楼",
	18: "18 楼",
	19: "19 楼",
	21: "21 楼",
	22: "22 楼",
	23: "23 楼",
	24: "24 楼",
	35: "35 楼",
	37: "37 楼",
	38: "38 楼",
	99: "其他"
}

## 特殊 floor_id 常量
const FLOOR_ID_INVALID: int = -1
const FLOOR_ID_OUTSIDE: int = 99

## 获取所有可选楼层ID（已排序）
static func get_available_floor_ids() -> Array:
	var ids = AVAILABLE_FLOORS.keys()
	ids.sort()
	return ids

## 获取楼层显示名称（用于下拉菜单等）
## @param floor_id: 楼层ID
## @return: 楼层名称，如 "38 楼"、"不在漕河泾"
static func get_floor_name(floor_id: int) -> String:
	return AVAILABLE_FLOORS.get(floor_id, "")

## 获取楼层短文本（用于UI紧凑显示）
## @param floor_id: 楼层ID
## @return: 如 "38F"、"外"，无效则返回空字符串
static func get_floor_short_text(floor_id: int) -> String:
	if floor_id >= 1 and floor_id <= 38:
		return str(floor_id) + "F"
	elif floor_id == FLOOR_ID_OUTSIDE:
		return "外"
	else:
		return ""

## 检查 floor_id 是否有效
static func is_valid_floor_id(floor_id: int) -> bool:
	return AVAILABLE_FLOORS.has(floor_id)

## 检查 floor_id 是否为有效的楼层选项（用于加载存档时验证）
static func is_available_floor(floor_id: int) -> bool:
	return AVAILABLE_FLOORS.has(floor_id)

## 迁移旧版 floor_id（0-38 索引制）到新版（1-38 真实楼层号）
## @param old_floor_id: 旧版 floor_id（数组索引 0-38）
## @return: 新版 floor_id（真实楼层号 1-38 或 99）
static func migrate_legacy_floor_id(old_floor_id: int) -> int:
	if old_floor_id >= 0 and old_floor_id <= 37:
		return old_floor_id + 1  # 0-37 → 1-38
	elif old_floor_id == 38:
		return FLOOR_ID_OUTSIDE  # 38 → 99
	else:
		return FLOOR_ID_INVALID
