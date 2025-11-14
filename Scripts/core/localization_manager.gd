extends Node

## 本地化管理器 - 管理多语言支持

signal locale_changed(new_locale: String)

const TRANSLATION_CSV_PATH = "res://localization/translations.csv"

var current_locale: String = "zh_CN"
var available_locales: Array = ["zh_CN", "en"]

func _ready() -> void:
	_load_translations()
	_set_initial_locale()
	print("[LocalizationManager] 本地化管理器就绪，当前语言: %s" % current_locale)

## 加载翻译文件
func _load_translations() -> void:
	# Godot会自动加载项目设置中指定的翻译文件
	# 这里我们只需要确保CSV文件被正确导入
	print("[LocalizationManager] 翻译文件已加载")

## 设置初始语言
func _set_initial_locale() -> void:
	# 尝试从系统获取语言
	var system_locale = OS.get_locale()
	
	# 如果系统语言是中文，使用中文，否则使用英文
	if system_locale.begins_with("zh"):
		current_locale = "zh_CN"
	else:
		current_locale = "en"
	
	# 应用语言设置
	TranslationServer.set_locale(current_locale)
	print("[LocalizationManager] 初始语言设置为: %s (系统: %s)" % [current_locale, system_locale])

## 切换语言
func change_locale(new_locale: String) -> void:
	if new_locale == current_locale:
		print("[LocalizationManager] 语言已经是 %s" % new_locale)
		return
	
	if new_locale not in available_locales:
		push_warning("[LocalizationManager] 不支持的语言: %s" % new_locale)
		return
	
	current_locale = new_locale
	TranslationServer.set_locale(new_locale)
	locale_changed.emit(new_locale)
	print("[LocalizationManager] 语言已切换到: %s" % new_locale)

## 获取当前语言
func get_current_locale() -> String:
	return current_locale

## 获取可用语言列表
func get_available_locales() -> Array:
	return available_locales.duplicate()

## 获取翻译文本（辅助函数）
func tr_text(key: String) -> String:
	return tr(key)
