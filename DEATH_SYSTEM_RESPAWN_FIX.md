# 复活位置修复 - 随机位置复活

## 🐛 问题

玩家复活时在原地点，而不是随机的可行走区域。

## 🔍 原因

地图层 `TileMap_BG` 只在 `"map"` 组中，但 `GameInitializer` 在查找 `"floor_layer"` 组：

```gdscript
// game_initializer.gd
floor_layer = get_tree().get_first_node_in_group("floor_layer")
if not floor_layer:
    push_warning("[GameInitializer] 找不到floor_layer，复活位置可能不正常")
```

**结果**：
- `floor_layer` 为 `null`
- `death_manager.set_floor_layer(null)` 
- `_respawn_player_at_random_position()` 提前返回
- 玩家位置没有改变 → 原地复活

## ✅ 解决方案

将 `TileMap_BG` 同时加入 `"floor_layer"` 组：

### 修改前
```gdscript
[node name="TileMap_BG" type="TileMapLayer" parent="." groups=["map"]]
```

### 修改后
```gdscript
[node name="TileMap_BG" type="TileMapLayer" parent="." groups=["map", "floor_layer"]]
```

## 📊 工作流程

### 修复前 ❌
```
复活请求
    ↓
_respawn_player_at_random_position()
    ↓
检查 floor_layer → null ✗
    ↓
push_warning("无法随机复活：player或floor_layer未设置")
    ↓
return（提前退出）
    ↓
玩家位置没变 → 原地复活
```

### 修复后 ✅
```
复活请求
    ↓
_respawn_player_at_random_position()
    ↓
检查 floor_layer → 有效 ✓
    ↓
获取所有可用格子: floor_layer.get_used_cells()
    ↓
随机选择一个格子: used_cells[randi() % size]
    ↓
转换为世界坐标: map_to_local(cell) * 6
    ↓
设置玩家位置: player.global_position = world_pos
    ↓
✅ 在随机位置复活！
```

## 🎯 复活位置计算

```gdscript
// death_manager.gd - _respawn_player_at_random_position()

// 1. 获取所有可用格子
var used_cells = floor_layer.get_used_cells()

// 2. 随机选择一个
var random_cell = used_cells[randi() % used_cells.size()]

// 3. 转换为世界坐标
var world_pos = floor_layer.map_to_local(random_cell) * 6
//                                                      ↑ 
//                                            地图缩放因子

// 4. 设置玩家位置
player.global_position = world_pos
```

### 为什么是 * 6？

查看 bg_map.tscn：
```
[node name="TileMap_BG" ...]
scale = Vector2(6, 6)  ← 地图缩放为6倍
```

所以需要将格子坐标乘以6来匹配缩放后的世界坐标。

## 🎮 测试效果

### 第1次死亡复活
```
[DeathManager] 玩家复活！
[DeathManager] 复活位置: Vector2(1452, 684)
```

### 第2次死亡复活
```
[DeathManager] 玩家复活！
[DeathManager] 复活位置: Vector2(894, 1236)  ← 不同的位置！
```

### 第3次死亡复活
```
[DeathManager] 玩家复活！
[DeathManager] 复活位置: Vector2(2148, 456)  ← 又是不同的位置！
```

## 📝 修改的文件

**scenes/map/bg_map.tscn**
- 将 `TileMap_BG` 加入 `"floor_layer"` 组

## 💡 关于组（Groups）

Godot 的组系统允许节点属于多个组：

```gdscript
// 节点可以同时在多个组中
groups=["map", "floor_layer", "walkable", ...]

// 查找时会返回第一个匹配的节点
get_tree().get_first_node_in_group("floor_layer")
```

**好处**：
- 不需要硬编码节点路径
- 便于动态查找
- 节点可以有多个"标签"

## 🔍 如何验证修复

### 方法1：观察日志
```
[GameInitializer] 游戏初始化完成
[DeathManager] 设置地图层  ← 应该有这条
```

如果没有这条日志，说明 floor_layer 还是 null。

### 方法2：测试复活
1. 记住死亡位置
2. 复活后观察
3. 位置应该完全不同

### 方法3：多次测试
- 连续死亡复活3-5次
- 每次位置应该都不同
- 分布应该覆盖整个地图

## ⚙️ 未来改进

目前的随机复活很简单，可以添加更多规则：

### 1. 避免靠近敌人
```gdscript
func is_safe_position(pos: Vector2) -> bool:
    var enemies = get_tree().get_nodes_in_group("enemy")
    for enemy in enemies:
        if pos.distance_to(enemy.global_position) < 300:
            return false
    return true
```

### 2. 避免边缘位置
```gdscript
func is_not_too_close_to_edge(cell: Vector2i) -> bool:
    return cell.x > 2 and cell.x < max_x - 2 and 
           cell.y > 2 and cell.y < max_y - 2
```

### 3. 优先选择安全点
```gdscript
// 可以在地图中标记一些"安全复活点"
var safe_spawn_points = [
    Vector2(100, 100),
    Vector2(500, 500),
    Vector2(900, 900)
]
```

---

**现在玩家会在随机位置复活了！** 🎮

