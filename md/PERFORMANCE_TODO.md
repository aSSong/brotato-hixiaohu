# 性能优化待办事项

> 本文档记录已识别但尚未修复的性能问题，供后续优化时参考。

## ✅ 已修复的问题

### 1. Multi模式墓碑刷新卡顿
- **文件**: `Scripts/managers/multi_graves_manager.gd`
- **问题**: 每次创建墓碑时都调用 `load()` 加载纹理
- **修复**: 改用 `preload()` 在文件开头预加载

### 2. Enemy每帧重复创建SpriteFrames
- **文件**: `Scripts/enemies/enemy.gd` + `Scripts/data/enemy_data.gd`
- **问题**: 每个敌人创建时都 `load()` 纹理并创建新的 SpriteFrames
- **修复**: 在 EnemyData 层面缓存 SpriteFrames，所有同类型敌人共享

### 3. 掉落物和子弹频繁查询玩家引用
- **文件**: `Scripts/items/drop_items.gd`, `Scripts/bullets/bullet.gd`
- **问题**: 每帧或每次碰撞都调用 `get_first_node_in_group("player")`
- **修复**: 缓存 player 引用，只在引用失效时重新查询

### 4. DeathManager墓碑纹理运行时load
- **文件**: `Scripts/players/death_manager.gd`
- **问题**: 创建墓碑时使用 `load()` 加载纹理
- **修复**: 改用 `preload()` 预加载

### 5. GraveRescueManager范围圈动态绘制导致卡顿
- **文件**: `Scripts/players/grave_rescue_manager.gd`
- **问题**: 每个墓碑创建时都动态生成800x800像素的圆环图案（640,000次循环+sqrt计算）
- **修复**: 使用预加载的 `rescue_range_circle.png` 图片，所有实例共享静态纹理

---

## 🟡 待修复的问题

### 4. Ghost外观降级方案中的运行时load
- **文件**: `Scripts/players/ghost.gd` 第247行
- **问题**: 当没有预配置的SpriteFrames时，会运行时加载纹理
- **代码**:
  ```gdscript
  var full_texture: Texture = load(player_path + player_type + "-sheet.png")
  ```
- **建议**: 预加载降级方案的纹理，或确保所有职业都有 SpriteFrames 配置
- **优先级**: 🟡 中
- **难度**: 低

### 5. GhostManager每帧的重度计算
- **文件**: `Scripts/players/ghost_manager.gd` 第26-67行
- **问题**: 每帧对所有Ghost进行多次距离计算和数组切片操作
- **代码**:
  ```gdscript
  func _process(delta: float) -> void:
      # 每帧对每个Ghost计算距离、切片数组等
      for i in range(ghosts.size()):
          var distance_to_target = ghost.global_position.distance_to(target_node.global_position)
          ghost.update_path_points(player_path.slice(start_index, end_index))
  ```
- **建议**:
  - 降低更新频率（如每3帧更新一次）
  - 使用 `distance_squared_to` 代替 `distance_to`（避免开方运算）
- **优先级**: 🟢 低
- **难度**: 中

### 6. Enemy._process 每帧的冗余Shader检查
- **文件**: `Scripts/enemies/enemy.gd` 第258-259行
- **问题**: `_ensure_status_shader_applied()` 每帧被调用，即使没有状态效果
- **代码**:
  ```gdscript
  func _process(delta: float) -> void:
      # ...
      _ensure_status_shader_applied()  # 每帧调用
  ```
- **建议**: 只在状态变化时更新shader，而不是每帧检查
- **优先级**: 🟢 低
- **难度**: 低

### 7. 动画系统每次播放都复制节点
- **文件**: `Scripts/animations/animations.gd` 第24行
- **问题**: `run_animation()` 使用 `self.duplicate()` 每次都复制整个节点树
- **代码**:
  ```gdscript
  func run_animation(options):
      var all_ani = self.duplicate()  # 每次都完整复制
  ```
- **建议**: 实现对象池模式，复用动画节点
- **优先级**: 🟡 中
- **难度**: 中

### 8. 掉落物系统缺少对象池
- **文件**: `Scripts/items/drop_items.gd` 第97-116行
- **问题**: 每个敌人死亡都创建新的掉落物节点，大量敌人死亡时造成GC压力
- **代码**:
  ```gdscript
  func gen_drop_item(options):
      var all_ani = self.duplicate()  # 每个掉落物都duplicate
  ```
- **建议**: 实现对象池模式，预创建一定数量的掉落物节点并复用
- **优先级**: 🟡 中
- **难度**: 中

---

## 📊 问题优先级说明

| 优先级 | 说明 |
|-------|------|
| 🔴 高 | 直接导致用户感知的卡顿，应立即修复 |
| 🟡 中 | 影响整体性能，建议在有空时修复 |
| 🟢 低 | 微小的性能影响，可以在大版本更新时处理 |

---

## 🛠 通用优化建议

1. **减少 `get_first_node_in_group()` 调用**
   - 在 `_ready()` 或初始化时获取引用并缓存
   - 使用信号机制而不是每帧查询

2. **使用对象池模式**
   - 对于频繁创建/销毁的对象（子弹、掉落物、特效）
   - 预创建一定数量的对象并复用

3. **减少 `_process` 中的计算**
   - 只在必要时更新（如使用脏标记模式）
   - 降低不重要更新的频率

4. **避免运行时 `load()`**
   - 尽量使用 `preload()` 在文件开头预加载
   - 对于动态资源，在游戏开始时统一加载

---

*文档更新时间: 2025-12-01*

