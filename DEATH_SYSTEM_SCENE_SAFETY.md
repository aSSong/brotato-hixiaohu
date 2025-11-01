# 死亡系统 - 场景切换安全性修复

## 🐛 问题

点击"放弃"后报错：
```
Cannot call method 'create_timer' on a null value.
```

**位置**：`Scripts/enemies/wave_system_v3.gd` - `_show_shop()` 函数

## 🔍 问题分析

### 发生场景

```
玩家HP降到0
    ↓
等待3秒期间，玩家击杀了最后一个敌人
    ↓
波次完成 → _check_wave_complete()
    ↓
调用 _show_shop()
    ↓
【开始等待2秒】
print("波次完成，2秒后打开商店...")
await get_tree().create_timer(2.0).timeout  ← 在这里等待
    ↓
【此时玩家点击了"放弃"】
    ↓
death_manager 切换场景到 start_menu.tscn
    ↓
bg_map.tscn 场景被卸载
wave_system_v3 节点被移除
get_tree() 返回 null
    ↓
【2秒计时器结束，尝试继续执行】
await 后面的代码执行
但是 get_tree() 已经是 null ❌
    ↓
错误：Cannot call method 'create_timer' on a null value
```

### 核心问题

在 `await` 期间，场景可能被切换，导致节点不再在场景树中：

```gdscript
await get_tree().create_timer(2.0).timeout  // 开始等待
// 【在这2秒内，场景可能被切换】
get_tree().paused = true  // ← 这里 get_tree() 可能已经是 null
```

## ✅ 解决方案

在每个 `await` 前后添加 `is_inside_tree()` 检查：

### 修复1：`_show_shop()` 函数

```gdscript
func _show_shop() -> void:
    if current_state != WaveState.WAVE_COMPLETE:
        return
    
    print("[WaveSystem V3] 波次完成，2秒后打开商店...")
    
    # 检查节点是否还在场景树中
    if not is_inside_tree():
        return
    
    await get_tree().create_timer(2.0).timeout
    
    # 再次检查（可能在等待期间场景被切换）
    if not is_inside_tree():
        return
    
    # 继续后续逻辑...
```

### 修复2：`_on_shop_closed()` 函数

```gdscript
func _on_shop_closed() -> void:
    # ...
    
    # 延迟开始下一波
    if not is_inside_tree():
        return
    
    await get_tree().create_timer(1.0).timeout
    
    # 再次检查节点状态
    if not is_inside_tree():
        return
    
    if current_wave < wave_configs.size():
        start_next_wave()
```

## 🛡️ 防护机制

### `is_inside_tree()` 的作用

```gdscript
is_inside_tree()
```

返回值：
- `true` - 节点在场景树中，可以安全使用 `get_tree()`
- `false` - 节点已被移除或场景已切换，不应继续执行

### 检查时机

```
await 之前检查
    ↓
await get_tree().create_timer(...).timeout
    ↓
await 之后立即检查
```

**为什么需要两次检查？**
1. **await 前**：确保可以安全创建计时器
2. **await 后**：确保在等待期间场景没有被切换

## 📊 完整流程（带保护）

```
波次完成
    ↓
_show_shop()
    ↓
检查 is_inside_tree() ✓
    ↓
await 2秒
    ↓
【如果在等待期间点击"放弃"】
├─ 场景切换到主菜单
├─ wave_system_v3 被移除
└─ is_inside_tree() = false
    ↓
检查 is_inside_tree() ✗
    ↓
return（提前退出，不再执行后续代码）
    ↓
✅ 不会有错误！
```

## 🎯 修复的场景

### 场景1：正常波次完成

```
波次完成
    ↓
等待2秒（玩家还活着）
    ↓
is_inside_tree() = true ✓
    ↓
商店打开 ✓
```

### 场景2：等待期间玩家死亡并放弃

```
波次完成
    ↓
开始等待2秒
    ↓
【1秒后玩家点击"放弃"】
    ↓
场景切换
    ↓
is_inside_tree() = false ✗
    ↓
提前退出 ✓
```

### 场景3：商店关闭后切换场景

```
商店关闭
    ↓
开始等待1秒
    ↓
【此时玩家做了某些操作导致场景切换】
    ↓
is_inside_tree() = false ✗
    ↓
提前退出 ✓
```

## 🔧 技术细节

### `is_inside_tree()` vs `get_tree() != null`

```gdscript
// 不推荐 ❌
if get_tree() != null:
    await get_tree().create_timer(1.0).timeout

// 推荐 ✅
if is_inside_tree():
    await get_tree().create_timer(1.0).timeout
```

**原因**：
- `is_inside_tree()` 是专门用来检查节点是否在场景树中
- 更语义化，更清晰
- 性能更好（不需要获取树引用）

### 为什么不能只检查一次？

```gdscript
// 错误示例 ❌
func _show_shop():
    if not is_inside_tree():
        return
    
    await get_tree().create_timer(2.0).timeout
    // 这里可能场景已经切换了！
    get_tree().paused = true  // ← 可能出错
```

**问题**：
- `await` 会暂停执行
- 在暂停期间，场景可能被切换
- 继续执行时，节点可能已不在场景树中

**正确做法**：
```gdscript
// 正确示例 ✅
func _show_shop():
    if not is_inside_tree():
        return
    
    await get_tree().create_timer(2.0).timeout
    
    if not is_inside_tree():  // ← 再次检查！
        return
    
    get_tree().paused = true  // ← 安全
```

## 📝 修改的文件

**Scripts/enemies/wave_system_v3.gd**
- `_show_shop()` - 添加两次 `is_inside_tree()` 检查
- `_on_shop_closed()` - 添加两次 `is_inside_tree()` 检查

## 🧪 测试场景

### 测试1：正常流程
1. 玩家击杀所有敌人
2. 等待2秒
3. 商店打开
4. ✅ 无错误

### 测试2：波次完成后立即放弃
1. 玩家HP降到0，但击杀了最后的敌人
2. 波次完成，开始等待2秒
3. 玩家点击"放弃"
4. 场景切换
5. ✅ 无错误（提前退出）

### 测试3：商店关闭后切换场景
1. 商店打开
2. 商店关闭，开始等待1秒
3. （某些情况导致场景切换）
4. ✅ 无错误（提前退出）

## 💡 最佳实践

### 在所有 await 使用场景中应用

```gdscript
// 模板
func my_async_function():
    // 1. 检查节点状态
    if not is_inside_tree():
        return
    
    // 2. 异步操作
    await get_tree().create_timer(1.0).timeout
    
    // 3. 再次检查节点状态
    if not is_inside_tree():
        return
    
    // 4. 继续后续逻辑
    // ...
```

### 适用场景

任何使用 `await` 的地方，如果：
- 在等待期间可能发生场景切换
- 在等待期间节点可能被移除
- 需要使用 `get_tree()` 等场景树相关方法

都应该添加 `is_inside_tree()` 检查。

---

**现在点击"放弃"不会再报错了！** ✅

