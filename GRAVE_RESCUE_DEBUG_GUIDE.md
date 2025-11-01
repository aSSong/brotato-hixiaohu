# 墓碑救援系统 - 调试指南

## 调试日期：2025-11-01

---

## 问题追踪

### 问题1：复活界面打开期间还是会刷怪
### 问题2：Ghost武器数量不对（应该4把，实际3把）

---

## 最新修改（v1.3）

### 修改1：加强死亡检查的安全性
**文件**: `Scripts/enemies/wave_system_v3.gd`
**位置**: `start_next_wave()`方法

```gdscript
# 检查玩家是否死亡
var tree = get_tree()
if tree == null:
    return

var death_manager = tree.get_first_node_in_group("death_manager")
if death_manager and death_manager.get("is_dead"):
    print("[WaveSystem V3] 玩家死亡，暂停开始新波次")
    if death_manager.has_signal("player_revived"):
        await death_manager.player_revived
    
    # await后重新检查tree
    tree = get_tree()
    if tree == null:
        return
    
    print("[WaveSystem V3] 玩家已复活，继续开始新波次")
```

**改进点**：
- ✅ 使用局部变量`tree`存储`get_tree()`结果
- ✅ 在`await`前后都检查`tree`是否为null
- ✅ 更安全的异步处理

### 修改2：增强Ghost创建的调试日志
**文件**: `Scripts/players/grave_rescue_manager.gd`
**位置**: `_create_ghost_from_data()`方法

新增日志：
```gdscript
print("[GraveRescue] 开始创建Ghost，职业:", ghost_data.class_id, " 武器数:", ghost_data.weapons.size())
for i in range(ghost_data.weapons.size()):
    var w = ghost_data.weapons[i]
    print("[GraveRescue] 武器", i+1, ":", w.id, " Lv.", w.level)

print("[GraveRescue] Ghost数据已设置，class_id:", new_ghost.class_id, " ghost_weapons数量:", new_ghost.ghost_weapons.size())
```

### 修改3：Ghost武器创建的调试日志
**文件**: `Scripts/players/ghost.gd`
**位置**: `_create_weapons()`方法

新增日志：
```gdscript
print("[Ghost] 创建武器，ghost_weapons数量:", ghost_weapons.size())
for i in range(ghost_weapons.size()):
    var weapon_data = ghost_weapons[i]
    print("[Ghost] 添加武器", i+1, ":", weapon_data["id"], " Lv.", weapon_data["level"])
```

---

## 调试步骤

### 测试1：追踪Ghost数据记录

1. **开始游戏，获得4把武器**
2. **让玩家死亡**
3. **观察控制台日志**，应该看到：

```
[GhostData] 玩家职业: 战士 -> ID: warrior
[GhostData] 检查玩家武器节点，子节点数量: 4
[GhostData] 记录武器: sword Lv.3
[GhostData] 记录武器: bow Lv.2
[GhostData] 记录武器: staff Lv.4
[GhostData] 记录武器: dagger Lv.1
[GhostData] 总共记录武器数量: 4
[DeathManager] 创建Ghost数据 | 职业: warrior  武器数: 4
```

**关键检查点**：
- ✅ `子节点数量`是否为4？
- ✅ `总共记录武器数量`是否为4？
- ✅ 每个武器都有ID和等级？

### 测试2：追踪Ghost创建

4. **复活玩家**
5. **靠近墓碑触发救援**
6. **选择"同意救援"**
7. **观察控制台日志**，应该看到：

```
[GraveRescue] 开始创建Ghost，职业: warrior  武器数: 4
[GraveRescue] 武器1: sword Lv.3
[GraveRescue] 武器2: bow Lv.2
[GraveRescue] 武器3: staff Lv.4
[GraveRescue] 武器4: dagger Lv.1
[GraveRescue] Ghost数据已设置，class_id: warrior  ghost_weapons数量: 4
[Ghost] 创建武器，ghost_weapons数量: 4
[Ghost] 添加武器1: sword Lv.3
[Ghost] 添加武器2: bow Lv.2
[Ghost] 添加武器3: staff Lv.4
[Ghost] 添加武器4: dagger Lv.1
[GraveRescue] Ghost创建成功！职业: warrior  武器数: 4
```

**关键检查点**：
- ✅ `开始创建Ghost`的武器数是否为4？
- ✅ `Ghost数据已设置`的`ghost_weapons数量`是否为4？
- ✅ `创建武器`的`ghost_weapons数量`是否为4？
- ✅ 实际添加的武器数是否为4？

### 测试3：复活期间刷怪问题

8. **玩到一波结束前**
9. **在最后一只怪死亡前，让玩家死亡**
10. **观察控制台日志**，应该看到：

```
[WaveSystem V3] 波次完成，2秒后打开商店...
[WaveSystem V3] 玩家死亡，延迟打开商店
（死亡UI显示）
（选择复活）
[WaveSystem V3] 玩家已复活，继续打开商店
（商店UI显示）
（关闭商店）
[WaveSystem V3] 玩家死亡，暂停开始新波次
（死亡UI显示）
（选择复活）
[WaveSystem V3] 玩家已复活，继续开始新波次
========== 第 X 波开始 ==========
```

**关键检查点**：
- ✅ 死亡UI显示期间，没有"波开始"日志？
- ✅ 复活后，才看到"波开始"日志？

---

## 可能的问题原因

### 如果Ghost武器数量不对

#### 原因1：武器数据没有被正确记录
**检查**：看`[GhostData]`日志中的`总共记录武器数量`
- 如果是0或少于4，说明`weapon_data`属性访问有问题
- 可能的原因：`weapon.get("weapon_data")`返回null

#### 原因2：数据传递过程丢失
**检查**：对比三个阶段的武器数量
1. `[GhostData] 总共记录武器数量`
2. `[GraveRescue] 开始创建Ghost，武器数`
3. `[Ghost] 创建武器，ghost_weapons数量`

如果某个阶段数量变少，说明在那个阶段数据丢失了。

#### 原因3：武器添加失败
**检查**：`[Ghost] 添加武器X`的日志数量
- 如果日志数量正确但实际武器数量不对
- 说明`weapons_node.add_weapon()`方法有问题

### 如果复活期间还是刷怪

#### 原因1：死亡检查未生效
**检查**：看是否有`[WaveSystem V3] 玩家死亡，暂停开始新波次`日志
- 如果没有这个日志，说明死亡检查未触发
- 可能原因：`death_manager.get("is_dead")`返回false

#### 原因2：await未等待
**检查**：日志顺序
- 应该是：`暂停开始新波次` → `玩家已复活` → `波开始`
- 如果顺序错了，说明await有问题

---

## 请提供的信息

测试后，请提供以下信息：

1. **控制台完整日志**（从死亡到Ghost创建完成）
2. **具体现象**：
   - Ghost实际有几把武器？
   - 武器ID和等级对吗？
   - 复活UI显示时，场上有怪物吗？
3. **关键日志截图**（如果方便）

---

## 状态

✅ 已添加大量调试日志  
✅ 已加强死亡检查安全性  
✅ 准备好追踪问题根源  

---

**版本**：v1.3  
**更新时间**：2025-11-01

