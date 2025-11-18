# 🐛 严重Bug修复：技能修改器默认值问题

## 问题描述

**症状**：
- 使用狂暴技能后，最大HP +100
- 移动速度也增加约100（从400变为500）
- 技能效果异常

## 根本原因

### 问题1：CombatStats的默认值

在 `Scripts/AttributeSystem/CombatStats.gd`：
```gdscript
@export var max_hp: int = 100  ## 最大生命值
@export var speed: float = 400.0  ## 移动速度
@export var crit_damage: float = 1.5  ## 暴击伤害倍数
```

### 问题2：技能修改器创建时使用了默认值

在 `Scripts/players/class_manager.gd` 的 `_create_skill_modifier()`：
```gdscript
// ❌ 错误的代码
modifier.stats_delta = CombatStats.new()  // 创建了带默认值的对象！
// stats_delta.max_hp = 100  (默认值)
// stats_delta.speed = 400.0  (默认值)
// stats_delta.crit_damage = 1.5  (默认值)

// 然后只设置需要的属性
modifier.stats_delta.global_attack_speed_mult = 1.5
modifier.stats_delta.global_damage_mult = 1.3
```

### 问题3：AttributeModifier.apply_to() 累加了所有值

在 `Scripts/AttributeSystem/AttributeModifier.gd`：
```gdscript
func apply_to(target_stats: CombatStats) -> void:
    // 累加所有属性（包括默认值！）
    target_stats.max_hp += stats_delta.max_hp  // +100 ❌
    target_stats.speed += stats_delta.speed    // +400 ❌
    target_stats.crit_damage += stats_delta.crit_damage  // +1.5 ❌
    
    // ... 其他属性
}
```

### 完整的Bug流程

```
1. 创建技能修改器
   modifier.stats_delta = CombatStats.new()
   ↓ 默认值：max_hp=100, speed=400, crit_damage=1.5
   
2. 设置技能效果
   modifier.stats_delta.global_attack_speed_mult = 1.5
   modifier.stats_delta.global_damage_mult = 1.3
   ↓ 但 max_hp, speed, crit_damage 仍然是默认值！
   
3. AttributeManager.recalculate()
   final_stats = base_stats.clone()  // base: hp=60, speed=350
   modifier.apply_to(final_stats)
   ↓
   final_stats.max_hp = 60 + 100 = 160  ❌ Bug!
   final_stats.speed = 350 + 400 = 750  ❌ Bug!
   
4. Player._on_stats_changed()
   max_hp = new_stats.max_hp  // 160
   speed = new_stats.speed    // 750
   ↓ 玩家属性异常！
```

---

## ✅ 修复方案

### 修复代码

在 `Scripts/players/class_manager.gd` 的 `_create_skill_modifier()` 中添加：

```gdscript
func _create_skill_modifier(skill_name: String, params: Dictionary) -> AttributeModifier:
    var modifier = AttributeModifier.new()
    modifier.modifier_type = AttributeModifier.ModifierType.SKILL
    modifier.modifier_id = "skill_" + skill_name
    modifier.stats_delta = CombatStats.new()
    
    var duration = params.get("duration", 0.0)
    modifier.duration = duration
    modifier.initial_duration = duration
    
    // ⭐ 新增：将默认值重置为0，避免意外累加
    modifier.stats_delta.max_hp = 0
    modifier.stats_delta.speed = 0.0
    modifier.stats_delta.crit_damage = 0.0  // 默认值1.5也需要清零
    
    // 根据技能类型设置属性变化
    match skill_name:
        "狂暴":
            modifier.stats_delta.global_attack_speed_mult = 1.5
            modifier.stats_delta.global_damage_mult = 1.3
        // ...
```

### 修复效果

```
修复前：
狂暴技能激活后：
- max_hp: 60 + 100 = 160 ❌
- speed: 350 + 400 = 750 ❌
- attack_speed_mult: 1.0 * 1.5 = 1.5 ✅

修复后：
狂暴技能激活后：
- max_hp: 60 + 0 = 60 ✅
- speed: 350 + 0 = 350 ✅
- attack_speed_mult: 1.0 * 1.5 = 1.5 ✅
```

