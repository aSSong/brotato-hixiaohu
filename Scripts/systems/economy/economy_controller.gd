extends Node
class_name EconomyController

## 经济控制器 - 统一管理游戏经济系统

signal transaction_completed(currency_type: String, amount: int, reason: String)
signal transaction_failed(currency_type: String, amount: int, reason: String)

## 货币类型
enum CurrencyType {
	GOLD,        # 金币（钥匙）
	MASTER_KEY,  # 主钥匙
	EXP,         # 经验值
	SCORE        # 分数
}

## 尝试花费货币
func try_spend(currency: CurrencyType, amount: int, reason: String = "") -> bool:
	if not can_afford(currency, amount):
		transaction_failed.emit(_currency_name(currency), amount, reason)
		return false
	
	_deduct_currency(currency, amount)
	transaction_completed.emit(_currency_name(currency), -amount, reason)
	return true

## 添加货币
func add_currency(currency: CurrencyType, amount: int, reason: String = "") -> void:
	_add_currency(currency, amount)
	transaction_completed.emit(_currency_name(currency), amount, reason)

## 检查是否有足够的货币
func can_afford(currency: CurrencyType, amount: int) -> bool:
	match currency:
		CurrencyType.GOLD:
			return GameMain.gold >= amount
		CurrencyType.MASTER_KEY:
			return GameMain.master_key >= amount
		CurrencyType.EXP:
			return false  # EXP不用于消费
		CurrencyType.SCORE:
			return false  # Score不用于消费
	return false

## 获取货币数量
func get_currency_amount(currency: CurrencyType) -> int:
	match currency:
		CurrencyType.GOLD:
			return GameMain.gold
		CurrencyType.MASTER_KEY:
			return GameMain.master_key
		CurrencyType.EXP:
			return 0  # TODO: 从玩家获取
		CurrencyType.SCORE:
			return GameMain.score
	return 0

## 内部：扣除货币
func _deduct_currency(currency: CurrencyType, amount: int) -> void:
	match currency:
		CurrencyType.GOLD:
			GameMain.gold -= amount
		CurrencyType.MASTER_KEY:
			GameMain.master_key -= amount

## 内部：添加货币
func _add_currency(currency: CurrencyType, amount: int) -> void:
	match currency:
		CurrencyType.GOLD:
			GameMain.gold += amount
		CurrencyType.MASTER_KEY:
			GameMain.master_key += amount
		CurrencyType.EXP:
			pass  # TODO: 添加到玩家经验
		CurrencyType.SCORE:
			GameMain.score += amount

## 获取货币名称
func _currency_name(currency: CurrencyType) -> String:
	match currency:
		CurrencyType.GOLD: return "gold"
		CurrencyType.MASTER_KEY: return "master_key"
		CurrencyType.EXP: return "exp"
		CurrencyType.SCORE: return "score"
	return "unknown"

## 计算复活费用
func get_revive_cost() -> int:
	return GameConfig.revive_base_cost * (GameMain.revive_count + 1)

## 计算商店刷新费用
func get_shop_refresh_cost(refresh_count: int) -> int:
	# 基础费用 * (1 + 刷新次数)
	return GameConfig.shop_refresh_base_cost * (1 + refresh_count)
