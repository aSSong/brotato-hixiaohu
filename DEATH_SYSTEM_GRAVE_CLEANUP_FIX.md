# 墓碑残留问题修复

## 🐛 问题

在放弃游戏后进入主菜单再开始新游戏，上一局的墓碑还残留在场上。

## 🔍 原因分析

### 问题代码（旧）

```gdscript
func _create_grave():
    # ...
    get_tree().root.add_child(grave_sprite)  // ← 添加到root！
```

**问题**：
1. 墓碑被添加到 `root` 节点
2. `root` 是整个游戏树的根节点，不会随场景切换而清理
3. 场景切换流程：
   ```
   游戏场景 (bg_map)
       ↓
   玩家死亡 → 创建墓碑 → 添加到root
       ↓
   玩家放弃 → 切换到主菜单
       ↓
   bg_map场景被卸载 ✓
   DeathManager被销毁 ✓
   但是墓碑还在root中！ ✗
       ↓
   开始新游戏 → 加载bg_map
       ↓
   旧墓碑还在显示！ ✗
   ```

### 为什么只是"比较小的概率"？

因为只有在以下情况下才会出现：
1. 玩家死亡（创建了墓碑）
2. 并且点击"放弃"（没有复活，墓碑没被移除）
3. 然后开始新游戏

如果玩家选择复活，墓碑会被 `_remove_grave()` 清理掉。

## ✅ 解决方案

### 修复1：将墓碑添加到当前场景

```gdscript
func _create_grave():
    # ...
    
    # 添加到当前场景而不是root（避免场景切换后残留）
    if player and player.get_parent():
        player.get_parent().add_child(grave_sprite)
    else:
        push_warning("[DeathManager] 无法找到合适的父节点放置墓碑")
```

**优势**：
- 墓碑成为场景的一部分
- 场景切换时会自动清理
- 更符合Godot的场景树管理

### 修复2：在DeathManager销毁时清理墓碑

```gdscript
func _exit_tree():
    _remove_grave()
    print("[DeathManager] 已清理")
```

**作用**：
- 双重保险
- 即使墓碑因为某些原因没被及时清理
- DeathManager销毁时会强制清理

## 📊 完整流程对比

### 修复前 ❌

```
游戏场景
    ↓
玩家死亡 → 墓碑创建
    ├─ grave_sprite 添加到 root
    └─ 墓碑显示 🪦
    ↓
玩家放弃
    ↓
场景切换
    ├─ bg_map 卸载 ✓
    ├─ DeathManager 销毁 ✓
    └─ 墓碑还在 root ✗
    ↓
新游戏开始
    ├─ 加载新的 bg_map
    └─ 旧墓碑还在显示 ✗ 🪦 (残留)
```

### 修复后 ✅

```
游戏场景
    ↓
玩家死亡 → 墓碑创建
    ├─ grave_sprite 添加到 player.get_parent() (bg_map)
    └─ 墓碑显示 🪦
    ↓
玩家放弃
    ↓
场景切换
    ├─ bg_map 卸载
    │   └─ 墓碑作为子节点被一起清理 ✓
    └─ DeathManager._exit_tree()
        └─ _remove_grave() 双重保险 ✓
    ↓
新游戏开始
    └─ 全新的场景，没有残留 ✓
```

## 🎯 关键改进

### 1. 节点层级

**之前**：
```
root
└─ grave_sprite (独立，不会被场景清理)
```

**现在**：
```
root
└─ bg_map
    ├─ player
    ├─ enemies
    └─ grave_sprite (场景的一部分，随场景清理)
```

### 2. 生命周期管理

**之前**：
- 依赖手动清理（复活时或放弃时）
- 放弃时可能遗漏清理

**现在**：
- 自动清理（场景切换）
- 双重保险（_exit_tree）

## 🧪 测试场景

### 测试1：正常复活
```
死亡 → 墓碑创建
    ↓
复活 → _remove_grave() 清理 ✓
```

### 测试2：放弃游戏（修复前会有问题）
```
死亡 → 墓碑创建（添加到bg_map）
    ↓
放弃 → 场景切换
    ├─ bg_map被卸载
    └─ 墓碑作为bg_map的子节点被自动清理 ✓
    ↓
新游戏 → 干净的场景 ✓
```

### 测试3：多次死亡和放弃
```
第1局：死亡 → 放弃
第2局：开始 → 没有残留 ✓
第2局：死亡 → 放弃
第3局：开始 → 没有残留 ✓
```

## 💡 Godot 场景树管理最佳实践

### 临时节点应该添加到哪里？

**根据生命周期决定**：

1. **随场景存在的节点** → 添加到场景中
   ```gdscript
   current_scene.add_child(node)
   player.get_parent().add_child(node)  // 通常就是场景
   ```

2. **跨场景的持久节点** → 添加到autoload或root
   ```gdscript
   get_tree().root.add_child(node)
   ```

3. **UI节点** → 根据是否跨场景决定
   ```gdscript
   // 场景内UI
   current_scene.add_child(ui)
   
   // 全局UI（如暂停菜单）
   get_tree().root.add_child(ui)
   ```

### 墓碑应该属于哪类？

**答案**：随场景存在的临时装饰物

**理由**：
- 只在当前游戏局中有意义
- 与玩家死亡位置相关（场景内位置）
- 不应该跨越场景边界
- 应该随场景卸载而清理

## 🔧 代码变更总结

### 修改的文件
**Scripts/players/death_manager.gd**

### 关键修改

1. **_create_grave()**
   ```gdscript
   // 之前
   get_tree().root.add_child(grave_sprite)
   
   // 现在
   player.get_parent().add_child(grave_sprite)
   ```

2. **新增 _exit_tree()**
   ```gdscript
   func _exit_tree():
       _remove_grave()  // 双重保险
   ```

## ✅ 验证修复

### 测试步骤

1. **开始游戏**
2. **让玩家死亡**
3. **等待3秒，死亡界面弹出**
4. **观察墓碑出现** 🪦
5. **点击"放弃"**
6. **返回主菜单**
7. **再次开始游戏**
8. **检查是否有残留墓碑** ← 应该没有！

### 预期日志

```
[DeathManager] 墓碑已创建于: Vector2(1200, 800)
[玩家点击放弃]
[DeathManager] 墓碑已移除
[DeathManager] 已清理
[场景切换]
[新游戏开始 - 应该没有墓碑]
```

---

**现在墓碑不会在场景切换后残留了！** 🪦✅

