# 属性系统重构 - 迁移指南

## 已完成的工作 ✅

### 第一阶段：核心属性系统框架
1. ✅ **CombatStats** (`Scripts/AttributeSystem/CombatStats.gd`)
   - 统一的属性容器，包含所有战斗属性
   - 支持分层加成计算（add层 + mult层）
   - 提供 `clone()` 和各种计算方法

2. ✅ **AttributeModifier** (`Scripts/AttributeSystem/AttributeModifier.gd`)
   - 表示单个属性修改来源
   - 支持永久和临时效果
   - 类型安全的修改器系统

3. ✅ **AttributeManager** (`Scripts/AttributeSystem/AttributeManager.gd`)
   - 统一管理所有属性加成
   - 自动过期处理
   - 发送 `stats_changed` 信号

### 第二阶段：特殊效果系统
4. ✅ **BuffSystem** (`Scripts/AttributeSystem/BuffSystem.gd`)
   - 管理临时状态效果（DoT、Buff、Debuff）
   - 支持堆叠和Tick机制
   - 自动过期清理

5. ✅ **SpecialEffects** (`Scripts/AttributeSystem/SpecialEffects.gd`)
   - 燃烧、冰冻、中毒、吸血效果处理
   - 所有特效统一管理
   - 静态方法，易于调用

6. ✅ **DamageCalculator** (`Scripts/AttributeSystem/DamageCalculator.gd`)
   - 统一所有伤害计算逻辑
   - 武器伤害、防御减伤、暴击、攻速、范围等
   - 完整的计算公式文档

### 第三阶段：数据类重构
7. ✅ **ClassData** 重构 (`Scripts/data/class_data.gd`)
   - 添加 `base_stats: CombatStats` 字段
   - 保留旧属性以兼容现有代码
   - 新增 `sync_to_base_stats()` 方法

8. ✅ **UpgradeData** 重构 (`Scripts/data/upgrade_data.gd`)
   - 添加 `stats_modifier: CombatStats` 字段
   - 新增 `create_modifier()` 方法
   - 保留 `attribute_changes` 兼容性

9. ✅ **ClassDatabase** 更新 (`Scripts/data/class_database.gd`)
   - 所有职业调用 `sync_to_base_stats()`
   - 新系统和旧系统双轨运行

10. ✅ **UpgradeDatabase** 文档更新 (`Scripts/data/upgrade_database.gd`)
    - 添加新系统使用示例
    - 保留旧系统兼容性

### 第四阶段：玩家系统重构
11. ✅ **Player** 重构 (`Scripts/players/player.gd`)
    - 添加 `attribute_manager` 和 `buff_system`
    - 实现 `_on_stats_changed()` 回调
    - 实现 `_on_buff_tick()` 回调
    - `chooseClass()` 使用新系统
    - `player_hurt()` 使用 `DamageCalculator`
    - 保留旧代码降级方案

---

## 待完成的工作 🚧

### 关键任务（影响游戏功能）

#### 1. **ClassManager 简化** ⚠️ 高优先级
- **文件**: `Scripts/players/class_manager.gd`
- **任务**: 移除 `get_passive_effect()` 中的硬编码
- **做法**:
  ```gdscript
  # 技能激活时创建 AttributeModifier
  func _execute_skill_effect(skill_name: String, params: Dictionary):
      var modifier = AttributeModifier.new()
      modifier.modifier_type = AttributeModifier.ModifierType.SKILL
      modifier.duration = params.get("duration", 0.0)
      modifier.stats_delta = CombatStats.new()
      
      match skill_name:
          "狂暴":
              modifier.stats_delta.global_damage_mult = params.get("damage_boost", 1.0)
              modifier.stats_delta.global_attack_speed_add = params.get("attack_speed_boost", 0.0)
          # ... 其他技能
      
      var player = get_parent()
      player.attribute_manager.add_temporary_modifier(modifier)
  ```

#### 2. **BaseWeapon 重构** ⚠️ 高优先级
- **文件**: `Scripts/weapons/base_weapon.gd`
- **任务**: 移除倍数字段，使用 `DamageCalculator`
- **做法**:
  ```gdscript
  # 移除这些字段：
  # var damage_multiplier: float = 1.0
  # var attack_speed_multiplier: float = 1.0
  # var range_multiplier: float = 1.0
  
  # 添加玩家属性引用
  var player_stats: CombatStats = null
  
  # 修改伤害计算
  func get_damage() -> int:
      return DamageCalculator.calculate_weapon_damage(
          weapon_data.damage,
          weapon_level,
          weapon_data.weapon_type,
          player_stats
      )
  
  # 修改攻速计算
  func get_attack_speed() -> float:
      return DamageCalculator.calculate_attack_speed(
          weapon_data.attack_speed,
          weapon_level,
          weapon_data.weapon_type,
          player_stats
      )
  ```

#### 3. **MeleeWeapon / MagicWeapon 更新** ⚠️ 高优先级
- **文件**: `Scripts/weapons/melee_weapon.gd`, `Scripts/weapons/magic_weapon.gd`
- **任务**: 应用特殊效果和新伤害计算
- **做法**:
  ```gdscript
  # 在 melee_weapon.gd 的伤害函数中：
  func _check_and_damage_enemies():
      var damage = get_damage()
      
      # 暴击判定
      if DamageCalculator.roll_critical(player_stats):
          damage = DamageCalculator.apply_critical_multiplier(damage, player_stats)
      
      for enemy in enemies:
          enemy.enemy_hurt(damage)
          
          # 吸血
          SpecialEffects.apply_lifesteal(get_parent().get_parent(), damage, player_stats.lifesteal_percent)
          
          # 燃烧
          SpecialEffects.try_apply_burn(player_stats, enemy)
          
          # 击退
          var final_knockback = DamageCalculator.calculate_knockback(
              weapon_data.knockback_force,
              player_stats
          )
  ```

