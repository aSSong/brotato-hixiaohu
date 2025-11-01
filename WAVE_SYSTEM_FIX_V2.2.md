# 波次系统修复 v2.2 - 防止商店期间开始新波次

## 问题分析（从截图）

### 观察到的问题
1. ❌ Wave显示第2波（Wave: 2 (0/10)）
2. ❌ 升级商店还在显示
3. ❌ 场上有新波次的敌人在生成
4. ✅ 日志显示击杀逻辑正确（10/10, 存活:0）

### 根本原因
`_end_current_wave()` 是异步函数，使用了 `await`：
```gdscript
func _end_current_wave() -> void:
    is_wave_in_progress = false  // 立即设为false
    await _show_upgrade_shop()   // 等待商店
    await shop_closed             // 等待关闭
    start_next_wave()             // 开始下一波
```

**问题**：
- `is_wave_in_progress` 在商店打开前就设为 `false`
- 商店还在显示时，某些地方可能调用了 `start_next_wave()`
- 导致新波次在商店还开着时就开始了

## 解决方案

### 1. 添加双重防护到 `start_next_wave()`
```gdscript
func start_next_wave() -> void:
    // 防护1: 检查商店状态
    if is_shop_open:
        push_warning("商店还在开着，不能开始新波次！")
        return
    
    // 防护2: 检查波次状态
    if is_wave_in_progress:
        push_warning("已有波次在进行，不能开始新波次！")
        return
    
    // 继续开始新波次...
```

### 2. 改进 `_end_current_wave()` 的状态管理
```gdscript
func _end_current_wave() -> void:
    is_wave_in_progress = false
    is_shop_open = true  // 立即标记商店打开
    
    // 暂停游戏
    get_tree().paused = true
    
    // 等待商店打开和关闭
    await _show_upgrade_shop()
    await shop_closed
    
    // 商店关闭后
    is_shop_open = false  // 清除商店标记
    
    // 确保游戏恢复
    if get_tree().paused:
        get_tree().paused = false
    
    // 延迟1秒再开始下一波
    await get_tree().create_timer(1.0).timeout
    
    start_next_wave()
```

### 3. 暂停游戏
在商店打开前暂停游戏，防止：
- 敌人继续移动/攻击
- 武器继续攻击
- 任何异步逻辑继续执行

## 关键改进

### ✅ 防护1：商店状态检查
```gdscript
if is_shop_open:
    return  // 商店开着不能开始新波次
```

### ✅ 防护2：波次状态检查
```gdscript
if is_wave_in_progress:
    return  // 有波次进行中不能开始新波次
```

### ✅ 改进3：游戏暂停
```gdscript
get_tree().paused = true  // 商店打开前暂停
// 商店关闭后恢复
get_tree().paused = false
```

### ✅ 改进4：延迟开始
```gdscript
await get_tree().create_timer(1.0).timeout  // 延迟1秒
start_next_wave()
```

## 完整流程

```
击杀最后敌人
    ↓
on_enemy_killed() 检测到 enemies_killed=10, enemies_alive=0
    ↓
调用 _end_current_wave()
    ↓
is_wave_in_progress = false
is_shop_open = true  ← 立即标记！
    ↓
暂停游戏 (paused = true)
    ↓
打开商店
    ↓
【玩家选择升级】
    ↓
关闭商店，发出 shop_closed 信号
    ↓
is_shop_open = false
恢复游戏 (paused = false)
    ↓
等待1秒
    ↓
start_next_wave() 检查：
  - is_shop_open? NO ✓
  - is_wave_in_progress? NO ✓
    ↓
开始第2波
```

## 防护矩阵

| 时机 | is_wave_in_progress | is_shop_open | paused | 能开始新波次? |
|------|-------------------|-------------|--------|-------------|
| 第1波进行中 | true | false | false | ❌ NO |
| 第1波结束，商店打开前 | false | true | true | ❌ NO |
| 商店显示中 | false | true | true | ❌ NO |
| 商店关闭，延迟中 | false | false | false | ❌ NO (等待) |
| 延迟结束 | false | false | false | ✅ YES |

## 测试验证

### 应该看到的日志
```
敌人击杀: 10/10 (已生成:10 存活:0)
波次结束条件满足！
=== 第 1 波结束 ===
击杀: 10/10
已生成: 10 存活: 0
准备打开商店...
暂停游戏
找到升级商店，正在打开...
等待商店关闭...
【玩家操作商店】
收到商店关闭信号
商店已关闭，准备开始下一波...
恢复游戏
【等待1秒】
准备开始下一波...
=== 开始第 2 波 ===
```

### 预期效果
1. ✅ 商店显示时，游戏暂停
2. ✅ 商店显示时，没有新敌人生成
3. ✅ 商店显示时，Wave显示仍为第1波
4. ✅ 关闭商店后，延迟1秒才开始第2波
5. ✅ 第2波开始时，Wave更新为2，开始生成敌人

## 修改的文件

- **Scripts/enemies/wave_manager.gd**
  - `start_next_wave()`: 添加2个防护检查
  - `_end_current_wave()`: 改进状态管理，添加游戏暂停/恢复

## 版本对比

| 功能 | v2.1 | v2.2 (当前) |
|------|------|------------|
| 商店状态检查 | ❌ 无 | ✅ 有 |
| 波次状态检查 | ❌ 无 | ✅ 有 |
| 游戏暂停 | ❌ 仅商店内 | ✅ wave_manager也控制 |
| 延迟开始 | 0.5秒 | 1.0秒 |
| 防护级别 | 弱 | 强 |

现在波次系统应该完全稳定，不会出现商店期间开始新波次的问题了！🎉

