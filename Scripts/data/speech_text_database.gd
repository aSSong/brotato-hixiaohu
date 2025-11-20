extends Node
class_name SpeechTextDatabase

## 说话文本库
## 按职业分类存储角色说话文本

static var speech_texts: Dictionary = {}

## 初始化文本库
static func initialize() -> void:
	if not speech_texts.is_empty():
		return
	
	# 战士职业文本
	speech_texts["warrior"] = [
		"为了荣耀！",
		"战斗到底！",
		"我的剑刃永不退缩！",
		"敌人，来战！",
		"这就是战士的意志！",
		"近战才是真正的战斗！",
		"我的力量无人能挡！",
		"为了胜利！"
	]
	
	# 射手职业文本
	speech_texts["ranger"] = [
		"精准射击！",
		"百步穿杨！",
		"远程才是王道！",
		"我的箭矢从不落空！",
		"保持距离，保持优势！",
		"瞄准，射击！",
		"敌人逃不出我的射程！",
		"远程火力压制！"
	]
	
	# 法师职业文本
	speech_texts["mage"] = [
		"魔法之力！",
		"元素听从我的召唤！",
		"知识就是力量！",
		"魔法才是真正的艺术！",
		"让敌人感受魔法的威力！",
		"智慧胜过蛮力！",
		"魔法爆发！",
		"元素之力，为我所用！"
	]
	
	# 平衡者职业文本
	speech_texts["balanced"] = [
		"平衡就是力量！",
		"全面发展才是王道！",
		"适应一切情况！",
		"没有弱点就是最大的优势！",
		"灵活应对！",
		"均衡发展！",
		"全能才是最强的！",
		"适应性强！"
	]
	
	# 坦克职业文本
	speech_texts["tank"] = [
		"坚不可摧！",
		"防御就是最好的进攻！",
		"我的盾牌永不破碎！",
		"承受一切攻击！",
		"我是最坚固的堡垒！",
		"防御至上！",
		"让敌人知道什么是坚不可摧！",
		"护盾就是生命！"
	]
	
	# 默认文本（如果职业不存在）
	speech_texts["default"] = [
		"继续战斗！",
		"不能放弃！",
		"坚持到底！",
		"为了胜利！"
	]

## 获取指定职业的文本列表
static func get_texts_for_class(class_id: String) -> Array:
	if speech_texts.is_empty():
		initialize()
	
	return speech_texts.get(class_id, speech_texts["default"])

## 随机获取指定职业的一句话
static func get_random_text(class_id: String) -> String:
	var texts = get_texts_for_class(class_id)
	if texts.is_empty():
		return "继续战斗！"
	
	return texts[randi() % texts.size()]