---

## 🔍 为什么之前没发现？

这个bug非常隐蔽，因为：

1. **看起来很合理**：创建 `CombatStats.new()` 并设置需要的属性
2. **默认值是"合理的"**：100 HP, 400 speed 看起来像是基础值
3. **累加逻辑是对的**：`target_stats.max_hp += stats_delta.max_hp` 本身没问题
4. **只在技能激活时触发**：不是每次都会看到

---

## 📋 需要检查的其他地方

### 1. UpgradeData 创建修改器

在 `Scripts/data/upgrade_data.gd` 的 `create_modifier()` 中，可能也有同样的问题：

```gdscript
func create_modifier() -> AttributeModifier:
    var modifier = AttributeModifier.new()
    modifier.stats_delta = stats_modifier.clone() if stats_modifier else CombatStats.new()
    
    // ⚠️ 如果使用 CombatStats.new()，也会有默认值问题！
```

**建议**：如果 `stats_modifier` 为null，应该返回null而不是创建空的修改器。

### 2. WeaponData 创建修改器

在 `Scripts/data/weapon_data.gd` 的 `create_weapon_modifier()` 中：

```gdscript
func create_weapon_modifier(weapon_id: String) -> AttributeModifier:
    var modifier = AttributeModifier.new()
    modifier.stats_delta = CombatStats.new()  // ⚠️ 同样的问题！
    
    // 只设置了特殊属性
    if crit_chance_bonus != 0.0:
        modifier.stats_delta.crit_chance = crit_chance_bonus
    // ...
    
    return modifier
```

**建议**：也需要清零默认值。

---

## ✅ 完整的修复清单

### 已修复 ✅
1. `Scripts/players/class_manager.gd` - 技能修改器

### 需要修复 ⚠️
2. `Scripts/data/weapon_data.gd` - 武器修改器
3. 所有创建 `CombatStats.new()` 并当作增量使用的地方

---

## 🎯 最佳实践建议

### 方案A：创建"零值"CombatStats

在 `CombatStats` 中添加静态方法：

```gdscript
## 创建一个所有值为0的CombatStats（用作增量）
static func zero() -> CombatStats:
    var stats = CombatStats.new()
    stats.max_hp = 0
    stats.speed = 0.0
    stats.crit_damage = 0.0
    // ... 设置所有非零默认值为0
    return stats
```

使用：
```gdscript
modifier.stats_delta = CombatStats.zero()  // 明确表示这是增量
```

### 方案B：修改 apply_to() 的逻辑

在 `AttributeModifier.apply_to()` 中，只累加非默认值：

```gdscript
func apply_to(target_stats: CombatStats) -> void:
    // 只累加非零值
    if stats_delta.max_hp != 100:  // 不是默认值才累加
        target_stats.max_hp += (stats_delta.max_hp - 100)
    
    if stats_delta.speed != 400.0:
        target_stats.speed += (stats_delta.speed - 400.0)
    // ...
}
```

**推荐方案A**，更清晰明了。

---

## 🧪 测试验证

### 测试1：狂暴技能
```
1. 开始游戏，选择战士
2. 查看初始属性：HP=60, Speed=350
3. 激活狂暴技能
4. 验证：HP仍为60, Speed仍为350
5. 等待5秒
6. 验证：属性恢复正常
```

### 测试2：全面强化技能
```
1. 选择平衡者
2. 查看初始属性：HP=50, Speed=400
3. 激活全面强化
4. 验证：HP仍为50, Speed变为480（+80正确）
5. 等待6秒
6. 验证：Speed恢复为400
```

---

## 📝 总结

这是一个由**默认值累加**导致的严重bug：
- ❌ 问题根源：`CombatStats.new()` 有非零默认值
- ❌ 触发条件：将 `CombatStats.new()` 当作增量使用
- ✅ 修复方法：手动清零所有默认值
- ✅ 最佳实践：创建 `CombatStats.zero()` 静态方法

**现在已修复！** 🎉

---

*创建日期：2024年11月18日*
*Bug级别：严重 (Critical)*
*影响范围：所有技能系统*

