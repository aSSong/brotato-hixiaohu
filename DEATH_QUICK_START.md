# 死亡和复活系统 - 快速开始

## ✅ 已完成

死亡和复活系统已经完全实现！

## 🚀 现在需要做什么

### 在 bg_map.tscn 场景中添加初始化节点

1. 打开 `scenes/map/bg_map.tscn`
2. 在场景树根节点下添加一个子节点
3. 选择节点类型：**Node2D**
4. 命名为：**GameInitializer**
5. 在右侧检查器中，附加脚本：`res://Scripts/game_initializer.gd`
6. 保存场景

就这样！系统就可以工作了。

## 🎮 测试方法

1. **运行游戏**
2. **让玩家受伤**：靠近敌人
3. **等待HP降到0**
4. **观察**：
   - 玩家停止移动
   - 3秒后弹出死亡界面
   - 显示复活费用和金币余额

5. **点击复活**（如果金币够）：
   - 扣除金币
   - HP全恢复
   - 在随机位置复活
   - 游戏继续

6. **或点击放弃**：
   - 返回主菜单
   - 数据重置

## 📊 系统功能

### ✅ 已实现
- [x] HP ≤ 0 触发死亡
- [x] 3秒延迟后显示死亡界面
- [x] 复活费用：5 × (复活次数 + 1)
- [x] 金币检查
- [x] 随机位置复活
- [x] HP全恢复
- [x] 保留所有进度（金币、钥匙、波次等）
- [x] 放弃返回主菜单
- [x] 数据重置

### 📝 复活费用
- 第1次：5 金币
- 第2次：10 金币
- 第3次：15 金币
- ...以此类推

## 🗂️ 创建的文件

1. ✅ `Scripts/UI/death_ui.gd` - 死亡UI脚本
2. ✅ `scenes/UI/death_ui.tscn` - 死亡UI场景
3. ✅ `Scripts/players/death_manager.gd` - 死亡管理器
4. ✅ `Scripts/game_initializer.gd` - 游戏初始化脚本
5. ✅ `DEATH_SYSTEM_GUIDE.md` - 详细文档
6. ✅ `DEATH_QUICK_START.md` - 本文件

## 📝 修改的文件

1. ✅ `Scripts/players/player.gd` - 移除死亡打印
2. ✅ `Scripts/GameMain.gd` - 添加复活次数追踪

## 🔍 日志示例

运行正常时，你会看到：

```
[GameInitializer] 游戏初始化完成
[DeathManager] 初始化
[DeathManager] 设置玩家引用
[DeathManager] 设置死亡UI
[DeathManager] 设置地图层
...
（玩家HP降到0）
[DeathManager] 玩家死亡！3秒后显示死亡界面...
[DeathManager] 当前复活次数: 0
（3秒后）
[DeathManager] 显示死亡UI | 金币:50 复活费用:5
[DeathUI] 显示死亡界面 | 复活次数:0 费用:5 当前金币:50
（玩家点击复活）
[DeathUI] 玩家选择复活
[DeathManager] 玩家复活！花费:5 剩余金币:45 累计复活次数:1
[DeathManager] 玩家已复活 | HP:100/100 位置:Vector2(...)
```

## ⚠️ 注意事项

### 确保这些节点在正确的组中：
- 玩家节点：在 "player" 组
- 地图层节点：在 "floor_layer" 组

### 如果死亡界面不显示：
1. 检查是否添加了 GameInitializer 节点
2. 查看控制台日志是否有错误
3. 确认 death_ui.tscn 路径正确

### 如果复活位置不对：
- 确保地图层在 "floor_layer" 组中

## 🎨 自定义

查看 `DEATH_SYSTEM_GUIDE.md` 了解如何：
- 修改死亡延迟时间
- 调整复活费用公式
- 自定义UI外观
- 更改复活位置策略

---

**就这么简单！添加 GameInitializer 节点，然后测试游戏即可！** 🎮

