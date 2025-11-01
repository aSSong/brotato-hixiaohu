# 死亡和复活系统 - 使用说明

## 📋 功能概述

玩家HP ≤ 0时触发死亡，3秒后弹出死亡界面，玩家可以选择：
1. **复活**：消耗金币，在随机位置复活，HP全恢复，继续游戏
2. **放弃**：结束游戏，返回主菜单

## 🎮 核心特性

### 死亡流程
```
HP ≤ 0
    ↓
禁止移动
    ↓
等待 3 秒
    ↓
暂停游戏
    ↓
弹出死亡界面
```

### 复活机制
- **费用公式**：`5 × (累计复活次数 + 1)`
  - 第1次复活：5 金币
  - 第2次复活：10 金币
  - 第3次复活：15 金币
  - ...

- **复活效果**：
  - ✅ HP 全恢复
  - ✅ 在可行走区域随机位置复活
  - ✅ 保留所有进度（金币、钥匙、波次、武器、等级等）
  - ✅ 游戏继续

- **金币不足**：
  - 复活按钮显示"金币不足"
  - 按钮禁用，无法点击
  - 只能选择放弃

### 放弃机制
- 返回主菜单 (`start_menu.tscn`)
- 重置游戏数据（金币、钥匙、分数、复活次数等）
- 不保留任何进度

## 📂 文件结构

### 新建文件

1. **Scripts/UI/death_ui.gd**
   - 死亡UI控制脚本
   - 显示死亡界面和按钮
   - 发出复活/放弃信号

2. **scenes/UI/death_ui.tscn**
   - 死亡UI场景
   - 包含标题、信息、费用标签和两个按钮

3. **Scripts/players/death_manager.gd**
   - 死亡管理器
   - 监听玩家HP变化
   - 处理死亡流程（3秒延迟）
   - 处理复活/放弃逻辑
   - 管理复活次数

4. **Scripts/game_initializer.gd**
   - 游戏初始化脚本
   - 创建并连接死亡系统组件

### 修改的文件

1. **Scripts/players/player.gd**
   - 移除死亡打印
   - 死亡逻辑由 DeathManager 处理

2. **Scripts/GameMain.gd**
   - 添加 `revive_count: int = 0`
   - 在 `reset_game()` 中重置复活次数

## 🔧 集成方法

### 方法1：在bg_map.tscn中添加初始化节点

在 `bg_map.tscn` 中添加一个 Node2D 节点：
1. 添加节点：Node2D
2. 命名为：GameInitializer
3. 附加脚本：`Scripts/game_initializer.gd`

### 方法2：在现有脚本中初始化

如果 bg_map 有主脚本，在其 `_ready()` 中添加：

```gdscript
func _ready():
    # ... 其他初始化代码 ...
    
    # 初始化死亡系统
    _init_death_system()

func _init_death_system():
    var initializer = load("res://Scripts/game_initializer.gd").new()
    add_child(initializer)
```

## 💡 使用示例

### 测试死亡系统

1. **让玩家受伤**：
   - 靠近敌人让敌人攻击
   - 等待HP降到0

2. **观察流程**：
```
[DeathManager] 玩家死亡！3秒后显示死亡界面...
[DeathManager] 当前复活次数: 0
【等待3秒】
[DeathManager] 显示死亡UI | 金币:50 复活费用:5
[DeathUI] 显示死亡界面 | 复活次数:0 费用:5 当前金币:50
```

3. **选择复活**：
```
[DeathUI] 玩家选择复活
[DeathManager] 玩家复活！花费:5 剩余金币:45 累计复活次数:1
[DeathManager] 玩家已复活 | HP:100/100 位置:Vector2(...)
```

4. **再次死亡**：
```
[DeathManager] 玩家死亡！3秒后显示死亡界面...
[DeathManager] 当前复活次数: 1
[DeathManager] 显示死亡UI | 金币:45 复活费用:10
```

### 金币不足场景

```
当前金币: 8
第2次复活费用: 10

死亡界面显示：
- 复活按钮：【金币不足】（禁用）
- 放弃按钮：【放弃】（可用）
```

## 🎨 UI自定义

### 修改死亡界面外观

编辑 `scenes/UI/death_ui.tscn`：
- 调整 Panel 大小/颜色
- 修改字体大小
- 调整按钮样式

### 修改文本内容

在 `Scripts/UI/death_ui.gd` 中修改：

```gdscript
func show_death_screen(...):
    title_label.text = "游戏结束"  # 修改标题
    info_label.text = "你想怎么做？"  # 修改说明
    # ...
```

