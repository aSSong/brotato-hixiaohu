# 武器系统配置指南

## 概述

本武器系统采用**行为-结算分离架构**，将武器的"攻击方式"（行为）与"伤害计算"（结算）解耦，支持灵活组合。

例如：
- **火焰剑**：近战行为（环绕攻击）+ 魔法结算（受魔法属性加成）
- **追踪导弹**：远程行为（发射子弹）+ 魔法结算 + 追踪子弹

---

## 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        WeaponFactory                             │
│                    （武器创建入口）                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        BaseWeapon                                │
│              （武器基类，使用行为组合模式）                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐     │
│  │ weapon_data │  │ player_stats │  │ behavior (行为实例) │     │
│  └─────────────┘  └──────────────┘  └─────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  MeleeBehavior  │  │ RangedBehavior  │  │  MagicBehavior  │
│   （环绕触碰）   │  │  （发射子弹）    │  │  （定点打击）    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │     Bullet      │
                    │ （支持多种移动） │
                    └─────────────────┘
```

### 核心文件说明

| 文件路径 | 职责 |
|---------|------|
| `Scripts/data/weapon_data.gd` | 武器数据类，定义枚举和属性结构 |
| `Scripts/data/weapon_database.gd` | 武器数据库，预定义所有武器配置 |
| `Scripts/weapons/base_weapon.gd` | 武器基类，管理行为实例和属性计算 |
| `Scripts/weapons/behaviors/weapon_behavior.gd` | 行为基类，定义行为接口 |
| `Scripts/weapons/behaviors/melee_behavior.gd` | 近战行为实现 |
| `Scripts/weapons/behaviors/ranged_behavior.gd` | 远程行为实现 |
| `Scripts/weapons/behaviors/magic_behavior.gd` | 魔法行为实现 |
| `Scripts/data/bullet_data.gd` | 子弹数据类 |
| `Scripts/data/bullet_database.gd` | 子弹数据库 |
| `Scripts/bullets/bullet.gd` | 子弹实现，支持多种移动类型 |
| `Scripts/AttributeSystem/DamageCalculator.gd` | 伤害计算器 |
| `Scripts/systems/weapons/weapon_factory.gd` | 武器工厂，统一创建流程 |

---

## 枚举类型

### WeaponData.BehaviorType（行为类型）

决定武器**如何攻击**：

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | MELEE | 近战：环绕玩家，触碰敌人造成伤害 |
| 1 | RANGED | 远程：发射子弹攻击敌人 |
| 2 | MAGIC | 魔法：在敌人位置显示指示器后爆炸 |

### WeaponData.CalculationType（结算类型）

决定武器**使用哪种属性加成**：

| 值 | 名称 | 使用的属性 |
|----|------|-----------|
| 0 | MELEE | `melee_damage_add/mult`, `melee_speed_add/mult`, `melee_range_add/mult` |
| 1 | RANGED | `ranged_damage_add/mult`, `ranged_speed_add/mult`, `ranged_range_add/mult` |
| 2 | MAGIC | `magic_damage_add/mult`, `magic_speed_add/mult`, `magic_range_add/mult` |

### BulletData.MovementType（子弹移动类型）

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | STRAIGHT | 直线飞行 |
| 1 | HOMING | 追踪最近敌人 |
| 2 | BOUNCE | 弹跳（击中敌人后寻找下一个目标） |
| 3 | WAVE | 波浪形移动 |
| 4 | SPIRAL | 螺旋移动 |

---

## 武器配置详解

### 基础结构

```gdscript
var weapon = WeaponData.new(
    "武器名称",                           # weapon_name: String
    WeaponData.BehaviorType.RANGED,       # behavior_type: 行为类型
    WeaponData.CalculationType.RANGED,    # calculation_type: 结算类型
    {                                     # behavior_params: 行为参数字典
        "damage": 5,
        "attack_speed": 0.5,
        "range": 800.0,
        # ... 其他行为特有参数
    },
    "res://assets/weapon/xxx.png",        # texture_path: 贴图路径
    Vector2(0.7, 0.7)                     # scale: 缩放
)
weapon.description = "武器描述"
weapon.special_effects = [...]            # 特殊效果配置
```

---

## 行为参数详解

### 通用参数（所有行为类型都有）

| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `damage` | int | 基础伤害 | 1 |
| `attack_speed` | float | 攻击间隔（秒） | 1.0 |
| `range` | float | 敌人检测范围（像素） | 500.0 |

### MELEE（近战）专用参数

| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `orbit_radius` | float | 环绕半径（武器围绕玩家旋转的距离） | 230.0 |
| `orbit_speed` | float | 环绕速度（度/秒） | 90.0 |
| `hit_range` | float | 攻击判定范围（造成伤害的距离） | 100.0 |
| `knockback_force` | float | 击退力度（0=不击退） | 0.0 |
| `rotation_speed` | float | 武器自转速度（度/秒，攻击时旋转） | 360.0 |

**示例：剑**
```gdscript
{
    "damage": 4,
    "attack_speed": 0.5,
    "range": 240.0,
    "orbit_radius": 300.0,
    "orbit_speed": 180.0,
    "hit_range": 240.0,
    "knockback_force": 560.0,
    "rotation_speed": 360.0
}
```

### RANGED（远程）专用参数

| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `bullet_id` | String | 子弹ID（引用 BulletDatabase） | "normal_bullet" |
| `pierce_count` | int | 穿透数量（0=不穿透） | 0 |
| `projectile_count` | int | 每次发射子弹数量 | 1 |
| `spread_angle` | float | 散射角度（度，多子弹时生效） | 0.0 |

**示例：散弹枪**
```gdscript
{
    "damage": 2,
    "attack_speed": 0.8,
    "range": 600.0,
    "bullet_id": "normal_bullet",
    "pierce_count": 0,
    "projectile_count": 5,
    "spread_angle": 30.0
}
```

### MAGIC（魔法）专用参数

| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| `explosion_radius` | float | 爆炸范围（像素） | 150.0 |
| `explosion_damage_multiplier` | float | 爆炸伤害倍数 | 1.0 |
| `cast_delay` | float | 施法延迟（秒，指示器显示时间） | 0.0 |
| `is_target_locked` | bool | 是否锁定目标（true=跟随，false=固定位置） | true |
| `max_targets` | int | 最大目标数量 | 1 |
| `has_explosion_damage` | bool | 是否有范围爆炸伤害 | true |
| `indicator_color` | Color | 指示器颜色 | Color(1,0.5,0,0.35) |

**示例：火球**
```gdscript
{
    "damage": 5,
    "attack_speed": 0.7,
    "range": 800.0,
    "explosion_radius": 150.0,
    "explosion_damage_multiplier": 1.0,
    "cast_delay": 0.5,
    "is_target_locked": true,
    "max_targets": 1,
    "has_explosion_damage": true,
    "indicator_color": Color(1.0, 0.4, 0.0, 0.4)
}
```

---

## 子弹配置详解

### 子弹数据结构

```gdscript
var bullet = BulletData.new(
    "bullet_id",      # 子弹ID
    2000.0,           # 速度
    3.0,              # 存活时间（秒）
    "res://assets/bullet/xxx.png"  # 贴图路径
)
bullet.bullet_name = "子弹名称"
bullet.scale = Vector2(1.0, 1.0)
bullet.modulate = Color.WHITE  # 颜色调制
bullet.movement_type = BulletData.MovementType.STRAIGHT
bullet.movement_params = {}  # 移动参数
bullet.destroy_on_hit = true  # 命中后是否销毁
```

### 移动参数详解

#### STRAIGHT（直线）
无额外参数。

#### HOMING（追踪）
```gdscript
movement_params = {
    "turn_speed": 5.0,      # 转向速度（弧度/秒）
    "acceleration": 200.0,  # 加速度
    "max_speed": 2500.0     # 最大速度
}
```

#### BOUNCE（弹跳）
```gdscript
movement_params = {
    "bounce_count": 3,      # 最大弹跳次数
    "bounce_loss": 0.9,     # 每次弹跳速度保留比例
    "search_range": 300.0   # 弹跳目标搜索范围
}
```
**注意：** 弹跳子弹需设置 `destroy_on_hit = false`

#### WAVE（波浪）
```gdscript
movement_params = {
    "amplitude": 40.0,  # 波浪振幅
    "frequency": 4.0    # 波浪频率
}
```

#### SPIRAL（螺旋）
```gdscript
movement_params = {
    "spiral_speed": 360.0,  # 螺旋旋转速度（度/秒）
    "spiral_radius": 20.0   # 螺旋半径
}
```

---

## 特殊效果配置

### 格式

```gdscript
weapon.special_effects = [
    {
        "type": "效果类型",
        "params": {
            # 效果参数
        }
    },
    # 可以有多个效果
]
```

### 支持的效果类型

#### lifesteal（吸血）
```gdscript
{
    "type": "lifesteal",
    "params": {
        "chance": 0.1,    # 触发概率（0-1，10%）
        "percent": 0.2    # 吸血比例（0-1，20%）
    }
}
```

#### burn（燃烧）
```gdscript
{
    "type": "burn",
    "params": {
        "chance": 0.2,         # 触发概率
        "tick_interval": 0.5,  # 伤害间隔（秒）
        "damage": 5.0,         # 每次伤害
        "duration": 3.0        # 持续时间（秒）
    }
}
```

#### freeze（冰冻）
```gdscript
{
    "type": "freeze",
    "params": {
        "chance": 0.1,     # 触发概率
        "duration": 2.0    # 冰冻时间（秒）
    }
}
```

#### bleed（流血）
```gdscript
{
    "type": "bleed",
    "params": {
        "chance": 0.2,
        "tick_interval": 0.5,
        "damage": 3.0,
        "duration": 3.0
    }
}
```

#### poison（中毒）
```gdscript
{
    "type": "poison",
    "params": {
        "chance": 0.15,
        "tick_interval": 1.0,
        "damage": 5.0,
        "duration": 5.0
    }
}
```

---

## 完整武器配置示例

### 示例1：火焰剑（近战行为 + 魔法结算）

```gdscript
var flame_sword = WeaponData.new(
    "火焰剑",
    WeaponData.BehaviorType.MELEE,      # 近战行为
    WeaponData.CalculationType.MAGIC,    # 魔法结算！
    {
        "damage": 5,
        "attack_speed": 0.6,
        "range": 250.0,
        "orbit_radius": 320.0,
        "orbit_speed": 160.0,
        "hit_range": 250.0,
        "knockback_force": 400.0,
        "rotation_speed": 300.0
    },
    "res://assets/weapon/Weapon_lasersword.png",
    Vector2(0.75, 0.75)
)
flame_sword.description = "附魔火焰的剑，近战行为但使用魔法伤害加成"
flame_sword.special_effects = [
    {
        "type": "burn",
        "params": {
            "chance": 0.4,
            "tick_interval": 0.5,
            "damage": 5.0,
            "duration": 3.0
        }
    }
]
weapons["flame_sword"] = flame_sword
```

### 示例2：追踪导弹（远程行为 + 追踪子弹）

```gdscript
# 1. 先在 BulletDatabase 添加追踪子弹
var homing_bullet = BulletData.new("homing_bullet", 1800.0, 5.0, "res://assets/bullet/bullet_blue.png")
homing_bullet.bullet_name = "追踪子弹"
homing_bullet.modulate = Color(0.5, 0.8, 1.0)
homing_bullet.movement_type = BulletData.MovementType.HOMING
homing_bullet.movement_params = {
    "turn_speed": 5.0,
    "acceleration": 200.0,
    "max_speed": 2500.0
}
bullets["homing_bullet"] = homing_bullet

