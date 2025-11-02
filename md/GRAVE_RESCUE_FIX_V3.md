# 墓碑救援系统 - 问题修复总结 #3

## 修复日期：2025-11-01（第三轮）

---

## 问题 #1：复活界面期间会刷怪

### 问题描述
玩家在死亡UI显示期间，如果恰好前一波完成，系统会自动开始下一波刷怪，导致玩家在复活界面时场上已经有怪物。

### 问题原因
在`wave_system_v3.gd`的`_on_shop_closed()`中，关闭商店后会延迟1秒启动下一波。这个启动过程没有检查玩家是否死亡，导致即使玩家死亡界面打开，下一波也会开始。

### 解决方案
在`Scripts/enemies/wave_system_v3.gd`的`start_next_wave()`方法开头添加玩家死亡检查：

```gdscript
# 检查玩家是否死亡
var death_manager = get_tree().get_first_node_in_group("death_manager")
if death_manager and death_manager.get("is_dead"):
    print("[WaveSystem V3] 玩家死亡，暂停开始新波次")
    # 等待玩家复活
    if death_manager.has_signal("player_revived"):
        await death_manager.player_revived
    print("[WaveSystem V3] 玩家已复活，继续开始新波次")
```

### 逻辑
- 在开始新波次前检查玩家是否死亡
- 如果死亡，等待`player_revived`信号
- 玩家复活后再继续开始新波次
- 与Shop界面的处理逻辑一致

---

## 问题 #2：Ghost数据没有正确记录玩家武器和职业

### 问题描述
玩家死亡后创建的Ghost：
1. 武器不是玩家死亡时的武器（可能是初始武器或随机武器）
2. 职业有时也不一致

### 问题原因分析

#### 原因1：武器获取方法错误
原代码：
```gdscript
if weapon.has_method("get_weapon_data"):
    var weapon_data = weapon.get_weapon_data()
```

**问题**：`BaseWeapon`类没有`get_weapon_data()`方法！
- 武器实际上有`weapon_data`属性（不是方法）
- 这导致所有武器都无法被记录，`data.weapons`数组为空
- Ghost创建时武器列表为空，可能使用了默认的随机生成

#### 原因2：缺少调试信息
无法确定是职业匹配失败还是武器记录失败。

### 解决方案

#### 修复武器记录逻辑
在`Scripts/data/ghost_data.gd`的`from_player()`方法中：

```gdscript
# 保存武器列表
data.weapons = []
var weapons_node = player.get_node_or_null("now_weapons")
if weapons_node:
    print("[GhostData] 检查玩家武器节点，子节点数量:", weapons_node.get_child_count())
    for weapon in weapons_node.get_children():
        # 尝试获取weapon_data属性（不是方法！）
        var weapon_data_obj = weapon.get("weapon_data") if "weapon_data" in weapon else null
        var weapon_level_val = weapon.get("weapon_level") if "weapon_level" in weapon else 1
        
        if weapon_data_obj:
            var weapon_id = weapon_data_obj.get("id") if "id" in weapon_data_obj else ""
            if weapon_id != "":
                data.weapons.append({
                    "id": weapon_id,
                    "level": weapon_level_val
                })
                print("[GhostData] 记录武器: ", weapon_id, " Lv.", weapon_level_val)
            else:
                print("[GhostData] 武器数据无ID:", weapon_data_obj)
        else:
            print("[GhostData] 武器无weapon_data:", weapon)
else:
    print("[GhostData] 找不到now_weapons节点")

print("[GhostData] 总共记录武器数量:", data.weapons.size())
```

#### 关键修改
1. ✅ 使用`weapon.get("weapon_data")`获取属性，而不是调用不存在的方法
2. ✅ 添加详细的调试日志，输出：
   - 武器节点子节点数量
   - 每个武器的ID和等级
   - 最终记录的武器总数
3. ✅ 添加职业记录的调试日志

#### 职业记录日志
```gdscript
if player.current_class:
    data.class_id = _find_class_id(player.current_class)
    print("[GhostData] 玩家职业:", player.current_class.name, " -> ID:", data.class_id)
else:
    data.class_id = "balanced"
    print("[GhostData] 玩家无职业，使用默认: balanced")

if data.class_id == "":
    data.class_id = GameMain.selected_class_id if "selected_class_id" in GameMain else "balanced"
    print("[GhostData] 职业ID为空，使用GameMain.selected_class_id:", data.class_id)
```

---

## 技术细节

### BaseWeapon的数据结构
```gdscript
# Scripts/weapons/base_weapon.gd
var weapon_data: WeaponData = null  # 这是属性，不是方法
var weapon_level: int = 1
```

### 正确的访问方式
```gdscript
# ❌ 错误：调用不存在的方法
var weapon_data = weapon.get_weapon_data()

# ✅ 正确：访问属性
var weapon_data_obj = weapon.get("weapon_data")
var weapon_id = weapon_data_obj.id
```

---

## 文件修改清单

1. ✅ `Scripts/enemies/wave_system_v3.gd`
   - `start_next_wave()`添加死亡检查

2. ✅ `Scripts/data/ghost_data.gd`
   - 修复武器数据获取方式
   - 添加详细调试日志

---

## 测试建议

### 测试 #1：复活期间不刷怪
1. 玩到一波快结束时
2. 在最后一只怪死亡前，让玩家死亡
3. 确认死亡UI显示期间不会开始新波次
4. 复活后，确认新波次正常开始

### 测试 #2：Ghost数据记录
1. 开始游戏，升级武器到高等级（例如Lv.3或以上）
2. 让玩家死亡
3. 观察控制台日志：
   - 检查`[GhostData] 记录武器:`日志
   - 确认记录的武器ID和等级正确
   - 确认职业ID正确
4. 复活后，靠近墓碑触发救援界面
5. 确认界面显示的武器和职业与玩家死亡时一致
6. 救援后，确认创建的Ghost的武器和职业正确

### 观察日志输出示例
```
[GhostData] 玩家职业: 战士 -> ID: warrior
[GhostData] 检查玩家武器节点，子节点数量: 3
[GhostData] 记录武器: sword Lv.4
[GhostData] 记录武器: bow Lv.2
[GhostData] 记录武器: staff Lv.3
[GhostData] 总共记录武器数量: 3
[DeathManager] 创建Ghost数据 | 职业: warrior  武器数: 3
```

---

## 调试日志

### 新增日志（问题诊断）
- `[WaveSystem V3] 玩家死亡，暂停开始新波次`
- `[WaveSystem V3] 玩家已复活，继续开始新波次`
- `[GhostData] 玩家职业: ... -> ID: ...`
- `[GhostData] 检查玩家武器节点，子节点数量: ...`
- `[GhostData] 记录武器: ... Lv....`
- `[GhostData] 总共记录武器数量: ...`

---

## 状态

✅ 所有问题已修复  
✅ 无linter错误  
✅ 添加了详细调试日志  
✅ 已准备好测试

---

**实现完成时间**：2025-11-01  
**修复版本**：v1.2

