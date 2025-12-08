extends Node

## 排行榜记录管理器
## 管理本地排行榜数据的存储和读取
## 数据使用 Base64 编码 + SHA-256 哈希校验，防止简单篡改

const SAVE_FILE_PATH = "user://leaderboard.dat"
const HASH_SALT = "brotato_hxh_2025_leaderboard"  # 哈希盐值

## 排行榜记录
var records: Dictionary = {
	"survival": null,  # Survival模式最佳记录
	"multi": null      # Multi模式最佳记录
}

func _ready() -> void:
	load_records()
	print("[LeaderboardManager] 排行榜管理器初始化完成")

## ==================== 公共方法 ====================

## 尝试更新 Survival 模式记录（只在胜利时调用）
## 返回 true 表示创建了新纪录
func try_update_survival_record(completion_time: float, death_count: int) -> bool:
	var current = records.get("survival")
	
	# 如果没有记录，或者新时间更短，则更新
	if current == null or completion_time < current.get("completion_time_seconds", INF):
		records["survival"] = _create_survival_record(completion_time, death_count)
		save_records()
		save_leaderboard_data(1, records["survival"])
		print("[LeaderboardManager] Survival模式新纪录! 时间: %.2f秒" % completion_time)
		return true
	
	print("[LeaderboardManager] Survival模式未打破纪录 (当前: %.2f秒, 最佳: %.2f秒)" % [completion_time, current.get("completion_time_seconds", 0)])
	return false

## 尝试更新 Multi 模式记录（游戏结束时调用）
## 返回 true 表示创建了新纪录
func try_update_multi_record(best_wave: int, death_count: int) -> bool:
	var current = records.get("multi")
	
	# 如果没有记录，或者新波次更高，则更新
	if current == null or best_wave > current.get("best_wave", 0):
		records["multi"] = _create_multi_record(best_wave, death_count)
		save_records()
		save_leaderboard_data(2, records["multi"])
		print("[LeaderboardManager] Multi模式新纪录! 波次: %d" % best_wave)
		return true
	
	print("[LeaderboardManager] Multi模式未打破纪录 (当前: %d波, 最佳: %d波)" % [best_wave, current.get("best_wave", 0)])
	return false

## 获取 Survival 模式记录
func get_survival_record() -> Dictionary:
	var record = records.get("survival")
	if record == null:
		return {}
	return record

## 获取 Multi 模式记录
func get_multi_record() -> Dictionary:
	var record = records.get("multi")
	if record == null:
		return {}
	return record

## 清除所有记录
func clear_all_records() -> void:
	records = {
		"survival": null,
		"multi": null
	}
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
	print("[LeaderboardManager] 所有记录已清除")

## ==================== 保存/加载 ====================

## 保存记录到文件
func save_records() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[LeaderboardManager] 无法打开文件进行写入: %s" % SAVE_FILE_PATH)
		return
	
	# 将记录转换为JSON
	var json_string = JSON.stringify(records)
	
	# Base64 编码
	var encoded_data = _encode_data(json_string)
	
	# 生成哈希签名
	var signature = _generate_signature(encoded_data)
	
	# 保存格式: {"data": "<base64>", "sig": "<hash>"}
	var save_data = {
		"data": encoded_data,
		"sig": signature
	}
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	print("[LeaderboardManager] 记录已保存")

## 从文件加载记录
func load_records() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[LeaderboardManager] 排行榜文件不存在，使用默认数据")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("[LeaderboardManager] 无法打开文件进行读取: %s" % SAVE_FILE_PATH)
		return false
	
	var file_content = file.get_as_text()
	file.close()
	
	# 解析外层JSON
	var json = JSON.new()
	var parse_result = json.parse(file_content)
	if parse_result != OK:
		push_warning("[LeaderboardManager] 文件格式错误，清除记录")
		_clear_corrupted_data()
		return false
	
	var save_data = json.data
	if not save_data is Dictionary:
		push_warning("[LeaderboardManager] 数据格式错误，清除记录")
		_clear_corrupted_data()
		return false
	
	var encoded_data = save_data.get("data", "")
	var signature = save_data.get("sig", "")
	
	# 验证签名
	if not _verify_signature(encoded_data, signature):
		push_warning("[LeaderboardManager] 签名验证失败，数据可能被篡改，清除记录")
		_clear_corrupted_data()
		return false
	
	# Base64 解码
	var json_string = _decode_data(encoded_data)
	if json_string.is_empty():
		push_warning("[LeaderboardManager] 解码失败，清除记录")
		_clear_corrupted_data()
		return false
	
	# 解析记录数据
	parse_result = json.parse(json_string)
	if parse_result != OK:
		push_warning("[LeaderboardManager] 记录数据解析失败，清除记录")
		_clear_corrupted_data()
		return false
	
	var loaded_data = json.data
	if loaded_data is Dictionary:
		records = loaded_data
		print("[LeaderboardManager] 记录已加载")
		return true
	
	push_warning("[LeaderboardManager] 记录数据格式错误，清除记录")
	_clear_corrupted_data()
	return false

# 从服务器加载记录
func load_leaderboard_data() -> Dictionary:
	var data = await ApiManager.load_leaderboard_data()
	if data is Dictionary and data.has("leaderboards"):
		# TODO: 根据客户端需求自行排序
		return data["leaderboards"]
	return {}

# 保存记录到服务器
func save_leaderboard_data(type: int, data: Dictionary) -> bool:
	var json_string = JSON.stringify(data)
	var result = await ApiManager.save_leaderboard_data(type, json_string)
	if result.has("error"):
		push_error("[LeaderboardManager] ✗ 上传失败: %s" % result["error"])
		return false
	elif result.has("success") and result["success"]:
		print("[LeaderboardManager] ✓ 上传成功！")
		return true
	else:
		push_warning("[LeaderboardManager] ⚠ 上传返回未知结果: %s" % result)
		return false

## ==================== 私有方法 ====================

## 创建 Survival 模式记录
func _create_survival_record(completion_time: float, death_count: int) -> Dictionary:
	return {
		"mode": "survival",
		"player_name": SaveManager.get_player_name(),
		"floor_id": SaveManager.get_floor_id(),
		"completion_time_seconds": completion_time,
		"total_death_count": death_count,
		"completed_at": _get_iso_timestamp()
	}

## 创建 Multi 模式记录
func _create_multi_record(best_wave: int, death_count: int) -> Dictionary:
	return {
		"mode": "multi",
		"player_name": SaveManager.get_player_name(),
		"floor_id": SaveManager.get_floor_id(),
		"best_wave": best_wave,
		"total_death_count": death_count,
		"achieved_at": _get_iso_timestamp()
	}

## 获取 ISO 8601 格式时间戳
func _get_iso_timestamp() -> String:
	var datetime = Time.get_datetime_dict_from_system(true)  # UTC时间
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]

## Base64 编码
func _encode_data(data: String) -> String:
	return Marshalls.utf8_to_base64(data)

## Base64 解码
func _decode_data(encoded: String) -> String:
	return Marshalls.base64_to_utf8(encoded)

## 生成哈希签名
func _generate_signature(data: String) -> String:
	var combined = data + HASH_SALT
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(combined.to_utf8_buffer())
	var hash_bytes = ctx.finish()
	return hash_bytes.hex_encode()

## 验证哈希签名
func _verify_signature(data: String, signature: String) -> bool:
	var expected = _generate_signature(data)
	return expected == signature

## 清除损坏的数据
func _clear_corrupted_data() -> void:
	records = {
		"survival": null,
		"multi": null
	}
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
