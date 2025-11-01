# 波次系统重构 V3 - 全新设计

## 为什么需要重构？

### 旧系统的问题（V2.x）

```
问题1: 计数不准确
├─ enemies_alive_this_wave 依赖手动增减
├─ Ghost击杀、生成失败等情况导致计数错误
└─ 结果：场上有敌人但计数为0，商店提前打开

问题2: 组查询也不可靠
├─ get_nodes_in_group("enemy") 仍然不准
├─ 敌人 queue_free() 但还在组里
└─ 结果：场上没敌人但查询到1个

问题3: 职责混乱
├─ WaveManager 既管理波次又处理生成回调
├─ now_enemies 既生成敌人又通知wave_manager
└─ 信号连接复杂，容易遗漏
```

## V3 新设计原则

### 1. **直接引用追踪** - 最可靠的方式
```gdscript
# 不依赖计数，不依赖组，直接持有敌人引用
var active_enemies: Array[Enemy] = []

# 生成时添加
active_enemies.append(enemy)

# 死亡时移除
active_enemies.remove_at(index)

# 判断波次结束
if active_enemies.is_empty():
    wave_complete()
```

### 2. **单一职责** - 清晰分工
```
WaveSystemV3 (wave_system_v3.gd)
├─ 职责：波次逻辑、状态管理、敌人追踪
├─ 不负责：生成敌人、查找位置
└─ 核心：直接持有敌人引用数组

EnemySpawnerV3 (enemy_spawner_v3.gd)
├─ 职责：生成敌人、查找位置
├─ 不负责：波次逻辑、计数
└─ 核心：生成成功就通知wave_system

now_enemies.gd (集成层)
├─ 职责：初始化两个系统，连接它们
└─ 不负责：具体逻辑
```

### 3. **状态机** - 防止状态混乱
```gdscript
enum WaveState {
    IDLE,           # 空闲
    SPAWNING,       # 生成中
    FIGHTING,       # 战斗中
    WAVE_COMPLETE,  # 波次完成
    SHOP_OPEN,      # 商店开启
}

# 每次状态变化都有日志
func _change_state(new_state):
    print("状态变化：", old_state, " -> ", new_state)
    current_state = new_state
```

### 4. **信号驱动** - 解耦通信
```
生成器 --enemy--> WaveSystem
   |                   |
   |                   v
   |              追踪数组 active_enemies[]
   |                   |
   |                   v
   |              监听 enemy_killed 信号
   |                   |
   |                   v
   |              从数组移除
   |                   |
   v                   v
 继续生成         检查是否全部清空
```

## 核心实现

### WaveSystemV3 的核心逻辑

```gdscript
class_name WaveSystemV3

# ========== 直接追踪敌人 ==========
var active_enemies: Array = []  # 存活敌人的直接引用

# 敌人生成时
func on_enemy_spawned(enemy: Node) -> void:
    active_enemies.append(enemy)  # 添加引用
    
    # 监听两个信号：
    enemy.enemy_killed.connect(_on_enemy_died)  # 被击杀
    enemy.tree_exiting.connect(_on_enemy_removed)  # queue_free
    
    # 检查是否生成完毕
    if spawned >= total:
        _change_state(FIGHTING)

# 敌人死亡时
func _on_enemy_died(enemy_ref: Node) -> void:
    _remove_enemy(enemy_ref)

func _on_enemy_removed(enemy_ref: Node) -> void:
    _remove_enemy(enemy_ref)

func _remove_enemy(enemy_ref: Node) -> void:
    var index = active_enemies.find(enemy_ref)
    if index != -1:
        active_enemies.remove_at(index)
        _check_wave_complete()

# 检查波次完成（核心！）
func _check_wave_complete() -> void:
    # 清理无效引用
    _cleanup_invalid_enemies()
    
    # 直接检查数组是否为空
    if active_enemies.is_empty():
        print("波次完成！")
        _show_shop()
```

### 为什么这样设计更可靠？

**旧方式（计数）：**
```gdscript
# 生成时 +1
enemies_alive += 1

# 击杀时 -1
enemies_alive -= 1

# 判断
if enemies_alive <= 0:
    wave_complete()

# 问题：如果某处没调用 +=/-=，计数就错了
```

**新方式（直接引用）：**
```gdscript
# 生成时添加引用
active_enemies.append(enemy)

# 击杀时移除引用（监听信号自动触发）
active_enemies.remove_at(index)

# 判断
if active_enemies.is_empty():
    wave_complete()

# 优势：
# 1. 不依赖计数，直接看数组
# 2. 信号自动触发，不会遗漏
# 3. 可以直接检查引用有效性
```

## 完整流程

```
游戏开始
    ↓
WaveSystemV3.start_game()
    ↓
start_next_wave()
    ↓
状态: IDLE → SPAWNING
    ↓
wave_system.spawn_wave(config) → EnemySpawnerV3
    ↓
[生成器异步生成敌人]
    ↓
每个敌人生成成功:
    spawner.on_enemy_spawned(enemy) → wave_system.on_enemy_spawned(enemy)
        ↓
        active_enemies.append(enemy)
        连接 enemy.enemy_killed 信号
        连接 enemy.tree_exiting 信号
    ↓
生成完毕 (spawned == total):
    状态: SPAWNING → FIGHTING
    ↓
[玩家战斗，击杀敌人]
    ↓
敌人被击杀:
    enemy.enemy_killed.emit() → wave_system._on_enemy_died()
        ↓
        active_enemies.remove_at(index)
        ↓
        _check_wave_complete()
            ↓
            _cleanup_invalid_enemies()  # 清理无效引用
            ↓
            if active_enemies.is_empty():  # 直接检查数组
                状态: FIGHTING → WAVE_COMPLETE
                ↓
                打开商店
                状态: WAVE_COMPLETE → SHOP_OPEN
                暂停游戏
                ↓
                [玩家选择升级]
                ↓
                商店关闭
                状态: SHOP_OPEN → IDLE
                恢复游戏
                ↓
                延迟1秒
                ↓
                start_next_wave()  # 循环
```

