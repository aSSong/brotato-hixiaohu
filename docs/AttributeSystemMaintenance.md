# 📘 属性系统维护与扩展手册

**最后更新**: 2024年11月19日  
**版本**: 2.0 (完全数据驱动版)

---

## 1. 🏗️ 系统架构概览

本属性系统采用了**组合优于继承**的设计模式，核心思想是将属性数据（Data）、修改逻辑（Modifier）和管理逻辑（Manager）分离。

### 核心组件关系图

```mermaid
graph TD
    Player[Player 玩家] --> AM[AttributeManager 属性管理器]
    
    subgraph 数据层 (Resources)
        CS[CombatStats 属性容器]
        UM[AttributeModifier 修改器]
        UD[UpgradeData 升级资源]
        SD[SkillData 技能资源]
        CD[ClassData 职业资源]
    end
    
    AM -->|持有| BaseStats[Base Stats 基础属性]
    AM -->|管理列表| PermMods[Permanent Modifiers 永久加成]
    AM -->|管理列表| TempMods[Temporary Modifiers 临时加成]
    AM -->|计算输出| FinalStats[Final Stats 最终属性]
    
    UD -->|生成| UM
    SD -->|生成| UM
    CD -->|提供| BaseStats
    
    PermMods --> UM
    TempMods --> UM
    
    UM -->|修改| CS
```

### 核心类职责

| 类名 | 职责 | 关键文件 |
| :--- | :--- | :--- |
| **CombatStats** | **数据容器**。定义了所有战斗属性（HP、攻速、伤害倍率等）。提供 `clone()` 方法。 | `Scripts/AttributeSystem/CombatStats.gd` |
| **AttributeModifier** | **修改器**。包含一个 `CombatStats` 增量（`stats_delta`）和持续时间。负责将增量应用到目标属性上。 | `Scripts/AttributeSystem/AttributeModifier.gd` |
| **AttributeManager** | **管理器**。挂载在 Player 下。管理所有 Modifier，负责根据公式 `Base + ΣMods` 计算 `FinalStats`。 | `Scripts/AttributeSystem/AttributeManager.gd` |
| **UpgradeData** | **资源定义**。定义商店升级项。包含价格、图标、品质以及对应的 `stats_modifier`。 | `Scripts/data/upgrade_data.gd` |
| **SkillData** | **资源定义**。定义职业技能。包含冷却、持续时间以及技能激活时的 `stats_modifier`。 | `Scripts/data/skill_data.gd` |

---

## 2. ⚙️ 数据驱动工作流

**原则**：所有属性调整、新升级、新技能都应通过**编辑资源文件（.tres）**完成，尽量不修改代码。

### 2.1 如何添加新的升级项目

1.  **无需写代码**。
2.  在 Godot 编辑器中，右键 `resources/upgrades/` 目录下的对应分类文件夹（如 `luck/`）。
3.  新建资源 -> 选择 `UpgradeData`。
4.  配置资源属性：
    *   `Upgrade Type`: 选择对应类型（如 `LUCK`）。
    *   `Name`: 显示名称（如 "超级幸运"）。
    *   `Cost`: 基础价格。
    *   `Quality`: 品质（决定价格倍率）。
    *   **关键** `Stats Modifier`: 点击新建 `CombatStats`。
        *   **重要**：只设置你想要增加的属性（如 `Luck = 50`）。
        *   **确保**：`Speed` 等加法属性默认为 0（不要误填），`*_mult` 等乘法属性默认为 1.0。
5.  保存文件。商店会自动加载它。

### 2.2 如何调整职业技能

1.  找到职业对应的 `SkillData` 资源（在 `resources/skills/` 下，或者新建一个）。
2.  配置技能属性：
    *   `Duration`: 持续时间。
    *   `Cooldown`: 冷却时间。
    *   `Stats Modifier`: 技能激活时的加成效果。
3.  打开职业资源文件（`resources/classes/xxx.tres`）。
4.  将 `Skill Data` 字段拖入刚刚创建/修改的技能资源。

### 2.3 如何批量修改/重构数据

如果需要批量调整数值（例如所有升级价格翻倍），不要手动改几百个文件。
使用 **编辑器脚本 (`@tool`)**：

*   参考脚本：`Scripts/editor/fix_upgrades_tool.gd`
*   操作：
    1.  修改脚本中的数值逻辑。
    2.  在编辑器中运行脚本（File -> Run）。
    3.  脚本会重新生成所有 `.tres` 文件。

---

## 3. 🧮 属性计算规则

系统采用 **分层计算** 逻辑，确保属性叠加符合直觉。

