# V3系统 - UI兼容性修复

## 问题
```
Invalid access to property or key 'enemies_killed_this_wave' on a base object of type 'Node (WaveSystemV3)'.
```

## 原因
V3系统中变量名改为 `killed_enemies_this_wave`，但UI代码还在使用旧名称 `enemies_killed_this_wave`。

## 解决方案

在 `wave_system_v3.gd` 中添加了兼容性接口：

### 1. 添加内部变量
```gdscript
var killed_enemies_this_wave: int = 0  # 用于统计击杀数
```

### 2. 添加兼容性属性（只读）
```gdscript
## 为了兼容旧代码，提供这些属性的访问
var enemies_killed_this_wave: int:
    get:
        return killed_enemies_this_wave

var enemies_total_this_wave: int:
    get:
        return total_enemies_this_wave

var enemies_spawned_this_wave: int:
    get:
        return spawned_enemies_this_wave
```

### 3. 添加信号
```gdscript
signal enemy_killed(wave_number: int, killed: int, total: int)  # 兼容UI
```

### 4. 在移除敌人时更新
```gdscript
func _remove_enemy(enemy_ref: Node) -> void:
    # ...
    killed_enemies_this_wave += 1  # 增加击杀计数
    
    # 发出击杀信号（供UI等监听）
    enemy_killed.emit(current_wave, killed_enemies_this_wave, total_enemies_this_wave)
```

### 5. 在开始新波次时重置
```gdscript
func start_next_wave() -> void:
    # ...
    killed_enemies_this_wave = 0  # 重置击杀计数
```

## 现在UI可以正常访问

```gdscript
# Scripts/UI/game_ui.gd (无需修改)
var wave_num = wave_manager_ref.current_wave
var killed = wave_manager_ref.enemies_killed_this_wave  # ✅ 现在可以正常访问
var total = wave_manager_ref.enemies_total_this_wave

wave_label.text = "Wave: %d    (%d/%d)" % [wave_num, killed, total]
```

## 优势

1. **向后兼容**：旧代码无需修改
2. **封装良好**：内部使用新名称，外部提供旧接口
3. **信号完整**：UI可以监听 `enemy_killed` 信号

现在可以正常运行了！🎮

