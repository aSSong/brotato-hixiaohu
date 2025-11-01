# 墓碑救援系统 - BUG修复记录

## 修复日期：2025-11-01

### BUG #1：读条时死亡后无法再次触发读条

#### 问题描述
当玩家在墓碑读条期间死亡，再次复活后，无法触发新墓碑的读条系统。

#### 问题原因
1. 旧的`GraveRescueManager`在玩家死亡时被调用`force_stop_reading()`
2. 但状态没有完全重置，导致`is_in_range`等变量保持错误状态
3. 新创建的`GraveRescueManager`可能继承了一些错误状态

#### 修复方案
在`Scripts/players/grave_rescue_manager.gd`的`force_stop_reading()`方法中：
- 完全重置所有读条相关状态：
  - `is_in_range = false`
  - `rescue_progress = 0.0`
  - `is_reading = false`
- 隐藏所有UI元素（范围圈、进度条、救援界面）
- 添加更详细的调试日志

#### 修改内容
```gdscript
func force_stop_reading() -> void:
    print("[GraveRescue] 强制停止读条")
    
    if is_reading:
        _stop_reading()
    
    # 重置所有状态
    is_in_range = false
    rescue_progress = 0.0
    is_reading = false
    
    # 隐藏救援UI
    if rescue_ui and rescue_ui.visible:
        rescue_ui.hide_dialog()
        get_tree().paused = false
    
    # 隐藏范围圈和进度条
    if range_circle:
        range_circle.visible = false
    if progress_bar:
        progress_bar.visible = false
```

### BUG #2：调整救援范围

#### 需求变更
救援范围从100单位调整为400单位。

#### 修改内容
在`Scripts/players/grave_rescue_manager.gd`中：
```gdscript
const RESCUE_RANGE: float = 400.0  # 原来是 100.0
```

### 增强功能：调试日志

#### 新增日志
为了更好地追踪问题，添加了以下调试日志：

1. **设置玩家引用时**：
   ```gdscript
   print("[GraveRescue] 设置玩家引用:", player)
   ```

2. **进入救援范围时**：
   ```gdscript
   print("[GraveRescue] 进入救援范围 | 玩家HP:", player.now_hp, " | 范围:", RESCUE_RANGE)
   ```

3. **无法读条时**（玩家引用无效）：
   ```gdscript
   print("[GraveRescue] 无法读条：玩家引用无效")
   ```

4. **强制停止读条时**：
   ```gdscript
   print("[GraveRescue] 强制停止读条")
   ```

### 代码健壮性增强

#### 玩家引用检查
在`_process()`中增强了引用检查：
```gdscript
func _process(delta: float) -> void:
    if not player or not is_instance_valid(player):
        return
    
    if not grave_sprite or not is_instance_valid(grave_sprite):
        return
    # ...
```

在`_can_start_reading()`中也增加了检查：
```gdscript
func _can_start_reading() -> bool:
    # 检查玩家引用
    if not player or not is_instance_valid(player):
        print("[GraveRescue] 无法读条：玩家引用无效")
        return false
    # ...
```

## 测试建议

1. **测试读条时死亡**：
   - 让玩家死亡，复活
   - 靠近墓碑开始读条
   - 读条期间再次让玩家死亡
   - 复活后检查是否可以正常触发新墓碑的读条

2. **测试400单位范围**：
   - 确认范围圈的大小是否正确
   - 确认在400单位边界时能否正常触发

3. **观察日志输出**：
   - 检查控制台日志，确认玩家引用设置正确
   - 确认进入范围时日志输出正确
   - 确认强制停止时状态重置正确

## 文件修改清单

- ✅ `Scripts/players/grave_rescue_manager.gd` - 修复BUG + 调整范围 + 增强调试
- ✅ `GRAVE_RESCUE_SYSTEM_GUIDE.md` - 更新范围说明
- ✅ `GRAVE_RESCUE_QUICK_START.md` - 更新范围说明
- ✅ `GRAVE_RESCUE_BUG_FIX.md` - 本文档

## 状态

✅ 所有修复已完成  
✅ 文档已更新  
✅ 无linter错误  
✅ 已准备好测试

