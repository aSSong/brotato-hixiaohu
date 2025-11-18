# 波次配置系统重构完成

## 完成的工作

### 1. 创建了JSON配置基础设施

✅ **WaveConfigLoader** (`Scripts/data/wave_config_loader.gd`)
- 从JSON文件加载配置
- 验证配置数据完整性
- 支持配置缓存和热重载

✅ **default.json** (`data/wave_configs/default.json`)
- 包含100波完整配置数据
- 前20波基于提供的难度曲线设计
- 21-100波使用递增公式生成

### 2. 配置格式

每波配置包含：
```json
{
  "wave": 1,
  "spawn_interval": 0.5,        // 刷新间隔（秒）
  "hp_growth": 0.0,             // HP成长率（0-1.0）
  "damage_growth": 0.0,         // 伤害成长率（0-1.0）
  "total_count": 8,             // 本波怪物数量（不含BOSS）
  "enemies": {                  // 怪物配比（总和≈1.0）
    "basic": 0.6,
    "fast": 0.2,
    "tank": 0.1,
    "elite": 0.1
  },
  "boss_config": {              // BOSS配置
    "count": 1,                 // BOSS数量（支持多BOSS）
    "enemy_id": "last_enemy",   // BOSS类型ID
    "spawn_at_end": true        // 是否在最后刷出
  },
  "special_spawns": []          // 特殊刷怪位置（可选）
}
```

### 3. 难度曲线设计

**第1-20波**（基于提供的曲线图）：
- 1-5波：新手期（8-12敌人，0-5%成长）
- 6-10波：稳定期（13-18敌人，5-8%成长，引入技能怪）
- 11-15波：上升期（19-28敌人，8-13%成长）
- 16-20波：陡升期（29-46敌人，15-23%成长）

**第21-100波**：
- 持续递增难度
- 敌人数量：8 → 286
- 成长率上限：40%
- 技能怪占比：逐渐增加至30%
- BOSS数量：1 → 6（每30波增加）
- 第100波有特殊刷怪（中间刷出额外BOSS）

### 4. 怪物种类

**基础怪**：
- `basic` - 基础敌人
- `fast` - 快速敌人
- `tank` - 坦克敌人
- `elite` - 精英敌人

**技能怪**：
- `charging_enemy` - 冲锋敌人
- `shooting_enemy` - 射击敌人
- `exploding_enemy` - 自爆敌人

**BOSS**：
- `last_enemy` - 波次首领（每波最后刷出）

### 5. 修改的核心系统

✅ **BaseGameMode** (`Scripts/modes/base_game_mode.gd`)
- 添加 `wave_config_id` 属性

✅ **WaveSystemV3** (`Scripts/enemies/wave_system_v3.gd`)
- 移除硬编码配置
- 添加 `load_wave_config()` 方法
- 从JSON读取并转换配置
- 支持从模式获取配置ID
- 显示成长率和间隔信息

✅ **EnemySpawnerV3** (`Scripts/enemies/enemy_spawner_v3.gd`)
- 移除硬编码的 `spawn_delay` 和 `enemystrong_per_wave`
- 从波次配置读取刷新间隔
- 应用 HP 和伤害成长率到敌人属性
- 成长公式：`属性 × (1 + 成长率)`

✅ **SurvivalMode** (`Scripts/modes/survival_mode.gd`)
- 设置 `wave_config_id = "default"`

✅ **MultiMode** (`Scripts/modes/multi_mode.gd`)
- 设置 `wave_config_id = "default"`

### 6. 高级特性

**支持多BOSS**：
- `boss_config.count` 可设置为任意数量
- 例如：第30波有2个BOSS，第100波有6个BOSS

**支持中间刷BOSS**：
- 使用 `special_spawns` 数组
- 例如：第100波在第143和215位置刷出额外BOSS

**灵活的配置系统**：
- 可创建多个配置文件（如 `hard.json`, `endless.json`）
- 不同模式可使用不同配置
- 支持配置热重载（开发模式）

## 使用方法

### 创建新配置

1. 在 `data/wave_configs/` 目录创建新JSON文件（如 `hard.json`）
2. 按照配置格式填写波次数据
3. 在模式的 `_init()` 中设置：`wave_config_id = "hard"`

### 测试配置

运行测试脚本验证配置：
```gdscript
# Scripts/test_wave_config.gd
# 在 Godot 编辑器中作为主场景运行
```

### 调整难度

修改JSON文件中的参数：
- `spawn_interval` - 越小越难（怪物刷得越快）
- `hp_growth` - 越高越难（怪物血量越高）
- `damage_growth` - 越高越难（怪物伤害越高）
- `total_count` - 越多越难
- `boss_config.count` - BOSS数量

## 迁移说明

旧系统的硬编码配置已被JSON配置完全替代：
- ❌ `enemy_add_multi` → ✅ JSON中的 `total_count`
- ❌ `enemystrong_per_wave` → ✅ JSON中的 `hp_growth`/`damage_growth`
- ❌ `spawn_delay` → ✅ JSON中的 `spawn_interval`
- ❌ 固定的敌人配比 → ✅ JSON中的 `enemies` 字典

## 文件清单

**新建文件**：
- `Scripts/data/wave_config_loader.gd` - 配置加载器
- `data/wave_configs/default.json` - 默认100波配置
- `Scripts/test_wave_config.gd` - 测试脚本

**修改文件**：
- `Scripts/modes/base_game_mode.gd`
- `Scripts/enemies/wave_system_v3.gd`
- `Scripts/enemies/enemy_spawner_v3.gd`
- `Scripts/modes/survival_mode.gd`
- `Scripts/modes/multi_mode.gd`

## 测试清单

- [ ] 在编辑器中运行 `test_wave_config.gd` 验证配置加载
- [ ] 开始游戏，检查第1波是否正确刷怪
- [ ] 观察波次信息显示（HP成长、伤害成长、刷新间隔）
- [ ] 完成第1-5波，检查难度曲线是否合理
- [ ] 跳到第20波测试（修改代码或作弊）
- [ ] 检查BOSS刷新是否正常
- [ ] 验证敌人HP和伤害是否随波次增长

## 注意事项

1. **JSON格式**：确保JSON文件格式正确，否则会加载失败并使用后备配置
2. **配比总和**：`enemies` 字典中的配比总和应接近1.0
3. **BOSS配置**：`boss_config` 是必需的，至少应有1个BOSS
4. **成长率范围**：建议0.0-0.5（0%-50%），过高会导致难度飙升
5. **特殊刷怪**：`position: -1` 表示最后一个，`position: 0` 表示第一个

## 后续扩展

- 可添加波次事件（如中途刷新道具、特殊效果）
- 可添加波次条件（如时间限制、存活条件）
- 可添加动态难度调整（根据玩家表现）
- 可添加配置编辑器（可视化编辑JSON）

