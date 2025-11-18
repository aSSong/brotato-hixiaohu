extends Node
class_name BuffSystem

## Buff系统
## 
## 职责：管理临时状态效果（DoT、Buff、Debuff等）
## 
## 特性：
##   - 支持持续时间和Tick机制
##   - 自动过期清理
##   - 可以修改属性和触发特殊效果
## 
## 使用示例：
##   buff_system = BuffSystem.new()
##   add_child(buff_system)
##   buff_system.add_buff("burn", 5.0, {"dps": 10.0})
##   buff_system.buff_tick.connect(_on_burn_tick)

## Buff数据类
class Buff:
	var buff_id: String = ""  ## Buff唯一标识
	var duration: float = 0.0  ## 剩余持续时间
	var tick_interval: float = 1.0  ## Tick间隔（DoT效果）
	var tick_timer: float = 0.0  ## Tick计时器
	var stats_modifier: CombatStats = null  ## 属性修改
	var special_effects: Dictionary = {}  ## 特殊效果数据
	var stacks: int = 1  ## 堆叠层数
	
	func _init(p_buff_id: String = "", p_duration: float = 0.0):
		buff_id = p_buff_id
		duration = p_duration
		stats_modifier = CombatStats.new()

## 当前所有激活的Buff
var active_buffs: Dictionary = {}  # key: buff_id, value: Buff

## 信号
signal buff_applied(buff_id: String)  ## Buff被应用
signal buff_expired(buff_id: String)  ## Buff过期
signal buff_tick(buff_id: String, tick_data: Dictionary)  ## DoT效果触发

## 添加Buff
## 
## 如果Buff已存在，根据规则刷新或堆叠
## 
## @param buff_id Buff唯一标识
## @param duration 持续时间（秒）
## @param effects 特殊效果数据字典
## @param tick_interval Tick间隔（默认1秒）
## @param allow_stack 是否允许堆叠（默认false）
func add_buff(buff_id: String, duration: float, effects: Dictionary = {}, tick_interval: float = 1.0, allow_stack: bool = false) -> void:
	if buff_id.is_empty():
		push_warning("[BuffSystem] Buff ID不能为空")
		return
	
	# 检查Buff是否已存在
	if active_buffs.has(buff_id):
		var existing_buff = active_buffs[buff_id]
		
		if allow_stack:
			# 堆叠模式：增加层数和刷新时间
			existing_buff.stacks += 1
			existing_buff.duration = duration
			print("[BuffSystem] Buff堆叠: %s (层数: %d)" % [buff_id, existing_buff.stacks])
		else:
			# 刷新模式：重置持续时间
			existing_buff.duration = duration
			print("[BuffSystem] Buff刷新: %s" % buff_id)
		
		return
	
	# 创建新Buff
	var buff = Buff.new(buff_id, duration)
	buff.tick_interval = tick_interval
	buff.special_effects = effects.duplicate()
	
	active_buffs[buff_id] = buff
	
	# 发送信号
	buff_applied.emit(buff_id)
	
	print("[BuffSystem] 添加Buff: %s, 持续: %.1f秒" % [buff_id, duration])

## 移除Buff
## 
## @param buff_id 要移除的Buff ID
func remove_buff(buff_id: String) -> void:
	if not active_buffs.has(buff_id):
		return
	
	active_buffs.erase(buff_id)
	
	# 发送信号
	buff_expired.emit(buff_id)
	
	print("[BuffSystem] 移除Buff: %s" % buff_id)

## 检查是否有某个Buff
## 
## @param buff_id Buff ID
## @return 是否存在
func has_buff(buff_id: String) -> bool:
	return active_buffs.has(buff_id)

## 获取Buff数据
## 
## @param buff_id Buff ID
## @return Buff对象，不存在返回null
func get_buff(buff_id: String) -> Buff:
	return active_buffs.get(buff_id, null)

## 获取Buff的堆叠层数
## 
## @param buff_id Buff ID
## @return 堆叠层数，不存在返回0
func get_buff_stacks(buff_id: String) -> int:
	var buff = get_buff(buff_id)
	return buff.stacks if buff else 0

## 清除所有Buff
func clear_all_buffs() -> void:
	for buff_id in active_buffs.keys():
		buff_expired.emit(buff_id)
	
	active_buffs.clear()
	print("[BuffSystem] 清除所有Buff")

## 更新所有Buff
## 
## 每帧调用，更新持续时间和Tick计时器
## 
## @param delta 时间增量（秒）
func _process(delta: float) -> void:
	if active_buffs.is_empty():
		return
	
	var expired_buffs = []
	
	# 更新每个Buff
	for buff_id in active_buffs.keys():
		var buff = active_buffs[buff_id]
		
		# 更新持续时间
		buff.duration -= delta
		
		# 更新Tick计时器
		buff.tick_timer += delta
		
		# 检查是否需要Tick
		if buff.tick_timer >= buff.tick_interval:
			buff.tick_timer -= buff.tick_interval
			
			# 构造Tick数据
			var tick_data = {
				"buff_id": buff_id,
				"stacks": buff.stacks,
				"effects": buff.special_effects
			}
			
			# 发送Tick信号
			buff_tick.emit(buff_id, tick_data)
		
		# 检查是否过期
		if buff.duration <= 0:
			expired_buffs.append(buff_id)
	
	# 移除过期的Buff
	for buff_id in expired_buffs:
		remove_buff(buff_id)

## 调试输出
func debug_print() -> void:
	print("=== BuffSystem Debug ===")
	print("激活Buff数量: ", active_buffs.size())
	for buff_id in active_buffs.keys():
		var buff = active_buffs[buff_id]
		print("  [%s] 持续: %.1fs, 层数: %d" % [buff_id, buff.duration, buff.stacks])
	print("========================")