## 防护机制

### 1. 状态检查
```gdscript
func start_next_wave() -> void:
    if current_state == SPAWNING or current_state == FIGHTING:
        push_warning("波次进行中，忽略")
        return
    
    if current_state == SHOP_OPEN:
        push_warning("商店开启中，忽略")
        return
    
    # 继续...
```

### 2. 引用有效性检查
```gdscript
func _cleanup_invalid_enemies() -> void:
    var valid = []
    for enemy in active_enemies:
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
            valid.append(enemy)
    active_enemies = valid
```

### 3. 双信号监听
```gdscript
# 情况1: 正常击杀
enemy.enemy_killed.connect(_on_enemy_died)

# 情况2: 直接 queue_free（可能被其他方式移除）
enemy.tree_exiting.connect(_on_enemy_removed)

# 两个都会调用 _remove_enemy()，内部会去重
```

## 对比：V2 vs V3

| 特性 | V2（旧） | V3（新） |
|------|---------|----------|
| 追踪方式 | 计数 | 直接引用数组 |
| 可靠性 | ❌ 计数可能错误 | ✅ 100%准确 |
| 职责分工 | ❌ 混乱 | ✅ 清晰 |
| 状态管理 | ❌ 隐式 | ✅ 显式状态机 |
| 调试难度 | ❌ 难（计数黑盒） | ✅ 易（直接看数组） |
| Ghost影响 | ❌ 会导致计数错误 | ✅ 不影响（只追踪引用） |
| 生成失败 | ❌ 会导致卡住 | ✅ 正确处理 |

## 代码量对比

### V2 (wave_manager.gd): ~260行
- 混杂了波次逻辑、生成管理、商店逻辑
- 各种计数变量、补偿逻辑

### V3:
- **wave_system_v3.gd**: ~280行（纯波次逻辑）
- **enemy_spawner_v3.gd**: ~120行（纯生成逻辑）
- **now_enemies.gd**: ~60行（集成层）

总计：460行，但**职责清晰**，**易于维护**

## 优势总结

### ✅ 可靠性
- 不依赖计数，不依赖组查询
- 直接持有引用，100%准确
- 双信号监听，不会遗漏

### ✅ 可维护性
- 单一职责，每个类功能清晰
- 显式状态机，状态变化可追踪
- 完整日志，容易调试

### ✅ 可扩展性
- 新增敌人类型：只需添加到数据库
- 新增波次逻辑：只需修改 WaveSystemV3
- 新增生成规则：只需修改 EnemySpawnerV3

### ✅ 鲁棒性
- Ghost击杀不影响（只看引用）
- 生成失败正确处理（只看成功生成的）
- 引用失效自动清理（cleanup函数）

## 预期效果

### 日志输出示例
```
[WaveSystem V3] ========== 第 1 波开始 ==========
[WaveSystem V3] 目标敌人数：10
[WaveSystem V3] 状态变化：IDLE -> SPAWNING
[EnemySpawner V3] 开始生成第 1 波
[EnemySpawner V3] 生成列表：10 个敌人
[WaveSystem V3] 敌人生成：1/10 | 存活：1
[WaveSystem V3] 敌人生成：2/10 | 存活：2
...
[WaveSystem V3] 敌人生成：10/10 | 存活：10
[EnemySpawner V3] 生成完成
[WaveSystem V3] ========== 生成完毕，进入战斗 ==========
[WaveSystem V3] 状态变化：SPAWNING -> FIGHTING
[WaveSystem V3] 场上敌人数：10
[WaveSystem V3] 敌人移除 | 剩余：9/10
[WaveSystem V3] 敌人移除 | 剩余：8/10
...
[WaveSystem V3] 敌人移除 | 剩余：0/10
[WaveSystem V3] ========== 第 1 波完成！==========
[WaveSystem V3] 已生成：10 目标：10
[WaveSystem V3] 状态变化：FIGHTING -> WAVE_COMPLETE
[WaveSystem V3] ========== 打开商店 ==========
[WaveSystem V3] 状态变化：WAVE_COMPLETE -> SHOP_OPEN
[玩家选择升级]
[WaveSystem V3] ========== 商店关闭 ==========
[WaveSystem V3] 状态变化：SHOP_OPEN -> IDLE
[WaveSystem V3] ========== 第 2 波开始 ==========
```

### 不会再出现的问题
1. ❌ 商店开着时场上有敌人
2. ❌ 场上没敌人但不开商店
3. ❌ 击杀数超过目标数
4. ❌ 波次卡住不前进
5. ❌ 商店期间开始新波次

## 测试建议

1. **正常流程**：击杀所有敌人 → 商店打开 → 关闭 → 下一波
2. **Ghost测试**：让Ghost击杀敌人，看是否正确结束波次
3. **生成失败**：减少地图空间，看是否正确处理
4. **极端情况**：快速击杀，看状态转换是否正确

现在可以测试新系统了！🎮

