extends Node
class_name WaveConfigLoader

## 波次配置加载器
## 从JSON文件加载波次配置数据

## 配置缓存
static var _config_cache: Dictionary = {}

## 加载波次配置
static func load_config(config_id: String) -> Dictionary:
	# 检查缓存
	if _config_cache.has(config_id):
		print("[WaveConfigLoader] 从缓存加载配置: ", config_id)
		return _config_cache[config_id]
	
	# 构建文件路径
	var file_path = "res://data/wave_configs/%s.json" % config_id
	
	# 检查文件是否存在
	if not FileAccess.file_exists(file_path):
		push_error("[WaveConfigLoader] 配置文件不存在: ", file_path)
		return {}
	
	# 打开文件
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[WaveConfigLoader] 无法打开配置文件: ", file_path, " 错误: ", FileAccess.get_open_error())
		return {}
	
	# 读取内容
	var content = file.get_as_text()
	file.close()
	
	# 解析JSON
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("[WaveConfigLoader] JSON解析失败: ", file_path, " 行: ", json.get_error_line(), " 消息: ", json.get_error_message())
		return {}
	
	var config_data = json.data
	
	# 验证配置
	if not _validate_config(config_data):
		push_error("[WaveConfigLoader] 配置验证失败: ", config_id)
		return {}
	
	# 缓存配置
	_config_cache[config_id] = config_data
	
	print("[WaveConfigLoader] 成功加载配置: ", config_id, " | 总波次: ", config_data.total_waves)
	return config_data

## 验证配置数据完整性
static func _validate_config(config: Dictionary) -> bool:
	# 检查必需字段
	if not config.has("config_id"):
		push_error("[WaveConfigLoader] 缺少字段: config_id")
		return false
	
	if not config.has("total_waves"):
		push_error("[WaveConfigLoader] 缺少字段: total_waves")
		return false
	
	if not config.has("waves"):
		push_error("[WaveConfigLoader] 缺少字段: waves")
		return false
	
	if not config.waves is Array:
		push_error("[WaveConfigLoader] waves 必须是数组")
		return false
	
	# 验证每一波的配置
	for i in range(config.waves.size()):
		var wave = config.waves[i]
		if not _validate_wave(wave, i + 1):
			return false
	
	return true

## 验证单个波次配置
static func _validate_wave(wave: Dictionary, wave_number: int) -> bool:
	# 必需字段
	var required_fields = ["wave", "spawn_interval", "hp_growth", "damage_growth", "total_count", "enemies"]
	for field in required_fields:
		if not wave.has(field):
			push_error("[WaveConfigLoader] 波次 ", wave_number, " 缺少字段: ", field)
			return false
	
	# 验证敌人配比
	if not wave.enemies is Dictionary:
		push_error("[WaveConfigLoader] 波次 ", wave_number, " enemies 必须是字典")
		return false
	
	# 验证配比总和（允许一定误差）
	var total_ratio = 0.0
	for enemy_id in wave.enemies:
		total_ratio += wave.enemies[enemy_id]
	
	# 如果没有boss_config或special_spawns，配比总和应该接近1.0
	if abs(total_ratio - 1.0) > 0.01 and not wave.has("special_spawns"):
		push_warning("[WaveConfigLoader] 波次 ", wave_number, " 敌人配比总和不为1.0: ", total_ratio)
	
	return true

## 清除缓存（用于热重载）
static func clear_cache() -> void:
	_config_cache.clear()
	print("[WaveConfigLoader] 配置缓存已清除")

## 重新加载配置（热重载）
static func reload_config(config_id: String) -> Dictionary:
	if _config_cache.has(config_id):
		_config_cache.erase(config_id)
	return load_config(config_id)

## 获取已缓存的配置列表
static func get_cached_configs() -> Array:
	return _config_cache.keys()

