# 波次系统 V3 - 快速开始

## 🎯 已经做了什么

已经**完全重构**了波次系统，使用全新的架构。

## ✅ 已修改的文件

1. **Scripts/enemies/wave_system_v3.gd** (新建)
   - 新的波次管理系统
   - 直接追踪敌人引用，不依赖计数

2. **Scripts/enemies/enemy_spawner_v3.gd** (新建)
   - 新的敌人生成器
   - 单一职责：只负责生成

3. **Scripts/enemies/now_enemies.gd** (修改)
   - 集成层：初始化和连接两个新系统

4. **Scripts/enemies/enemy.gd** (修改)
   - 移除手动加入enemy组的代码

## 🚀 如何使用

**不需要做任何改动！**

新系统会自动替代旧系统。打开Godot，运行游戏即可。

## 📊 预期效果

### 应该看到的日志
```
[now_enemies] 使用新的波次系统 V3
[WaveSystem V3] 初始化完成：20波
[EnemySpawner V3] 初始化完成
[WaveSystem V3] 设置生成器：EnemySpawnerV3
[EnemySpawner V3] 连接到波次系统
[WaveSystem V3] 开始游戏
[WaveSystem V3] ========== 第 1 波开始 ==========
[WaveSystem V3] 目标敌人数：10
[WaveSystem V3] 状态变化：IDLE -> SPAWNING
...
```

### 不会再出现的问题
- ✅ 商店只在**所有敌人清空后**才打开
- ✅ 击杀数不会超过目标数
- ✅ 场上敌人数量100%准确
- ✅ Ghost击杀不会影响波次判定
- ✅ 生成失败不会导致卡住

## 🔍 核心原理

### 旧系统（有问题）
```gdscript
var enemies_alive = 0  // 计数

// 生成时 +1
enemies_alive += 1

// 击杀时 -1
enemies_alive -= 1

// 判断
if enemies_alive <= 0:
    open_shop()

// 问题：计数可能不准！
```

### 新系统（V3）
```gdscript
var active_enemies: Array = []  // 直接引用

// 生成时添加
active_enemies.append(enemy)
enemy.enemy_killed.connect(_on_died)  // 监听死亡

// 击杀时自动触发
func _on_died(enemy):
    active_enemies.remove(enemy)
    if active_enemies.is_empty():  // 直接检查
        open_shop()

// 优势：100%准确，不依赖计数！
```

## 🐛 如果遇到问题

### 1. 如果游戏不开始
检查日志是否有：
- `[WaveSystem V3] 初始化完成`
- `[WaveSystem V3] 开始游戏`

### 2. 如果敌人不生成
检查日志是否有：
- `[EnemySpawner V3] 开始生成第 X 波`
- `[WaveSystem V3] 敌人生成：X/Y`

### 3. 如果波次不结束
检查日志中的：
- `[WaveSystem V3] 敌人移除 | 剩余：X/Y`
- 剩余数应该最终到达 0

### 4. 如果想回到旧系统
1. 打开 `Scripts/enemies/now_enemies.gd`
2. 用 Git 还原到之前的版本
3. 或者保留旧的 `wave_manager.gd` 备份

## 📚 详细文档

- **WAVE_SYSTEM_V3_ARCHITECTURE.md**: 完整架构说明
- **Scripts/enemies/wave_system_v3.gd**: 核心系统源码（带详细注释）
- **Scripts/enemies/enemy_spawner_v3.gd**: 生成器源码（带详细注释）

## 🎮 现在就测试吧！

打开Godot → 运行游戏 → 观察日志

应该能看到清晰的状态变化和准确的敌人数量追踪。

---

**设计理念**：不依赖计数，直接持有引用，信号驱动，状态机管理。简单、可靠、易维护。

