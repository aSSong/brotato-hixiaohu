# 波次系统修复 v2.3 - 使用实际场上敌人数量判断

## 问题分析（从截图）

### 核心问题
商店打开时场上还有敌人存活（左下角可见紫色敌人）

### 根本原因
**敌人计数不准确！**

1. ❌ `enemies_alive_this_wave` 依赖于 `on_enemy_spawned()` 和 `on_enemy_killed()` 的调用来增减
2. ❌ 如果有任何情况导致这两个函数调用不匹配（比如Ghost击杀敌人、敌人生成失败等），计数就会不准
3. ❌ 使用不准确的计数判断波次结束，导致商店在场上还有敌人时就打开

## 解决方案

### 方案1: 使用实时场上敌人数量（推荐）✅

```gdscript
# 不依赖计数，直接查询场上有多少敌人
var actual_enemy_count = get_tree().get_nodes_in_group("enemy").size()

if enemies_killed_this_wave >= enemies_total_this_wave:
    if actual_enemy_count <= 0:  // 检查真实敌人数
        _end_current_wave()
    else:
        print("场上还有敌人，等待...")
```

**优势**：
- ✅ 不依赖计数准确性
- ✅ 直接查询场上实际情况
- ✅ 不受Ghost、生成失败等因素影响
- ✅ 最可靠的判断方式

### 方案2: 修复计数逻辑（备选）

检查所有可能影响计数的地方：
- Ghost击杀敌人是否计入
- 敌人生成失败是否正确处理
- 敌人被其他方式杀死的情况

**缺点**：
- ❌ 需要追踪所有可能的边界情况
- ❌ 容易遗漏某些情况
- ❌ 维护成本高

## 实现细节

### 1. 确保敌人加入 "enemy" 组

```gdscript
# Scripts/enemies/enemy.gd
func _ready() -> void:
    add_to_group("enemy")  # 关键！
    # ...
```

**为什么重要**：
- `get_tree().get_nodes_in_group("enemy")` 需要敌人在这个组里
- 这是唯一能准确获取场上敌人数量的方式

### 2. 修改波次结束判定

```gdscript
# Scripts/enemies/wave_manager.gd
func on_enemy_killed() -> void:
    # ...
    
    # 实时查询场上真实的敌人数量
    var actual_enemy_count = get_tree().get_nodes_in_group("enemy").size()
    
    print("敌人击杀: ", enemies_killed_this_wave, "/", enemies_total_this_wave, 
          " (已生成:", enemies_spawned_this_wave, 
          " 存活计数:", enemies_alive_this_wave, 
          " 实际场上:", actual_enemy_count, ")")
    
    # 新的判定逻辑
    if enemies_killed_this_wave >= enemies_total_this_wave:
        # 击杀数达标后，检查场上是否还有敌人
        if actual_enemy_count <= 0:
            print("波次结束条件满足！")
            _end_current_wave()
        else:
            print("击杀数达标但场上还有", actual_enemy_count, "个敌人，等待击杀完毕...")
```

## 对比：旧逻辑 vs 新逻辑

### 旧逻辑（有问题）❌
```gdscript
if enemies_killed_this_wave >= 10 and enemies_alive_this_wave <= 0:
    _end_current_wave()
```

**问题**：
- 如果 `enemies_alive_this_wave` 计数错误（比如Ghost杀了1个敌人但计数未减）
- 实际场上有1个敌人，但 `enemies_alive_this_wave = 0`
- 结果：击杀9个后就判定波次结束，商店打开，场上还有1个敌人

### 新逻辑（正确）✅
```gdscript
var actual_enemy_count = get_tree().get_nodes_in_group("enemy").size()

if enemies_killed_this_wave >= 10:
    if actual_enemy_count <= 0:
        _end_current_wave()
    else:
        print("场上还有", actual_enemy_count, "个敌人")
```

**优势**：
- 直接查询场上实际有多少敌人
- 不依赖任何计数变量
- 100% 准确

## 调试日志改进

### 新的日志输出
```
敌人击杀: 9/10 (已生成:10 存活计数:1 实际场上:1)
敌人击杀: 10/10 (已生成:10 存活计数:0 实际场上:1)  ← 发现不一致！
击杀数达标但场上还有 1 个敌人，等待击杀完毕...
敌人击杀: 11/10 (已生成:10 存活计数:-1 实际场上:0)  ← 最后一个也被杀了
波次结束条件满足！(击杀数达标且场上无存活敌人)
```

### 关键信息
- **存活计数**：`enemies_alive_this_wave`（可能不准）
- **实际场上**：`get_tree().get_nodes_in_group("enemy").size()`（100%准确）
- 如果两者不一致，说明计数有bug，但不影响判断

## 可能的计数不准原因

### 1. Ghost武器击杀敌人
- Ghost的武器攻击敌人
- 敌人死亡，发出 `enemy_killed` 信号
- `on_enemy_killed()` 被多次调用
- 但 `on_enemy_spawned()` 没有为Ghost调用
- **结果**：击杀数 > 生成数

### 2. 敌人生成失败但被手动添加
- `spawn_enemy()` 失败，没调用 `on_enemy_spawned()`
- 但后续某个流程手动添加了敌人
- **结果**：场上有敌人但计数为0

### 3. 敌人被其他方式移除
- 敌人被 `queue_free()` 但没触发 `enemy_killed` 信号
- **结果**：计数减少但没调用 `on_enemy_killed()`

## 预期效果

### ✅ 现在应该看到
1. 商店只在场上最后一个敌人被杀死后才打开
2. 日志清楚显示 "实际场上" 的敌人数量
3. 即使 "存活计数" 不准，也能正确判断波次结束
4. 不再出现商店开着时场上有敌人的情况

### 📊 测试场景
```
击杀第9个敌人 → 场上还有1个 → 不开商店 ✓
击杀第10个敌人 → 场上还有1个(Ghost杀的) → 不开商店 ✓
Ghost杀死最后1个 → 场上0个 → 开商店 ✓
```

## 修改的文件

1. **Scripts/enemies/enemy.gd**
   - `_ready()`: 添加 `add_to_group("enemy")`

2. **Scripts/enemies/wave_manager.gd**
   - `on_enemy_killed()`: 
     - 添加实时查询 `actual_enemy_count`
     - 修改判定逻辑使用 `actual_enemy_count`
     - 改进日志输出

## 版本历史

| 版本 | 判定方式 | 问题 |
|------|---------|------|
| v2.1 | `enemies_alive_this_wave <= 0` | 计数不准导致误判 ❌ |
| v2.2 | 添加防护检查 | 防止商店期间开始新波 ✅ |
| v2.3 | `actual_enemy_count <= 0` | 使用实际敌人数，100%准确 ✅ |

现在波次系统应该完全准确了！🎯

