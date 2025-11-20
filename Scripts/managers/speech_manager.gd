extends Node
class_name SpeechManager

## 说话管理器
## 管理Player和Ghost的随机说话逻辑
## 确保同时只有一个气泡，上一个消失后等待随机时间再开始下一个

## 当前活跃的气泡
var current_bubble: Node = null  # 可能是 PlayerSpeechBubble 或 speaker 节点

## 等待下一个说话的计时器
var next_speech_timer: Timer = null

## 最小等待时间（秒）
var min_wait_time: float = 1.0

## 最大等待时间（秒）
var max_wait_time: float = 3.0

## 气泡显示持续时间
var bubble_duration: float = 5.0

## 所有可说话的角色列表（Player和Ghost）
var speakers: Array = []

var _debug = true

func _ready() -> void:
	# 创建计时器
	next_speech_timer = Timer.new()
	next_speech_timer.name = "NextSpeechTimer"
	next_speech_timer.one_shot = true
	next_speech_timer.timeout.connect(_on_next_speech_timer_timeout)
	add_child(next_speech_timer)
	
	# 开始第一个等待周期
	_start_next_speech_timer()

func _process(_delta: float) -> void:
	# 检查当前气泡是否还在显示
	if current_bubble and is_instance_valid(current_bubble):
		var is_still_showing = false
		
		# 检查speaker的speech_bubble组件的is_showing属性
		if "speech_bubble" in current_bubble:
			var bubble = current_bubble.speech_bubble
			if bubble and is_instance_valid(bubble) and "is_showing" in bubble:
				is_still_showing = bubble.is_showing
		
		# 如果气泡不再显示，开始下一个周期
		if not is_still_showing:
			current_bubble = null
			if next_speech_timer.is_stopped():
				_start_next_speech_timer()

## 注册可说话的角色
func register_speaker(speaker: Node2D) -> void:
	if speaker not in speakers:
		speakers.append(speaker)
		if _debug:
			print("[SpeechManager] 注册说话者: ", speaker.name)

## 取消注册说话者
func unregister_speaker(speaker: Node2D) -> void:
	if speaker in speakers:
		speakers.erase(speaker)
		if _debug:
			print("[SpeechManager] 取消注册说话者: ", speaker.name)

## 开始下一个说话的等待计时器
func _start_next_speech_timer() -> void:
	if current_bubble and is_instance_valid(current_bubble):
		# 如果还有气泡在显示，不启动新的计时器
		return
	
	# 随机等待时间
	var wait_time = randf_range(min_wait_time, max_wait_time)
	next_speech_timer.wait_time = wait_time
	next_speech_timer.start()
	if _debug:
		print("[SpeechManager] 等待 %.1f 秒后下一个说话" % wait_time)

## 计时器超时回调
func _on_next_speech_timer_timeout() -> void:
	# 如果当前还有气泡在显示，不创建新的
	if current_bubble and is_instance_valid(current_bubble):
		_start_next_speech_timer()
		return
	
	# 随机选择一个说话者
	_trigger_random_speech()

## 触发随机说话
func _trigger_random_speech() -> void:
	if _debug:
		print("[SpeechManager] 触发随机说话，当前说话者数量: ", speakers.size())
	
	# 过滤掉无效的说话者
	speakers = speakers.filter(func(speaker): return is_instance_valid(speaker))
	if _debug:
		print("[SpeechManager] 过滤后说话者数量: ", speakers.size())
	
	if speakers.is_empty():
		# 如果没有可用的说话者，等待一段时间再试
		if _debug:
			print("[SpeechManager] 没有可用的说话者，等待...")
		_start_next_speech_timer()
		return
	
	# 随机选择一个说话者
	var speaker = speakers[randi() % speakers.size()]
	if _debug:
		print("[SpeechManager] 选择说话者: ", speaker.name, " 类型: ", speaker.get_class())
	
	# 获取说话者的职业ID
	var class_id = _get_speaker_class_id(speaker)
	if class_id.is_empty():
		class_id = "default"
	if _debug:
		print("[SpeechManager] 职业ID: ", class_id)
	
	# 从文本库获取随机文本
	var text = SpeechTextDatabase.get_random_text(class_id)
	if _debug:
		print("[SpeechManager] 获取文本: ", text)
	
	# 显示气泡（通过speaker的方法）
	if speaker.has_method("show_speech"):
		print("[SpeechManager] 调用show_speech方法")
		speaker.show_speech(text, bubble_duration)
		if _debug:
			print("[SpeechManager] %s 说: %s" % [speaker.name, text])
		
		# 标记当前有气泡显示（通过检查speaker的speech_bubble组件）
		if "speech_bubble" in speaker and speaker.speech_bubble:
			current_bubble = speaker.speech_bubble
			if _debug:
				print("[SpeechManager] 设置current_bubble为speech_bubble组件")
		else:
			# 如果没有speech_bubble属性，使用一个标记
			current_bubble = speaker
			print("[SpeechManager] 设置current_bubble为speaker节点")
	else:
		push_warning("[SpeechManager] %s 没有show_speech方法！" % speaker.name)
		if _debug:
			print("[SpeechManager] speaker的方法列表: ", speaker.get_method_list())
		_start_next_speech_timer()

## 获取说话者的职业ID
func _get_speaker_class_id(speaker: Node2D) -> String:
	# 检查是否是Player（通过检查current_class属性）
	if "current_class" in speaker:
		var current_class = speaker.current_class
		if current_class and current_class is ClassData:
			# 通过职业名称找到对应的ID
			return _get_class_id_by_name(current_class.name)
	
	# 检查是否是Ghost（通过检查class_id属性）
	if "class_id" in speaker:
		var class_id = speaker.class_id
		if class_id is String and not class_id.is_empty():
			return class_id
	
	# 尝试通过组名判断
	if speaker.is_in_group("player"):
		# 尝试从GameMain获取
		if "selected_class_id" in GameMain:
			return GameMain.selected_class_id
	
	return ""

## 通过职业名称获取职业ID
func _get_class_id_by_name(name_str: String) -> String:
	var class_ids = ClassDatabase.get_all_class_ids()
	for class_id in class_ids:
		var class_data = ClassDatabase.get_class_data(class_id)
		if class_data and class_data.name == name_str:
			return class_id
	return "balanced"  # 默认返回平衡者
