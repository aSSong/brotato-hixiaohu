extends Node
class_name EconomyController

## 经济控制器
## 统一管理金币、升级、商店逻辑

## 信号
signal transaction_completed(item_type: String, cost: int)
signal purchase_failed(reason: String)

## 引用
var session: GameSession = null

func _ready() -> void:
	# 获取当前会话
	if GameMain.current_session:
		session = GameMain.current_session
		print("[EconomyController] 已连接到游戏会话")
	else:
		push_warning("[EconomyController] 未找到游戏会话，将在需要时获取")

## 确保会话可用
func _ensure_session() -> bool:
	if not session and GameMain.current_session:
		session = GameMain.current_session
	
	if not session:
		push_error("[EconomyController] 游戏会话不可用")
		return false
	
	return true

# ========== 金币管理 ==========

## 添加金币
func add_gold(amount: int) -> void:
	if not _ensure_session():
		return
	session.add_gold(amount)
	print("[EconomyController] +%d 金币 | 总计: %d" % [amount, session.gold])

## 检查是否能支付
func can_afford(cost: int) -> bool:
	if not _ensure_session():
		return false
	return session.can_afford(cost)

## 扣除金币
func remove_gold(amount: int) -> bool:
	if not _ensure_session():
		return false
	return session.remove_gold(amount)

## 执行购买
func purchase(item_type: String, cost: int) -> bool:
	if not _ensure_session():
		purchase_failed.emit("会话不可用")
		return false
	
	if not can_afford(cost):
		print("[EconomyController] 金币不足 | 需要: %d, 拥有: %d" % [cost, session.gold])
		purchase_failed.emit("金币不足")
		return false
	
	if session.remove_gold(cost):
		print("[EconomyController] 购买成功: %s | 花费: %d" % [item_type, cost])
		transaction_completed.emit(item_type, cost)
		return true
	
	return false

# ========== 主钥管理 ==========

## 添加主钥
func add_master_key(amount: int) -> void:
	if not _ensure_session():
		return
	session.add_master_key(amount)
	print("[EconomyController] +%d 主钥 | 总计: %d" % [amount, session.master_key])

## 扣除主钥
func remove_master_key(amount: int) -> bool:
	if not _ensure_session():
		return false
	return session.remove_master_key(amount)

# ========== 复活费用计算 ==========

## 获取复活费用
func get_revive_cost() -> int:
	if not _ensure_session():
		return GameConfig.revive_base_cost
	
	return GameConfig.revive_base_cost * (session.revive_count + 1)

## 检查是否能复活
func can_revive() -> bool:
	return can_afford(get_revive_cost())

## 执行复活购买
func purchase_revive() -> bool:
	var cost = get_revive_cost()
	if purchase("复活", cost):
		if session:
			session.revive_count += 1
		return true
	return false

# ========== 商店相关 ==========

## 获取商店刷新费用
## @param refresh_count: 已刷新次数
func get_shop_refresh_cost(refresh_count: int) -> int:
	return GameConfig.shop_refresh_base_cost * pow(2, refresh_count)

## 检查是否能刷新商店
func can_refresh_shop(refresh_count: int) -> bool:
	return can_afford(get_shop_refresh_cost(refresh_count))

## 执行商店刷新购买
func purchase_shop_refresh(refresh_count: int) -> bool:
	var cost = get_shop_refresh_cost(refresh_count)
	return purchase("商店刷新", cost)

# ========== 统计信息 ==========

## 获取经济状态
func get_economy_status() -> Dictionary:
	if not _ensure_session():
		return {}
	
	return {
		"gold": session.gold,
		"master_key": session.master_key,
		"revive_count": session.revive_count,
		"next_revive_cost": get_revive_cost(),
		"can_revive": can_revive()
	}

## 打印经济状态（调试用）
func print_status() -> void:
	var status = get_economy_status()
	print("[EconomyController] 经济状态:")
	print("  - 金币: %d" % status.get("gold", 0))
	print("  - 主钥: %d" % status.get("master_key", 0))
	print("  - 复活次数: %d" % status.get("revive_count", 0))
	print("  - 下次复活费用: %d" % status.get("next_revive_cost", 0))
	print("  - 能否复活: %s" % status.get("can_revive", false))