# 2. 在 WeaponDatabase 添加武器
var homing_missile = WeaponData.new(
    "追踪导弹",
    WeaponData.BehaviorType.RANGED,
    WeaponData.CalculationType.MAGIC,
    {
        "damage": 8,
        "attack_speed": 1.2,
        "range": 1000.0,
        "bullet_id": "homing_bullet",  # 引用上面定义的子弹
        "pierce_count": 0,
        "projectile_count": 1,
        "spread_angle": 0.0
    },
    "res://assets/weapon/Weapon_fire.png",
    Vector2(0.7, 0.7)
)
homing_missile.description = "发射追踪导弹，使用魔法伤害"
homing_missile.special_effects = [
    {"type": "burn", "params": {"chance": 0.3, "tick_interval": 0.5, "damage": 3.0, "duration": 2.0}}
]
weapons["homing_missile"] = homing_missile
```

### 示例3：闪电法杖（魔法多目标）

```gdscript
var lightning = WeaponData.new(
    "闪电",
    WeaponData.BehaviorType.MAGIC,
    WeaponData.CalculationType.MAGIC,
    {
        "damage": 3,
        "attack_speed": 0.5,
        "range": 850.0,
        "explosion_radius": 80.0,
        "explosion_damage_multiplier": 0.6,
        "cast_delay": 0.2,
        "is_target_locked": true,
        "max_targets": 3,  # 同时攻击3个目标
        "has_explosion_damage": true,
        "indicator_color": Color(0.8, 0.8, 1.0, 0.3)
    },
    "res://assets/weapon/Weapon_ice.png",
    Vector2(0.6, 0.6)
)
lightning.description = "快速魔法武器，可同时攻击多个目标"
weapons["lightning"] = lightning
```

---

## 伤害计算公式

### 武器伤害
```
最终伤害 = 基础伤害 × 等级倍数 × (1 + 全局加法) × 全局乘法 × (1 + 类型加法) × 类型乘法
```

其中：
- **等级倍数**：1级=1.0, 2级=1.3, 3级=1.6, 4级=2.0, 5级=2.5
- **全局加法/乘法**：`global_damage_add`, `global_damage_mult`
- **类型加法/乘法**：根据 `calculation_type` 选择对应属性

### 攻击速度
```
最终间隔 = 基础间隔 / 等级倍数 / 全局倍数 / 类型倍数
```

### 特殊效果伤害
特殊效果造成的伤害受 `status_effect_mult` 加成。

---

## 注意事项

### 1. 枚举类型使用
- 行为类型和结算类型统一使用 `WeaponData` 中定义的枚举
- 在代码中引用时使用 `WeaponData.BehaviorType.XXX` 和 `WeaponData.CalculationType.XXX`

### 2. 子弹ID必须存在
- `behavior_params["bullet_id"]` 必须在 `BulletDatabase` 中存在
- 如果不存在，会使用默认的 `"normal_bullet"`

### 3. 特殊效果格式
```gdscript
# 正确格式（Array of Dictionary）
special_effects = [{"type": "burn", "params": {...}}]