#### 4. **NowWeapons 简化** 🔵 中优先级
- **文件**: `Scripts/weapons/now_weapons.gd`
- **任务**: 简化武器加成应用
- **做法**:
  ```gdscript
  func add_weapon(weapon_id: String, level: int = 1):
      # ... 创建武器 ...
      
      # 设置属性引用（不再手动计算加成）
      if weapon_instance is BaseWeapon:
          weapon_instance.player_stats = player_ref.attribute_manager.final_stats
  
  # 删除 _apply_class_bonuses() 方法
  # 删除 reapply_all_bonuses() 方法
  ```

#### 5. **UpgradeShop 重构** 🔵 中优先级
- **文件**: `Scripts/UI/upgrade_shop.gd`
- **任务**: 使用新属性系统应用升级
- **做法**:
  ```gdscript
  func _on_upgrade_purchased(upgrade: UpgradeData):
      # ... 扣除钥匙 ...
      
      if upgrade.upgrade_type == UpgradeData.UpgradeType.HEAL_HP:
          _apply_heal_upgrade()
      elif upgrade.upgrade_type == UpgradeData.UpgradeType.NEW_WEAPON:
          await _apply_new_weapon_upgrade(upgrade.weapon_id)
      elif upgrade.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL_UP:
          _apply_weapon_level_upgrade(upgrade.weapon_id)
      else:
          # 属性升级 - 使用新系统
          var player = get_tree().get_first_node_in_group("player")
          var modifier = upgrade.create_modifier()
          player.attribute_manager.add_permanent_modifier(modifier)
          player.attribute_manager.recalculate()
  
  # 删除 _apply_attribute_changes() 方法
  ```

---

### 次要任务（优化和完善）

#### 6. **UpgradeOption 优化** 🟢 低优先级
- **文件**: `Scripts/UI/upgrade_option.gd`
- **任务**: 统一价格获取逻辑
- **做法**: 添加 `get_display_cost()` 方法

#### 7. **UpgradeDatabase 完整迁移** 🟢 低优先级
- **文件**: `Scripts/data/upgrade_database.gd`
- **任务**: 将所有升级从 `attribute_changes` 迁移到 `stats_modifier`
- **示例**:
  ```gdscript
  # 旧方式（保留兼容）:
  hp_upgrade.attribute_changes = {"max_hp": {"op": "add", "value": 50}}
  
  # 新方式（推荐）:
  hp_upgrade.stats_modifier = CombatStats.new()
  hp_upgrade.stats_modifier.max_hp = 50
  ```

#### 8. **WeaponDatabase 扩展** 🟢 低优先级
- **文件**: `Scripts/data/weapon_database.gd`
- **任务**: 为未来特性添加字段
- **新属性**: 穿透、弹药数、燃烧等

#### 9. **测试场景** 🟢 低优先级
- **创建**: `scenes/tests/attribute_system_test.tscn`
- **功能**: 显示实时属性、测试加成叠加

---

## 快速迁移检查清单

当你添加新属性时，请按此顺序操作：

- [ ] 在 `CombatStats` 添加字段（add 和 mult）
- [ ] 更新 `CombatStats.clone()` 方法
- [ ] 在 `AttributeModifier.apply_to()` 中添加应用逻辑
- [ ] 在 `DamageCalculator` 中添加计算方法（如需要）
- [ ] 在 `UpgradeDatabase` 创建相关升级
- [ ] 在 `ClassDatabase` 设置职业初始值（如需要）
- [ ] 测试属性应用和计算

---

## 关键改进总结

1. **统一属性管理** - 所有属性在 `CombatStats` 中定义
2. **分层加成规则** - 同类加成先相加，再与其他层相乘
3. **类型安全** - 使用类型化字段，编译时检查
4. **解耦设计** - `ClassData` 只读，运行时用 `AttributeManager`
5. **统一计算** - `DamageCalculator` 集中处理所有计算
6. **可扩展** - 容易添加新属性和特效
7. **向后兼容** - 新旧系统并存，平滑过渡

---

## 常见问题

**Q: 为什么属性没有生效？**
A: 检查是否调用了 `attribute_manager.recalculate()`

**Q: 如何添加临时加成（如技能效果）？**
A: 使用 `add_temporary_modifier()` 并设置 `duration`

**Q: 如何在武器中使用玩家属性？**
A: 设置 `weapon.player_stats = player.attribute_manager.final_stats`

**Q: 旧的 attribute_changes 还能用吗？**
A: 可以，为了兼容性保留了旧系统，但建议逐步迁移到新系统

---

## 下一步建议

1. **立即完成**: ClassManager、BaseWeapon、武器子类（影响游戏功能）
2. **尽快完成**: NowWeapons、UpgradeShop（核心系统）
3. **逐步迁移**: UpgradeDatabase 中的所有升级选项
4. **性能测试**: 在大规模战斗场景下测试 `recalculate()` 性能
5. **文档完善**: 根据实际使用情况更新这个文档

---

生成时间: 2024-11-18
版本: v1.0 - 核心系统重构完成