## ⚙️ 配置参数

### 死亡延迟时间

在 `Scripts/players/death_manager.gd` 中：

```gdscript
var death_delay: float = 3.0  # 修改这里，单位：秒
```

### 复活费用公式

在 `Scripts/players/death_manager.gd` 中修改费用计算：

```gdscript
# 当前公式：5 * (revive_count + 1)
func _on_revive_requested():
    var cost = 5 * (revive_count + 1)  # 修改这里
    # ...

func get_next_revive_cost():
    return 5 * (revive_count + 1)  # 同步修改
```

例如，改为指数增长：
```gdscript
var cost = 5 * (2 ** revive_count)  # 5, 10, 20, 40, 80...
```

### 复活位置策略

在 `Scripts/players/death_manager.gd` 的 `_respawn_player_at_random_position()` 中自定义：

```gdscript
func _respawn_player_at_random_position():
    # 方案1: 随机位置（当前实现）
    var random_cell = used_cells[randi() % used_cells.size()]
    
    # 方案2: 距离敌人最远的位置
    # ... 自定义逻辑 ...
    
    # 方案3: 固定安全点
    # player.global_position = Vector2(0, 0)
```

## 🔍 调试信息

所有关键操作都有日志输出，前缀为：
- `[DeathManager]` - 死亡管理器
- `[DeathUI]` - 死亡UI
- `[GameInitializer]` - 游戏初始化

### 常见日志

```
[GameInitializer] 游戏初始化完成
[DeathManager] 玩家死亡！3秒后显示死亡界面...
[DeathManager] 显示死亡UI | 金币:X 复活费用:Y
[DeathUI] 显示死亡界面 | 复活次数:N ...
[DeathUI] 玩家选择复活
[DeathManager] 玩家复活！花费:X ...
[DeathUI] 玩家选择放弃
[GameMain] 游戏数据已重置
```

## 🐛 故障排除

### 问题1：死亡界面不显示

**检查**：
1. 是否添加了 GameInitializer 节点？
2. 日志中是否有 `[GameInitializer] 游戏初始化完成`？
3. 是否有错误日志？

**解决**：
- 确保 `death_ui.tscn` 路径正确
- 确保玩家在 "player" 组中

### 问题2：复活后位置不对

**检查**：
- floor_layer 是否在 "floor_layer" 组中？
- 日志中是否有 `找不到floor_layer` 警告？

**解决**：
- 确保地图层节点加入了 "floor_layer" 组
- 或修改 `game_initializer.gd` 中的查找逻辑

### 问题3：放弃后返回错误场景

**检查**：
- 主菜单场景路径是否为 `res://scenes/UI/start_menu.tscn`？

**解决**：
- 修改 `death_manager.gd` 中的场景路径：
```gdscript
get_tree().change_scene_to_file("你的主菜单路径.tscn")
```

### 问题4：复活次数没有重置

**检查**：
- 是否在 `GameMain.reset_game()` 中重置了 `revive_count`？

**解决**：
- 确认 GameMain.gd 已更新

## 📊 数据流图

```
player.now_hp <= 0
    ↓
player.hp_changed.emit(0, max_hp)
    ↓
death_manager._on_player_hp_changed()
    ↓
death_manager._trigger_death()
    - player.canMove = false
    - 启动3秒计时器
    ↓
3秒后
    ↓
death_manager._show_death_ui()
    - get_tree().paused = true
    - death_ui.show_death_screen()
    ↓
用户点击【复活】
    ↓
death_ui.revive_requested.emit()
    ↓
death_manager._on_revive_requested()
    - GameMain.remove_gold(cost)
    - revive_count += 1
    - _revive_player()
        - player.now_hp = max_hp
        - 随机位置
        - player.canMove = true
        - get_tree().paused = false
```

## ✅ 测试清单

- [ ] HP降到0时，3秒后显示死亡界面
- [ ] 金币足够时，可以复活
- [ ] 复活后HP全恢复
- [ ] 复活后位置随机
- [ ] 复活后游戏继续，进度保留
- [ ] 复活费用随次数递增（5, 10, 15...）
- [ ] 金币不足时，复活按钮禁用
- [ ] 点击放弃，返回主菜单
- [ ] 放弃后，游戏数据重置
- [ ] 多次死亡和复活，系统稳定

现在系统已经完成，请在 bg_map 场景中添加 GameInitializer 节点即可使用！🎮