# 错误格式（不要使用嵌套的 effects 键）
special_effects = {"effects": [...]}  # ❌ 已废弃
```

### 4. 弹跳子弹设置
```gdscript
bullet.movement_type = BulletData.MovementType.BOUNCE
bullet.destroy_on_hit = false  # 必须设置为 false，否则无法弹跳
```

### 5. 魔法武器指示器
- `is_target_locked = true`：指示器跟随目标移动
- `is_target_locked = false`：指示器固定在初始位置
- `cast_delay = 0`：无指示器，立即爆炸

### 6. 行为-结算组合规则
任意行为类型可以与任意结算类型组合：

| 组合 | 说明 | 应用场景 |
|------|------|---------|
| MELEE + MELEE | 标准近战武器 | 剑、斧头 |
| MELEE + MAGIC | 魔法近战武器 | 火焰剑、冰霜锤 |
| RANGED + RANGED | 标准远程武器 | 手枪、步枪 |
| RANGED + MAGIC | 魔法远程武器 | 追踪导弹、魔法箭 |
| MAGIC + MAGIC | 标准魔法武器 | 火球、冰刺 |
| MAGIC + MELEE | 近战型魔法武器 | 地刺（近战加成的范围攻击） |

---

## 扩展指南

### 添加新武器

1. 在 `WeaponDatabase.initialize_weapons()` 中添加配置
2. 如果需要新的子弹类型，先在 `BulletDatabase` 中添加

### 添加新行为类型

1. 在 `WeaponData.BehaviorType` 枚举中添加新值
2. 创建新的行为类 `Scripts/weapons/behaviors/xxx_behavior.gd`
3. 继承 `WeaponBehavior`，实现 `perform_attack()` 方法
4. 在 `BaseWeapon._create_behavior()` 中添加创建逻辑

### 添加新子弹移动类型

1. 在 `BulletData.MovementType` 枚举中添加新值
2. 在 `Bullet._physics_process()` 中添加对应的移动逻辑
3. 在 `Bullet._init_movement()` 中添加初始化逻辑

### 添加新特殊效果

1. 在 `SpecialEffects` 类中实现效果逻辑
2. 配置时使用新的效果类型名称

---

## 调试方法

### 查看伤害计算详情
```gdscript
DamageCalculator.debug_print_damage_calculation(
    base_damage,
    weapon_level,
    calculation_type,
    player_stats
)
```

### 打印武器配置
```gdscript
var weapon_data = WeaponDatabase.get_weapon("flame_sword")
print("武器: ", weapon_data.weapon_name)
print("行为类型: ", weapon_data.behavior_type)
print("结算类型: ", weapon_data.calculation_type)
print("行为参数: ", weapon_data.get_behavior_params())
print("特殊效果: ", weapon_data.special_effects)
```

---

## 版本历史

- **v2.0** (当前版本)
  - 行为-结算分离架构
  - 子弹系统支持多种移动类型
  - 统一使用 WeaponData 中的枚举定义
  - special_effects 改为直接 Array 格式

- **v1.0** (旧版)
  - 武器类型与脚本绑定（MeleeWeapon, RangedWeapon, MagicWeapon）
  - special_effects 使用 `{"effects": [...]}` 嵌套格式