**公式**：`最终值 = (基础值 + 加法修正总和) × 乘法修正总和`

*   **加法层 (`_add` / `+`)**：
    *   `MaxHP`, `Speed`, `Defense` 等基础属性。
    *   `GlobalDamageAdd` 等显式加法修正。
    *   默认值通常为 0。
*   **乘法层 (`_mult` / `*`)**：
    *   `GlobalDamageMult`, `AttackSpeedMult` 等百分比修正。
    *   默认值通常为 1.0。

**示例：伤害计算**
*   基础伤害: 100
*   升级A: +10% (Mult 1.1)
*   升级B: +20% (Mult 1.2)
*   技能: +50% (Mult 1.5)
*   **错误算法**：`100 * 1.1 * 1.2 * 1.5 = 198`
*   **本系统算法**：
    *   AttributeManager 不直接计算最终伤害值，它计算**最终倍率**。
    *   `FinalMult = 1.0 * 1.1 * 1.2 * 1.5 = 1.98`
    *   如果还有加法修正（如装备增加固定伤害 10）：
    *   `FinalDamage = (100 + 10) * 1.98`

---

## 4. 🐛 常见问题与排错 (Troubleshooting)

### 4.1 属性值异常（如买攻速加了移速）

*   **原因**：资源文件脏数据。
*   **检查**：使用 `Scripts/editor/verify_resources.gd` 验证资源文件内容。
*   **修复**：运行 `fix_upgrades_tool.gd` 重新生成资源。确保 `StatsModifier` 中的无关属性为 0。

### 4.2 技能效果不消失 / 永久残留

*   **原因**：`AttributeModifier` 的 `is_expired()` 逻辑错误。
*   **原理**：`duration` 倒计时结束后会变成负数。如果只判断 `duration < 0`，会被误判为“永久效果”。
*   **正确逻辑**：必须检查 `initial_duration`。如果初始设定了时间（`>0`），那么 `duration <= 0` 即视为过期。
*   **状态**：已在 `AttributeModifier.gd` 中修复。

### 4.3 商店价格与品质不匹配

*   **原因**：`UpgradeData` 中的 `actual_cost` 或 `quality` 字段未导出 (`@export`)。
*   **后果**：保存资源时这些字段丢失，加载时变成默认值（低价格）。
*   **状态**：已在 `UpgradeData.gd` 中添加 `@export` 并修复。

### 4.4 调试技巧

*   **实时日志**：游戏运行时，关注 Output 面板。`AttributeManager` 会打印属性变化的 Diff 日志。
    *   `GlobalAttackSpeed: x1.00 -> x1.50`
*   **UI 面板**：游戏内的属性面板底部集成了日志显示，方便非开发人员测试。
*   **调用栈追踪**：如果在 `AttributeManager` 中发现莫名其妙的属性添加，可以使用 `print_stack()` 打印调用来源。

---

## 5. 🚀 扩展指南 (Future Work)

### 添加新属性（如“闪避率”）

1.  **修改 `CombatStats.gd`**：
    ```gdscript
    @export var dodge_chance: float = 0.0
    ```
2.  **修改 `AttributeModifier.gd`**：
    在 `apply_to()` 方法中添加：
    ```gdscript
    target_stats.dodge_chance += stats_delta.dodge_chance
    ```
3.  **修改 `AttributeManager.gd`**：
    在 `_log_stats_diff()` 中添加日志支持。
4.  **使用属性**：
    在 `Player.gd` 或 `DamageCalculator.gd` 中读取 `attribute_manager.final_stats.dodge_chance` 并实现闪避逻辑。

### 实现复杂的技能效果（非纯属性）

目前的 `StatsModifier` 只能修改数值。如果技能需要特殊逻辑（如“攻击时发射火球”）：
1.  不要通过 `AttributeManager` 实现。
2.  使用 `BuffSystem` 或监听 `ClassManager` 的信号。
3.  在 Player 中编写具体逻辑。

---

## 6. 🤝 交接清单

如果你是接手这个模块的新 AI 或开发者，请先阅读：
1.  `Scripts/AttributeSystem/CombatStats.gd` - 了解所有可用属性。
2.  `Scripts/AttributeSystem/AttributeManager.gd` - 了解属性是如何计算和更新的。
3.  `Scripts/data/upgrade_data.gd` - 了解资源结构。

**关键维护脚本**：
*   `Scripts/editor/fix_upgrades_tool.gd`: **核弹级工具**。用于重置/重新生成所有升级数据。修改配置表后必须运行此脚本。
*   `Scripts/editor/verify_resources.gd`: **体检工具**。用于检查资源文件是否包含异常数据。

---
**祝开发愉快！**

