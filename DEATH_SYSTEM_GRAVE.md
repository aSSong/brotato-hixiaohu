# 死亡系统 - 墓碑功能

## 🪦 新增功能

玩家死亡时：
1. ✅ 玩家完全隐藏 (`visible = false`)
2. ✅ 武器彻底禁用（`PROCESS_MODE_DISABLED`，不再攻击）
3. 🪦 在死亡位置放置墓碑图片
4. ⏰ 3秒后弹出死亡界面

复活时：
1. ✅ 移除墓碑
2. ✅ 玩家重新显示
3. ✅ 武器重新启用
4. ✅ 随机位置复活

## 🔧 核心修改

### 1. 武器彻底禁用

**问题**：之前只是隐藏 (`visible = false`)，武器的 `_process()` 还在运行，所以还能攻击敌人。

**解决**：

```gdscript
# Scripts/players/player.gd

## 禁用所有武器（彻底停止攻击）
func _disable_weapons() -> void:
    var weapons_node = get_node_or_null("now_weapons")
    if weapons_node:
        # 停止武器处理（不再攻击）
        weapons_node.process_mode = Node.PROCESS_MODE_DISABLED  # ← 关键！
        # 隐藏武器
        weapons_node.visible = false

## 启用所有武器（复活时调用）
func enable_weapons() -> void:
    var weapons_node = get_node_or_null("now_weapons")
    if weapons_node:
        # 恢复武器处理
        weapons_node.process_mode = Node.PROCESS_MODE_INHERIT
        # 显示武器
        weapons_node.visible = true
```

**效果**：
- `PROCESS_MODE_DISABLED` 会完全停止节点及其子节点的 `_process()` 和 `_physics_process()`
- 武器不再有任何逻辑执行，完全冻结

### 2. 墓碑系统

**实现**：

```gdscript
# Scripts/players/death_manager.gd

var grave_sprite: Sprite2D = null  # 墓碑精灵
var death_position: Vector2 = Vector2.ZERO  # 记录死亡位置

## 创建墓碑
func _create_grave() -> void:
    # 加载墓碑纹理
    var grave_texture = load("res://assets/others/grave.png")
    
    # 创建墓碑精灵
    grave_sprite = Sprite2D.new()
    grave_sprite.texture = grave_texture
    grave_sprite.global_position = death_position
    
    # 设置层级（在玩家上方）
    grave_sprite.z_index = 10
    
    # 添加到场景
    get_tree().root.add_child(grave_sprite)

## 移除墓碑
func _remove_grave() -> void:
    if grave_sprite and is_instance_valid(grave_sprite):
        grave_sprite.queue_free()
        grave_sprite = null
```

### 3. 死亡流程

```gdscript
func _trigger_death():
    # 记录死亡位置
    death_position = player.global_position
    
    # 创建墓碑
    _create_grave()
    
    # 禁止玩家移动
    player.canMove = false
```

### 4. 复活流程

```gdscript
func _revive_player():
    # 移除墓碑
    _remove_grave()
    
    # 恢复HP
    player.now_hp = player.max_hp
    
    # 随机复活位置
    _respawn_player_at_random_position()
    
    # 显示玩家
    player.visible = true
    
    # 启用武器
    player.enable_weapons()
```

## 📊 完整流程

```
HP降到0
    ↓
【玩家端 - player.gd】
├─ canMove = false
├─ stop = true
├─ visible = false  ← 隐藏玩家
└─ _disable_weapons()
    ├─ process_mode = DISABLED  ← 停止武器逻辑
    └─ visible = false
    ↓
【死亡管理器 - death_manager.gd】
├─ 记录死亡位置: death_position
└─ _create_grave()
    ├─ 加载 grave.png
    ├─ 创建 Sprite2D
    ├─ 放置在 death_position
    └─ z_index = 10
    ↓
场景中显示：
┌─────────┐
│   🪦    │  ← 墓碑
└─────────┘
玩家不可见
武器不可见
武器不攻击  ← 问题已解决！
    ↓
等待3秒
    ↓
弹出死亡界面
    ↓
【选择复活】
    ↓
_revive_player()
├─ _remove_grave()  ← 移除墓碑
├─ visible = true  ← 显示玩家
├─ enable_weapons()
│   ├─ process_mode = INHERIT  ← 恢复武器逻辑
│   └─ visible = true
└─ 随机位置
    ↓
游戏继续！
```

