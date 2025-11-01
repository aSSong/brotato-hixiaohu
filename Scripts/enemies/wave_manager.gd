extends Node
class_name WaveManager

## 波次管理器
## 管理敌人的波次生成和进度

## 波次配置
## 每波配置：{"enemies": [{"id": "basic", "count": 8}], "last_enemy": {"id": "elite", "count": 1}}
## 或者简化为总数量和敌人种类分布
var wave_configs: Array = []  # 20波配置

## 当前波次
var current_wave: int = 0
var enemies_killed_this_wave: int = 0
var enemies_total_this_wave: int = 0
var enemies_spawned_this_wave: int = 0

## 状态
var is_wave_in_progress: bool = false
var is_waiting_for_next_wave: bool = false

## 信号
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal enemy_killed(wave_number: int, killed: int, total: int)
signal all_waves_completed()

## 初始化波次配置（测试数据：每波10个敌人）
func _ready() -> void:
	_initialize_test_waves()

## 初始化测试波次（20波，每波10个敌人）
func _initialize_test_waves() -> void:
	wave_configs.clear()
	
	for wave in range(20):
		var config = {
			"enemies": [
				{"id": "basic", "count": 7},  # 7个基础敌人
				{"id": "fast", "count": 2},   # 2个快速敌人
			],
			"last_enemy": {"id": "basic", "count": 1}  # 最后1个基础敌人（总计10个）
		}
		
		# 每5波增加难度
		if wave > 0 and wave % 5 == 0:
			config.enemies = [
				{"id": "basic", "count": 5},
				{"id": "fast", "count": 2},
				{"id": "tank", "count": 1}
			]
			config.last_enemy = {"id": "elite", "count": 1}
		
		wave_configs.append(config)

## 开始下一波
func start_next_wave() -> void:
	if current_wave >= wave_configs.size():
		# 所有波次完成
		all_waves_completed.emit()
		return
	
	current_wave += 1
	enemies_killed_this_wave = 0
	enemies_spawned_this_wave = 0
	
	# 计算本波总敌人数
	var config = wave_configs[current_wave - 1]
	var total_count = 0
	for enemy_group in config.enemies:
		total_count += enemy_group.count
	total_count += config.last_enemy.count
	enemies_total_this_wave = total_count
	
	is_wave_in_progress = true
	is_waiting_for_next_wave = false
	
	wave_started.emit(current_wave)
	print("开始第 ", current_wave, " 波，共 ", enemies_total_this_wave, " 个敌人")

## 获取当前波的生成列表
func get_current_wave_spawn_list() -> Array:
	if current_wave == 0 or current_wave > wave_configs.size():
		return []
	
	var config = wave_configs[current_wave - 1]
	var spawn_list = []
	
	# 添加普通敌人
	for enemy_group in config.enemies:
		for i in range(enemy_group.count):
			spawn_list.append(enemy_group.id)
	
	# 最后添加特殊敌人
	for i in range(config.last_enemy.count):
		spawn_list.append(config.last_enemy.id)
	
	return spawn_list

## 敌人被击杀
func on_enemy_killed() -> void:
	if not is_wave_in_progress:
		return
	
	enemies_killed_this_wave += 1
	enemy_killed.emit(current_wave, enemies_killed_this_wave, enemies_total_this_wave)
	
	# 检查是否杀光本波所有敌人
	if enemies_killed_this_wave >= enemies_total_this_wave:
		_end_current_wave()

## 结束当前波
func _end_current_wave() -> void:
	is_wave_in_progress = false
	wave_ended.emit(current_wave)
	print("第 ", current_wave, " 波结束！击杀: ", enemies_killed_this_wave, "/", enemies_total_this_wave)
	
	# 等待5秒后开始下一波
	if current_wave < wave_configs.size():
		is_waiting_for_next_wave = true
		await get_tree().create_timer(5.0).timeout
		start_next_wave()
