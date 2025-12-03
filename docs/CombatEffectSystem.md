# 战斗特效系统文档

## 目录
- [系统概述](#系统概述)
- [架构设计](#架构设计)
- [配置指南](#配置指南)
- [使用示例](#使用示例)
- [维护和扩展](#维护和扩展)
- [常见问题](#常见问题)

---

## 系统概述

战斗特效系统（CombatEffectManager）是一个统一的视觉特效管理系统，用于管理游戏中所有战斗相关的视觉特效，包括：

- **粒子特效**：爆炸、烟雾、火花等粒子效果
- **序列帧动画**：爆炸动画、击中动画、死亡动画等
- **组合特效**：同时播放多个特效（粒子 + 序列帧）

### 核心特性

- ✅ **预加载机制**：所有特效在游戏初始化时预加载，避免运行时卡顿
- ✅ **统一管理**：所有特效通过 `CombatEffectManager` 统一调用
- ✅ **灵活配置**：支持自定义场景、独立 scale、组合特效
- ✅ **自动清理**：特效播放完成后自动清理，无需手动管理
- ✅ **向后兼容**：支持简单格式（使用默认场景）和完整格式（自定义场景）

---

## 架构设计

### 文件结构

```
Scripts/
├── systems/
│   └── CombatEffectManager.gd      # 特效管理器（核心）
└── animations/
	└── animations.gd                # 动画播放器（底层实现）

scenes/
├── effects/                         # 粒子特效场景
│   ├── meteor_explosion.tscn
│   ├── fireball_explosion.tscn
│   └── ice_explosion.tscn
└── animations/                      # 序列帧动画场景
	├── animations.tscn              # 默认场景（敌人死亡/受伤）
	└── explosion_sprites.tscn      # 自定义场景（爆炸动画）
```

### 核心类

#### CombatEffectManager
- **类型**：静态类（无需实例化）
- **职责**：统一管理所有特效配置和播放
- **主要方法**：
  - `initialize()` - 初始化并预加载所有特效
  - `play_explosion(weapon_name, position, scale)` - 播放武器爆炸特效
  - `play_enemy_death(position, scale)` - 播放敌人死亡特效
  - `play_enemy_hurt(position, scale)` - 播放敌人受伤特效
  - `play_effect_group(effects, position, scale)` - 播放组合特效

#### animations.gd
- **类型**：Node2D（场景脚本）
- **职责**：底层特效播放实现
- **主要方法**：
  - `run_animation(options)` - 播放序列帧动画（默认场景）
  - `run_animation_from_scene(options)` - 播放序列帧动画（自定义场景）
  - `run_particle_effect(options)` - 播放粒子特效
  - `run_effect_group(options)` - 播放组合特效

---

## 配置指南

### 1. 特效配置位置

所有特效配置在 `Scripts/systems/CombatEffectManager.gd` 的 `_setup_effect_configs()` 方法中：

```gdscript
static func _setup_effect_configs() -> void:
	effect_configs["武器名_类型"] = {
		"particles": [...],      # 粒子特效路径数组
		"animations": [...]      # 序列帧动画配置数组
	}
```

### 2. 配置格式

#### 2.1 粒子特效配置

```gdscript
"particles": [
	"res://scenes/effects/meteor_explosion.tscn",  # 粒子场景路径
	"res://scenes/effects/smoke.tscn"               # 可以多个粒子
]
```

#### 2.2 序列帧动画配置（简单格式）

使用默认场景 `animations.tscn`，只需要动画名称：

```gdscript
"animations": [
	"enemies_dead",    # 动画名称（在 animations.tscn 中定义）
	"enemies_hurt"     # 可以多个动画
]
```

#### 2.3 序列帧动画配置（完整格式）

使用自定义场景，可以设置独立的 scale：

```gdscript
"animations": [{
	"scene_path": "res://scenes/effects/explosion_sprites.tscn",  # 场景路径
	"ani_name": "Meteor_explode",                                  # 动画名称
	"scale": 1.5                                                   # 自定义scale（可选）
}]
```

### 3. 配置示例

#### 示例1：只有粒子特效

```gdscript
effect_configs["火球_爆炸"] = {
	"particles": ["res://scenes/effects/fireball_explosion.tscn"],
	"animations": []
}
```

#### 示例2：只有序列帧动画（默认场景）

```gdscript
effect_configs["敌人_死亡"] = {
	"particles": [],
	"animations": ["enemies_dead"]
}
```

#### 示例3：组合特效（粒子 + 序列帧）

```gdscript
effect_configs["陨石_爆炸"] = {
	"particles": ["res://scenes/effects/meteor_explosion.tscn"],
	"animations": [{
		"scene_path": "res://scenes/effects/explosion_sprites.tscn",
		"ani_name": "Meteor_explode",
		"scale": 1.5  # 序列帧使用1.5倍大小
	}]
}
```

#### 示例4：多个特效组合

```gdscript
effect_configs["超级爆炸"] = {
	"particles": [
		"res://scenes/effects/explosion.tscn",
		"res://scenes/effects/smoke.tscn",
        "res://scenes/effects/sparks.tscn"
	],
	"animations": [
		"enemies_dead",  # 使用默认场景
		{                # 使用自定义场景
			"scene_path": "res://scenes/effects/explosion_sprites.tscn",
			"ani_name": "big_explode",
			"scale": 2.0
		}
	]
}
```

---

## 使用示例

### 1. 播放武器爆炸特效

```gdscript
# 在武器代码中
CombatEffectManager.play_explosion("陨石", explosion_position)

# 带自定义scale
CombatEffectManager.play_explosion("火球", explosion_position, 1.5)
```

### 2. 播放敌人死亡特效

```gdscript
# 在敌人代码中
CombatEffectManager.play_enemy_death(enemy.global_position)

# 带自定义scale
CombatEffectManager.play_enemy_death(enemy.global_position, 1.2)
```

### 3. 播放敌人受伤特效

```gdscript
CombatEffectManager.play_enemy_hurt(enemy.global_position)
```

### 4. 播放组合特效（高级用法）

```gdscript
var effects = [
	{
		"particles": ["res://scenes/effects/hit_particle.tscn"]
	},
	{
		"scene_path": "res://scenes/effects/hit_animation.tscn",
		"ani_name": "hit",
		"scale": 1.3
	}
]

CombatEffectManager.play_effect_group(effects, hit_position)
```

---

## 维护和扩展

### 添加新武器特效

1. **创建粒子特效场景**（如果需要）
   - 在 `scenes/effects/` 目录创建新的粒子场景
   - 配置粒子参数

2. **创建序列帧动画场景**（如果需要）
   - 在 `scenes/effects/` 或 `scenes/animations/` 目录创建新场景
   - 场景结构：
	 ```
	 Node2D (根节点)
	 └── AnimatedSprite2D (任意名称)
		 └── sprite_frames (SpriteFrames资源)
			 └── 动画名称 (如 "explode")
	 ```
   - 注意：节点名称可以是任意名称，系统会自动查找 `AnimatedSprite2D` 节点

3. **在 CombatEffectManager 中添加配置**

```gdscript
effect_configs["新武器_爆炸"] = {
	"particles": ["res://scenes/effects/new_weapon_explosion.tscn"],
	"animations": [{
		"scene_path": "res://scenes/effects/new_weapon_animation.tscn",
		"ani_name": "explode",
		"scale": 1.0
	}]
}
```

4. **在代码中调用**

```gdscript
CombatEffectManager.play_explosion("新武器", position)
```

### 添加新的特效类型

1. **在 CombatEffectManager 中添加新方法**

```gdscript
## 播放击中特效
static func play_hit_effect(weapon_name: String, position: Vector2, scale: float = 1.0) -> void:
	var config_key = weapon_name + "_击中"
	if not effect_configs.has(config_key):
		push_warning("[CombatEffectManager] 未找到击中特效: %s" % weapon_name)
		return
	
	var config = effect_configs[config_key]
	_play_effect_config(config, position, scale)
```

2. **添加配置**

```gdscript
effect_configs["陨石_击中"] = {
	"particles": ["res://scenes/effects/meteor_hit_particle.tscn"],
	"animations": [{
		"scene_path": "res://scenes/effects/hit_animation.tscn",
		"ani_name": "meteor_hit",
		"scale": 1.2
	}]
}
```

3. **使用**

```gdscript
CombatEffectManager.play_hit_effect("陨石", hit_position)
```

### 修改现有特效

1. **修改粒子特效**：直接编辑 `scenes/effects/` 中的场景文件
2. **修改序列帧动画**：直接编辑对应的场景文件
3. **修改配置**：编辑 `CombatEffectManager._setup_effect_configs()` 中的配置

### 预加载机制

系统会在 `GameMain._ready()` 中自动调用 `CombatEffectManager.initialize()` 预加载所有特效。

**预加载的时机**：
- 游戏启动时
- 只加载一次（如果已加载则跳过）

**预加载的内容**：
- 所有粒子特效场景
- 所有自定义序列帧场景（不包括默认的 `animations.tscn`）

---

## 常见问题

### Q1: 序列帧动画不播放？

**检查清单**：
1. ✅ 场景文件路径是否正确
2. ✅ 场景中是否有 `AnimatedSprite2D` 节点
3. ✅ 动画名称是否与配置中的 `ani_name` 一致
4. ✅ `SpriteFrames` 资源中是否定义了该动画
5. ✅ 查看控制台日志，是否有错误信息

**调试方法**：
- 查看控制台输出：`[CombatEffectManager] 播放序列帧动画: ...`
- 查看控制台输出：`[Animations] 找到 AnimatedSprite2D 节点，播放动画: ...`

### Q2: 动画节点名称必须是什么？

**答案**：可以是任意名称！系统会自动递归查找 `AnimatedSprite2D` 节点。

例如：
- `all_animation` ✅
- `explosion_animation` ✅
- `sprite` ✅
- 任意名称 ✅

### Q3: 如何设置动画的 scale？

在配置中使用完整格式：

```gdscript
"animations": [{
	"scene_path": "res://scenes/effects/explosion_sprites.tscn",
	"ani_name": "explode",
	"scale": 1.5  # 设置scale为1.5倍
}]
```

### Q4: 循环动画如何清理？

系统会自动检测循环动画（`loop: true`），并根据动画时长自动清理：
- 时长 = 帧数 / 速度
- 例如：19帧，速度20.0 → 时长 = 19/20 = 0.95秒

### Q5: 如何同时播放多个特效？

使用组合特效配置：

```gdscript
effect_configs["组合特效"] = {
	"particles": [
		"res://scenes/effects/particle1.tscn",
        "res://scenes/effects/particle2.tscn"
	],
	"animations": [
		"enemies_dead",
		{
			"scene_path": "res://scenes/effects/custom.tscn",
			"ani_name": "custom_anim",
			"scale": 1.5
		}
	]
}
```

### Q6: 特效没有预加载？

**检查**：
1. 配置是否正确添加到 `_setup_effect_configs()`
2. 场景文件路径是否存在
3. 查看控制台输出：`[CombatEffectManager] ✓ 预加载...`

### Q7: 如何为不同武器设置不同的特效？

在配置中使用武器名称作为 key：

```gdscript
effect_configs["陨石_爆炸"] = {...}  # 陨石武器
effect_configs["火球_爆炸"] = {...}  # 火球武器
effect_configs["冰刺_爆炸"] = {...}  # 冰刺武器
```

调用时使用武器名称：

```gdscript
CombatEffectManager.play_explosion(weapon_data.weapon_name, position)
```

### Q8: 粒子特效和序列帧动画的 scale 是独立的吗？

**答案**：是的！

- 粒子特效使用全局 scale（调用时传入的 scale）
- 序列帧动画可以使用独立的 scale（在配置中设置）

例如：

```gdscript
# 调用时
CombatEffectManager.play_explosion("陨石", position, 1.0)  # 全局scale = 1.0

# 配置中
"animations": [{
	"scene_path": "...",
	"ani_name": "...",
	"scale": 1.5  # 序列帧使用1.5倍，粒子使用1.0倍
}]
```

---

## 配置参考

### 当前已配置的特效

#### 武器爆炸特效

| 武器名称 | 粒子特效 | 序列帧动画 | Scale |
|---------|---------|-----------|-------|
| 陨石 | meteor_explosion.tscn | Meteor_explode | 1.5 |
| 火球 | fireball_explosion.tscn | fire_explode | 1.3 |
| 冰刺 | - | ice_explode | 1.0 |

#### 敌人特效

| 特效类型 | 序列帧动画 | 场景 |
|---------|-----------|------|
| 死亡 | enemies_dead | animations.tscn（默认） |
| 受伤 | enemies_hurt | animations.tscn（默认） |

### 特效场景结构要求

#### 粒子特效场景
```
Node2D (根节点)
├── CPUParticles2D (或多个)
└── GPUParticles2D (可选)
```

#### 序列帧动画场景
```
Node2D (根节点)
└── AnimatedSprite2D (任意名称)
	└── sprite_frames (SpriteFrames资源)
		└── 动画名称 (如 "explode", "Meteor_explode")
```

---

## 技术细节

### 预加载流程

1. `GameMain._ready()` 调用 `CombatEffectManager.initialize()`
2. `initialize()` 调用 `_setup_effect_configs()` 设置配置
3. 遍历所有配置，预加载粒子场景和自定义序列帧场景
4. 存储到 `effect_scenes` 字典中

### 播放流程

1. 调用 `CombatEffectManager.play_xxx()` 方法
2. 根据配置 key 查找特效配置
3. 调用 `_play_effect_config()` 播放
4. 分别处理粒子和序列帧：
   - 粒子：从预加载字典获取场景，调用 `run_particle_effect()`
   - 序列帧：判断是默认场景还是自定义场景，调用相应方法
5. 自动清理（根据动画类型）

### 自动清理机制

- **非循环动画**：监听 `animation_finished` 信号
- **循环动画**：根据动画时长延迟清理
- **粒子特效**：根据粒子生命周期延迟清理

---

## 更新日志

### v1.0 (当前版本)
- ✅ 支持粒子特效和序列帧动画
- ✅ 支持自定义场景和独立 scale
- ✅ 支持组合特效
- ✅ 自动预加载和清理机制
- ✅ 向后兼容简单格式

---

## 联系和支持

如有问题或建议，请查看：
- 控制台日志输出
- 代码注释
- 本文档的常见问题部分
