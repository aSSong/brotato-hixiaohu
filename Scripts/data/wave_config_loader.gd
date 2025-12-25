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
	
	# 预处理：允许配置文件包含尾逗号/注释（避免因格式小问题导致整套波次回退）
	content = _sanitize_json(content)
	
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

## ========== JSON 预处理（容错）==========
## 支持：
## 1) 去掉 // 行注释 与 /* */ 块注释（仅在字符串外生效）
## 2) 去掉尾逗号：  { "a": 1, } / [1,2,]
static func _sanitize_json(text: String) -> String:
	var cleaned := text
	cleaned = _strip_json_comments(cleaned)
	cleaned = _strip_trailing_commas(cleaned)
	return cleaned

static func _strip_trailing_commas(text: String) -> String:
	var re := RegEx.new()
	# 匹配：逗号 + 可选空白 + 右花括号/右中括号
	re.compile(",(\\s*[}\\]])")
	return re.sub(text, "\\1", true)

static func _strip_json_comments(text: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var in_string := false
	var escape := false
	var i := 0
	var n := text.length()
	
	while i < n:
		var c := text[i]
		
		if in_string:
			parts.append(c)
			if escape:
				escape = false
			elif c == "\\":
				escape = true
			elif c == "\"":
				in_string = false
			i += 1
			continue
		
		# 字符串开始
		if c == "\"":
			in_string = true
			parts.append(c)
			i += 1
			continue
		
		# 注释开始（仅在字符串外）
		if c == "/" and (i + 1) < n:
			var next := text[i + 1]
			# // 行注释：跳到行尾（保留换行）
			if next == "/":
				i += 2
				while i < n and text[i] != "\n":
					i += 1
				continue
			# /* */ 块注释：跳到结束标记
			if next == "*":
				i += 2
				while (i + 1) < n and not (text[i] == "*" and text[i + 1] == "/"):
					i += 1
				# 吃掉 */
				i = min(i + 2, n)
				continue
		
		parts.append(c)
		i += 1
	
	# 兼容：不同 Godot 版本里字符串拼接接口差异较大，这里用最稳妥的逐段拼接避免解析期报错
	var result := ""
	for s in parts:
		result += s
	return result

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
	# 兼容两种格式：
	# 1) 旧格式：{wave, spawn_interval, hp_growth, damage_growth, total_count, enemies, boss_config?, special_spawns?}
	# 2) 新 Phase 格式：{wave, base_config?, spawn_phases, boss_config?, special_spawns?}
	if not wave.has("wave"):
		push_error("[WaveConfigLoader] 波次 %d 缺少字段: wave" % wave_number)
		return false
	
	# ========== 新 Phase 格式 ==========
	if wave.has("spawn_phases"):
		if not (wave.spawn_phases is Array):
			push_error("[WaveConfigLoader] 波次 %d spawn_phases 必须是数组" % wave_number)
			return false
		if wave.spawn_phases.is_empty():
			push_error("[WaveConfigLoader] 波次 %d spawn_phases 不能为空" % wave_number)
			return false
		
		# base_config 可选，但若存在必须是 Dictionary
		if wave.has("base_config") and not (wave.base_config is Dictionary):
			push_error("[WaveConfigLoader] 波次 %d base_config 必须是字典" % wave_number)
			return false
		
		# 校验每个 phase
		for p_idx in range(wave.spawn_phases.size()):
			var phase = wave.spawn_phases[p_idx]
			if not (phase is Dictionary):
				push_error("[WaveConfigLoader] 波次 %d phase[%d] 必须是字典" % [wave_number, p_idx])
				return false
			
			# enemy_types 必须存在且为字典（否则刷怪无意义）
			if not phase.has("enemy_types") or not (phase.enemy_types is Dictionary):
				push_error("[WaveConfigLoader] 波次 %d phase[%d] 缺少 enemy_types 或类型错误" % [wave_number, p_idx])
				return false
			if (phase.enemy_types as Dictionary).is_empty():
				push_error("[WaveConfigLoader] 波次 %d phase[%d] enemy_types 不能为空" % [wave_number, p_idx])
				return false
			
			# total_count 允许缺省（由上层给默认），但若存在应为非负数
			var total_count = int(phase.get("total_count", 0))
			if total_count < 0:
				push_error("[WaveConfigLoader] 波次 %d phase[%d] total_count 不能为负数" % [wave_number, p_idx])
				return false
			
			# 概率/权重和提示（允许不为1或100；EnemySpawnerV3 会按权重总和归一化抽取）
			var sum := 0.0
			for enemy_id in phase.enemy_types:
				sum += float(phase.enemy_types[enemy_id])
			# 仅提示：既不接近 1，也不接近 100，且不是 0
			if sum > 0.0 and abs(sum - 1.0) > 0.01 and abs(sum - 100.0) > 0.01:
				push_warning("[WaveConfigLoader] 波次 %d phase[%d] enemy_types 权重和异常(不接近1或100)：%s" % [wave_number, p_idx, str(sum)])
		
		# boss_config 可选：若存在，允许 count=0 或 enemy_id=""
		if wave.has("boss_config"):
			if not (wave.boss_config is Dictionary):
				push_error("[WaveConfigLoader] 波次 %d boss_config 必须是字典" % wave_number)
				return false
			var bc = wave.boss_config
			var bc_count = int(bc.get("count", 0))
			if bc_count < 0:
				push_error("[WaveConfigLoader] 波次 %d boss_config.count 不能为负数" % wave_number)
				return false
		
		# special_spawns 可选：若存在应为数组
		if wave.has("special_spawns") and not (wave.special_spawns is Array):
			push_error("[WaveConfigLoader] 波次 %d special_spawns 必须是数组" % wave_number)
			return false
		
		return true
	
	# ========== 旧格式 ==========
	var required_fields = ["spawn_interval", "hp_growth", "damage_growth", "total_count", "enemies"]
	for field in required_fields:
		if not wave.has(field):
			push_error("[WaveConfigLoader] 波次 %d 缺少字段: %s" % [wave_number, field])
			return false
	
	# 验证敌人配比
	if not (wave.enemies is Dictionary):
		push_error("[WaveConfigLoader] 波次 %d enemies 必须是字典" % wave_number)
		return false
	
	# 验证配比总和（允许一定误差；这里仅提示，刷怪侧会按权重总和归一化）
	var total_ratio = 0.0
	for enemy_id in wave.enemies:
		total_ratio += float(wave.enemies[enemy_id])
	if total_ratio > 0.0 and abs(total_ratio - 1.0) > 0.01 and abs(total_ratio - 100.0) > 0.01 and not wave.has("special_spawns"):
		push_warning("[WaveConfigLoader] 波次 %d enemies 权重和异常(不接近1或100)：%s" % [wave_number, str(total_ratio)])
	
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