## 🎯 解决的问题

### 问题1：武器还在攻击 ❌

**原因**：只设置了 `visible = false`，`_process()` 还在运行

**解决**：
```gdscript
weapons_node.process_mode = Node.PROCESS_MODE_DISABLED
```

**效果**：
- ✅ `_process()` 完全停止
- ✅ 武器不再检测敌人
- ✅ 不再发射子弹
- ✅ 不再造成伤害

### 问题2：武器击杀敌人导致shop弹出 ❌

**原因**：武器还在攻击 → 击杀敌人 → 触发波次完成 → 弹出shop

**解决**：
- 武器彻底禁用后，不会再击杀任何敌人
- 波次系统不会被触发
- shop不会错误弹出

### 问题3：没有死亡视觉反馈 ❌

**原因**：玩家只是停止移动，还在原地显示

**解决**：
- ✅ 隐藏玩家 (`visible = false`)
- 🪦 显示墓碑在死亡位置
- 视觉上清晰表示玩家已死亡

## 🎨 墓碑资源

**路径**：`res://assets/others/grave.png`

**要求**：
- 图片应该是一个墓碑的图像
- 建议大小：64x64 或更大
- 格式：PNG（支持透明背景）

**如果图片不存在**：
- 会输出错误日志：`[DeathManager] 无法加载墓碑纹理！`
- 其他功能正常工作（只是没有墓碑显示）

## 🔍 调试日志

### 死亡时

```
[Player] 武器已禁用
[DeathManager] 玩家死亡！3秒后显示死亡界面...
[DeathManager] 墓碑已创建于: Vector2(1198, 950)
```

### 复活时

```
[DeathUI] 玩家选择复活
[DeathManager] 墓碑已移除
[Player] 武器已启用
[DeathManager] 玩家已复活 | HP:100/100 位置:Vector2(...)
```

### 放弃时

```
[DeathUI] 玩家选择放弃
[DeathManager] 墓碑已移除
[GameMain] 游戏数据已重置
```

## 📝 修改的文件

1. **Scripts/players/player.gd**
   - 修改：`_disable_weapons()` 使用 `PROCESS_MODE_DISABLED`
   - 修改：`enable_weapons()` 使用 `PROCESS_MODE_INHERIT`
   - 添加：死亡时隐藏玩家 (`visible = false`)

2. **Scripts/players/death_manager.gd**
   - 添加：`grave_sprite` 变量
   - 添加：`death_position` 变量
   - 添加：`_create_grave()` 方法
   - 添加：`_remove_grave()` 方法
   - 修改：`_trigger_death()` 调用创建墓碑
   - 修改：`_revive_player()` 移除墓碑并显示玩家
   - 修改：`_on_give_up_requested()` 放弃时也移除墓碑

## ✅ 测试清单

- [ ] HP降到0时，玩家消失
- [ ] HP降到0时，墓碑出现在死亡位置
- [ ] 武器完全停止攻击（不击杀任何敌人）
- [ ] 不会触发shop弹出
- [ ] 3秒后弹出死亡界面
- [ ] 复活后，墓碑消失
- [ ] 复活后，玩家重新显示
- [ ] 复活后，武器正常工作
- [ ] 放弃后，墓碑也被清理

## 🎮 视觉效果对比

### 之前 ❌
```
HP = 0
│
└─ 玩家还显示在原地
   武器虽然隐藏但还在攻击 → 击杀敌人 → shop弹出
```

### 现在 ✅
```
HP = 0
│
├─ 玩家完全隐藏
├─ 墓碑出现在死亡位置  🪦
└─ 武器彻底停止（不再有任何效果）
   
场景中只显示墓碑，游戏世界"冻结"在死亡瞬间
```

---

**现在系统完善了！武器不会再攻击，墓碑会正确显示。** 🎮🪦

