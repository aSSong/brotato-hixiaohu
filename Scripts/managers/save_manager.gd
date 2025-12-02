extends Node

## 存档管理器
## 负责保存和读取用户数据（名字、楼层等）

const SAVE_FILE_PATH = "user://user_save.dat"

## 用户数据字典
var user_data: Dictionary = {
	"player_name": "",
	"floor_id": -1,  # -1 表示未选择，1-38 对应真实楼层，99 表示"不在漕河泾"
	"floor_name": "",
	"total_death_count": 0  # 累计死亡次数
}

## 初始化
func _ready() -> void:
	load_user_data()
	print("[SaveManager] 存档管理器初始化完成")

## 保存用户数据
func save_user_data() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法打开存档文件进行写入: %s" % SAVE_FILE_PATH)
		return
	
	# 将数据转换为JSON格式保存
	var json_string = JSON.stringify(user_data)
	file.store_string(json_string)
	file.close()
	
	print("[SaveManager] 用户数据已保存: %s" % user_data)

## 读取用户数据
func load_user_data() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[SaveManager] 存档文件不存在，使用默认数据")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] 无法打开存档文件进行读取: %s" % SAVE_FILE_PATH)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# 解析JSON数据
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[SaveManager] 解析存档文件失败: %s" % json.get_error_message())
		return false
	
	var loaded_data = json.data
	if loaded_data is Dictionary:
		user_data = loaded_data
		# 确保旧存档也有 total_death_count 字段
		if not user_data.has("total_death_count"):
			user_data["total_death_count"] = 0
		# 迁移旧版 floor_id（0-38 索引制）到新版（1-38 真实楼层号）
		_migrate_legacy_floor_id()
		print("[SaveManager] 用户数据已加载: %s" % user_data)
		return true
	else:
		push_error("[SaveManager] 存档文件格式错误")
		return false

## 设置玩家名字
func set_player_name(name: String) -> void:
	user_data["player_name"] = name
	save_user_data()

## 设置楼层信息
func set_floor(floor_id: int, floor_name: String) -> void:
	user_data["floor_id"] = floor_id
	user_data["floor_name"] = floor_name
	save_user_data()

## 获取玩家名字
func get_player_name() -> String:
	return user_data.get("player_name", "")

## 获取楼层ID
func get_floor_id() -> int:
	return user_data.get("floor_id", -1)

## 获取楼层名称
func get_floor_name() -> String:
	return user_data.get("floor_name", "")

## 检查是否有存档
func has_save_data() -> bool:
	return user_data.get("player_name", "") != "" and user_data.get("floor_id", -1) >= 0

## 清除存档数据
func clear_save_data() -> void:
	user_data = {
		"player_name": "",
		"floor_id": -1,
		"floor_name": "",
		"total_death_count": 0
	}
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
	print("[SaveManager] 存档数据已清除")

## 增加死亡次数
func increment_death_count() -> void:
	var current_count = user_data.get("total_death_count", 0)
	user_data["total_death_count"] = current_count + 1
	save_user_data()
	print("[SaveManager] 死亡次数已增加，当前总死亡次数:", user_data["total_death_count"])

## 获取总死亡次数
func get_total_death_count() -> int:
	return user_data.get("total_death_count", 0)

## 迁移旧版 floor_id 到新版
## 旧版: 0-37 对应 1-38 楼，38 对应"不在漕河泾"
## 新版: 1-38 对应真实楼层，99 对应"不在漕河泾"
func _migrate_legacy_floor_id() -> void:
	var floor_id = user_data.get("floor_id", -1)
	# 检测是否为旧版格式（0-38 范围且不是有效的新版ID）
	# 旧版: floor_id 0 对应 "1 楼"，新版: floor_id 1 对应 "1 楼"
	# 如果 floor_id 为 0，肯定是旧版（新版中 0 无效）
	if floor_id == 0:
		user_data["floor_id"] = 1
		print("[SaveManager] 迁移旧版 floor_id: 0 → 1")
		save_user_data()
	elif floor_id == 38:
		# 旧版 38 表示"不在漕河泾"，新版用 99
		user_data["floor_id"] = 99
		print("[SaveManager] 迁移旧版 floor_id: 38 → 99")
		save_user_data()
