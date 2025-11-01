# V3系统 - 商店延迟打开

## 需求
最后一只怪杀死之后，延迟2秒再打开shop界面。

## 实现

在 `wave_system_v3.gd` 的 `_show_shop()` 函数中添加延迟：

```gdscript
func _show_shop() -> void:
    if current_state != WaveState.WAVE_COMPLETE:
        return
    
    # 延迟2秒再打开商店
    print("[WaveSystem V3] 波次完成，2秒后打开商店...")
    await get_tree().create_timer(2.0).timeout
    
    _change_state(WaveState.SHOP_OPEN)
    print("[WaveSystem V3] ========== 打开商店 ==========")
    
    # 暂停游戏
    get_tree().paused = true
    
    # ... 打开商店逻辑 ...
```

## 效果流程

```
击杀最后一个敌人
    ↓
[WaveSystem V3] 敌人移除 | 击杀：10 剩余：0/10
    ↓
[WaveSystem V3] ========== 第 1 波完成！==========
    ↓
状态: FIGHTING → WAVE_COMPLETE
    ↓
[WaveSystem V3] 波次完成，2秒后打开商店...
    ↓
【等待2秒】
  - 玩家可以继续移动
  - 玩家可以拾取掉落物（金币、钥匙）
  - 游戏未暂停
    ↓
2秒后
    ↓
状态: WAVE_COMPLETE → SHOP_OPEN
    ↓
[WaveSystem V3] ========== 打开商店 ==========
    ↓
暂停游戏
    ↓
商店界面弹出
```

## 优势

1. **缓冲时间**：给玩家2秒时间拾取掉落物
2. **体验优化**：不会突然弹出商店打断操作
3. **状态清晰**：延迟期间仍处于 WAVE_COMPLETE 状态，防止其他操作

## 日志输出

```
[WaveSystem V3] 敌人移除 | 击杀：10 剩余：0/10
[WaveSystem V3] ========== 第 1 波完成！==========
[WaveSystem V3] 已生成：10 目标：10
[WaveSystem V3] 状态变化：FIGHTING -> WAVE_COMPLETE
[WaveSystem V3] 波次完成，2秒后打开商店...
[等待2秒...]
[WaveSystem V3] ========== 打开商店 ==========
[WaveSystem V3] 状态变化：WAVE_COMPLETE -> SHOP_OPEN
```

## 可配置化（可选）

如果将来需要调整延迟时间，可以添加配置变量：

```gdscript
@export var shop_delay: float = 2.0  # 商店打开延迟（秒）

func _show_shop() -> void:
    # ...
    await get_tree().create_timer(shop_delay).timeout
    # ...
```

现在击杀最后一个敌人后，会等待2秒再打开商店，给玩家时间拾取物品！🎮

