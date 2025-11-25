extends Node

## Ghost数据库管理器
## 管理三层数据：预填充数据、本地记录、服务器数据
## 自动加载为 GhostDatabase，全局可访问

const PREFILL_CONFIG_PATH = "res://data/ghosts_config.json"
const LOCAL_SAVE_PATH = "user://ghosts_local.json"
const SERVER_CACHE_PATH = "user://ghosts_server.json"

## 三层数据存储
var prefill_ghosts: Array = []  # 预填充数据（静态）
var local_ghosts: Array = []    # 本地记录（玩家自己的死亡）
var server_ghosts: Array = []   # 服务器数据（其他玩家）

func _ready() -> void:
	_load_prefill_data()
	_load_local_data()
	await _save_server_data()
	await _load_server_data()
	print("[GhostDatabase] 初始化完成 | 预填充:%d 本地:%d 服务器:%d" % [prefill_ghosts.size(), local_ghosts.size(), server_ghosts.size()])

## 加载预填充数据（静态配置）
func _load_prefill_data() -> void:
	if not FileAccess.file_exists(PREFILL_CONFIG_PATH):
		push_warning("[GhostDatabase] 预填充配置文件不存在: %s" % PREFILL_CONFIG_PATH)
		return
	
	var file = FileAccess.open(PREFILL_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("[GhostDatabase] 无法打开预填充配置: %s" % PREFILL_CONFIG_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GhostDatabase] 解析预填充配置失败: %s" % json.get_error_message())
		return
	
	var data = json.data
	if data is Dictionary and data.has("ghosts"):
		prefill_ghosts = _convert_json_to_ghost_data_array(data["ghosts"])
		print("[GhostDatabase] 加载预填充数据: %d 条" % prefill_ghosts.size())

## 加载本地数据（玩家自己的死亡记录）
func _load_local_data() -> void:
	if not FileAccess.file_exists(LOCAL_SAVE_PATH):
		print("[GhostDatabase] 本地记录文件不存在，将在首次保存时创建")
		return
	
	var file = FileAccess.open(LOCAL_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[GhostDatabase] 无法打开本地记录: %s" % LOCAL_SAVE_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GhostDatabase] 解析本地记录失败: %s" % json.get_error_message())
		return
	
	var data = json.data
	if data is Dictionary and data.has("ghosts"):
		local_ghosts = _convert_json_to_ghost_data_array(data["ghosts"])
		print("[GhostDatabase] 加载本地记录: %d 条" % local_ghosts.size())

## 加载服务器数据（缓存）
func _load_server_data() -> void:
	var data = await ApiManager.load_ghost_data()
	if data is Dictionary and data.has("ghosts"):
		server_ghosts = _convert_json_to_ghost_data_array(data["ghosts"])

## 保存服务器数据（缓存）
func _save_server_data() -> void:
	var data = {
		"player_name": SaveManager.get_player_name(),
		"ghosts": []
	}
	for ghost_data in local_ghosts:
		data["ghosts"].append(_ghost_data_to_dict(ghost_data))
	var json_string = JSON.stringify(data, "\t")
	await ApiManager.save_ghost_data(json_string)

## 将JSON数组转换为GhostData数组
func _convert_json_to_ghost_data_array(json_array: Array) -> Array:
	var result: Array = []
	for item in json_array:
		if item is Dictionary:
			var ghost_data = _dict_to_ghost_data(item)
			if ghost_data:
				result.append(ghost_data)
	return result

## 字典转GhostData
func _dict_to_ghost_data(dict: Dictionary) -> GhostData:
	var ghost_data = GhostData.new()
	
	ghost_data.class_id = dict.get("class_id", "balanced")
	ghost_data.player_name = dict.get("player_name", "Unknown")
	ghost_data.total_death_count = dict.get("total_death_count", 1)
	ghost_data.death_count = dict.get("death_count", 1)
	ghost_data.map_id = dict.get("map_id", "")
	ghost_data.wave = dict.get("wave", 1)
	
	# 解析死亡位置
	var pos = dict.get("death_position", {"x": 960, "y": 540})
	ghost_data.death_position = Vector2(pos.get("x", 960), pos.get("y", 540))
	
	# 解析武器列表
	var weapons = dict.get("weapons", [])
	for weapon in weapons:
		if weapon is Dictionary:
			ghost_data.weapons.append({
				"id": weapon.get("id", "pistol"),
				"level": weapon.get("level", 1)
			})
	
	return ghost_data

## GhostData转字典（用于保存）
func _ghost_data_to_dict(ghost_data: GhostData) -> Dictionary:
	return {
		"class_id": ghost_data.class_id,
		"player_name": ghost_data.player_name,
		"total_death_count": ghost_data.total_death_count,
		"death_count": ghost_data.death_count,
		"map_id": ghost_data.map_id,
		"wave": ghost_data.wave,
		"death_position": {
			"x": ghost_data.death_position.x,
			"y": ghost_data.death_position.y
		},
		"weapons": ghost_data.weapons.duplicate()
	}

## 添加本地记录（玩家死亡时调用）
func add_ghost_record(ghost_data: GhostData) -> void:
	local_ghosts.append(ghost_data)
	save_local_data()
	print("[GhostDatabase] 添加本地记录: %s Wave%d" % [ghost_data.player_name, ghost_data.wave])

## 查询指定wave的ghost（合并所有数据源）
func get_ghosts_for_wave(mode_id: String, map_id: String, wave: int) -> Array:
	var result: Array = []
	
	# 优先级：服务器 > 本地 > 预填充
	var all_sources = [server_ghosts, local_ghosts, prefill_ghosts]
	
	for source in all_sources:
		for ghost_data in source:
			# 检查模式、地图、波次匹配（预填充数据中可能mode_id为空，表示通用）
			if ghost_data.map_id == map_id and ghost_data.wave == wave:
				result.append(ghost_data)
	
	print("[GhostDatabase] 查询 Map:%s Wave:%d | 找到:%d 个Ghost" % [map_id, wave, result.size()])
	return result

## 保存本地数据
func save_local_data() -> void:
	var data = {
		"ghosts": []
	}
	
	for ghost_data in local_ghosts:
		data["ghosts"].append(_ghost_data_to_dict(ghost_data))
	
	var json_string = JSON.stringify(data, "\t")
	
	var file = FileAccess.open(LOCAL_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[GhostDatabase] 无法保存本地记录: %s" % LOCAL_SAVE_PATH)
	else:
		file.store_string(json_string)
		file.close()
		print("[GhostDatabase] 本地记录已保存: %d 条" % local_ghosts.size())

	await _save_server_data()

## 保存服务器缓存
func _save_server_cache() -> void:
	var data = {
		"player_name": SaveManager.get_player_name(),
		"ghosts": []
	}
	
	for ghost_data in server_ghosts:
		data["ghosts"].append(_ghost_data_to_dict(ghost_data))
	
	var json_string = JSON.stringify(data, "\t")
	await ApiManager.save_ghost_data(json_string)

## 清空本地记录（调试用）
func clear_local_data() -> void:
	local_ghosts.clear()
	if FileAccess.file_exists(LOCAL_SAVE_PATH):
		DirAccess.remove_absolute(LOCAL_SAVE_PATH)
	print("[GhostDatabase] 本地记录已清空")

## 获取统计信息
func get_statistics() -> Dictionary:
	return {
		"prefill_count": prefill_ghosts.size(),
		"local_count": local_ghosts.size(),
		"server_count": server_ghosts.size(),
		"total_count": prefill_ghosts.size() + local_ghosts.size() + server_ghosts.size()
	}
