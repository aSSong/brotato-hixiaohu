# 架构导览 - KeyBattle 项目

## 📁 目录结构

```
Scripts/
├── core/                          # 核心系统（自动加载）
│   ├── game_config.gd            # 游戏配置（GameConfig）
│   ├── game_session.gd           # 会话管理（数据）
│   ├── game_state_machine.gd     # 状态机（GameState）
│   ├── initialization_manager.gd # 初始化管理器
│   ├── scene_cleanup_manager.gd  # 场景清理管理器
│   ├── mode_registry.gd          # 模式注册表（ModeRegistry）
│   ├── map_registry.gd           # 地图注册表（MapRegistry）
│   └── localization_manager.gd   # 本地化管理器（LocalizationManager）
│
├── systems/                       # 子系统
│   ├── weapons/
│   │   └── weapon_factory.gd     # 武器工厂
│   ├── ghost/
│   │   └── ghost_factory.gd      # Ghost工厂
│   └── economy/
│       └── economy_controller.gd # 经济控制器
│
├── modes/                         # 游戏模式
│   ├── base_game_mode.gd         # 模式基类
│   └── survival_mode.gd          # 生存模式
│
├── maps/                          # 地图系统
│   ├── map_config.gd             # 地图配置
│   └── base_map_controller.gd    # 地图控制器基类
│
├── GameMain.gd                    # 全局管理器（自动加载）
├── weapons/                       # 武器相关
├── players/                       # 玩家和Ghost
├── UI/                           # 用户界面
└── ...                           # 其他系统

localization/
└── translations.csv              # 翻译文件
```

## 🎯 核心系统说明

### 1. 自动加载顺序

```gdscript
1. GameConfig          # 配置（最先加载）
2. GameState          # 状态机
3. ModeRegistry       # 模式注册表
4. MapRegistry        # 地图注册表
5. LocalizationManager # 本地化
6. GameMain           # 主管理器
7. CameraShake        # 相机抖动
8. BGMManager         # 音乐管理器
```

### 2. 数据流向

```
用户输入
   ↓
UI层 → GameState（状态检查）
   ↓
GameMain（业务逻辑）
   ↓
GameSession（数据存储） → 发送信号
   ↓
UI更新 ← 监听信号
```

### 3. 场景生命周期

```
启动游戏
   ↓
主菜单 (main_title.tscn)
   ↓
角色选择 → GameMain.selected_class_id
   ↓
游戏场景 (bg_map.tscn)
   ↓
GameInitializer._ready()
   ├─ 播放BGM
   ├─ 查找玩家和地图
   ├─ 创建死亡管理器
   └─ 创建ESC菜单
   ↓
游戏运行中
   ├─ 波次管理（WaveManager）
   ├─ 敌人生成（EnemySpawner）
   ├─ 玩家战斗（Player + Weapons）
   ├─ 商店系统（UpgradeShop）
   └─ 状态转换（GameState）
   ↓
游戏结束（胜利/失败）
   ↓
SceneCleanupManager.cleanup_game_scene()
   ├─ 清理所有Ghost
   ├─ 清理所有掉落物
   ├─ 清理所有敌人
   ├─ 清理所有子弹
   └─ 重置GameMain数据
   ↓
场景切换（胜利UI/主菜单）
```

## 🔧 核心类参考

### GameConfig（配置管理）

```gdscript
# 访问配置
var speed = GameConfig.base_speed
var required_keys = GameConfig.keys_required

# 配置分组
- Player: base_speed, base_max_hp, base_max_exp
- Victory: keys_required
- Shop: shop_refresh_base_cost
- Death: death_delay, revive_base_cost
- Ghost: ghost_path_record_distance, ghost_follow_distance, ...
- Wave: total_waves, wave_first_base_count, enemy_ratio_*
- Weapon: max_weapon_count, weapon_radius
```

### GameSession（会话数据）

```gdscript
# 通过GameMain访问（向后兼容）
GameMain.gold = 100
GameMain.master_key = 5
GameMain.score = 1000

# 或直接访问会话
GameMain.current_session.add_gold(10)
if GameMain.current_session.can_afford(50):
    # 购买逻辑

# 监听变化
GameMain.current_session.gold_changed.connect(_on_gold_changed)
```

### GameState（状态机）

```gdscript
# 切换状态
GameState.change_state(GameState.State.WAVE_FIGHTING)
GameState.change_state(GameState.State.SHOPPING)

# 检查状态
if GameState.is_in_state(GameState.State.WAVE_FIGHTING):
    # 战斗逻辑

# 监听状态变化
GameState.state_changed.connect(_on_state_changed)

# 可用状态
- NONE, MAIN_MENU, CHARACTER_SELECT
- GAME_INITIALIZING, WAVE_FIGHTING, WAVE_CLEARING
- SHOPPING, PLAYER_DEAD, GAME_PAUSED
- GAME_VICTORY, GAME_OVER
```

### SceneCleanupManager（场景清理）

```gdscript
# 安全的场景切换
await SceneCleanupManager.change_scene_safely("res://scenes/UI/main_title.tscn")

# 或使用PackedScene
var scene = load("res://scenes/UI/victory_ui.tscn")
await SceneCleanupManager.change_scene_to_packed_safely(scene)

# 手动清理（通常不需要）
SceneCleanupManager.cleanup_game_scene()
```

### WeaponFactory（武器创建）

```gdscript
# 创建武器
var weapon = WeaponFactory.create_weapon("pistol", 3)
if weapon:
    add_child(weapon)
    # 武器已初始化并设置好script

# 内部处理
- 加载weapon.tscn
- 根据WeaponType设置正确的script
- 调用initialize(weapon_data, level)
```

### GhostFactory（Ghost创建）

```gdscript
# 创建新Ghost
var ghost = GhostFactory.create_ghost(follow_target, queue_index, player_speed, null)
add_child(ghost)

# 从数据恢复Ghost（复活）
var ghost = GhostFactory.create_ghost_from_data(follow_target, queue_index, speed, ghost_data)
```

### EconomyController（经济系统）

```gdscript
var economy = EconomyController.new()

# 尝试消费
if economy.try_spend(EconomyController.CurrencyType.GOLD, 50, "购买武器"):
    # 购买成功
    
# 添加货币
economy.add_currency(EconomyController.CurrencyType.GOLD, 10, "击杀敌人")

# 检查支付能力
if economy.can_afford(EconomyController.CurrencyType.GOLD, cost):
    # 能够支付
    
# 获取费用
var revive_cost = economy.get_revive_cost()
var shop_cost = economy.get_shop_refresh_cost(refresh_count)
```

### ModeRegistry & MapRegistry（模式和地图）

```gdscript
# 获取当前模式
var mode = ModeRegistry.current_mode
print(mode.mode_name)  # "生存模式"

# 切换模式
ModeRegistry.set_current_mode("survival")

# 获取所有模式
var all_modes = ModeRegistry.get_all_modes()

# 获取地图
var map = MapRegistry.get_map("default")
print(map.map_name)  # "默认战场"

# 获取支持指定模式的地图
var maps = MapRegistry.get_maps_for_mode("survival")
```

### LocalizationManager（本地化）

```gdscript
# 切换语言
LocalizationManager.change_locale("en")  # 切换到英文
LocalizationManager.change_locale("zh_CN")  # 切换到中文

# 使用翻译（在代码中）
var title = tr("GAME_TITLE")  # 返回 "钥匙之战" 或 "Key Battle"

# 监听语言变化
LocalizationManager.locale_changed.connect(_on_locale_changed)
```

## 💡 最佳实践

### 1. 添加新配置

```gdscript
# 在 GameConfig 中添加
@export var new_setting: int = 100

# 在其他脚本中使用
var value = GameConfig.new_setting
```

### 2. 添加新的游戏模式

```gdscript
# 1. 创建新模式类
extends BaseGameMode
class_name MyNewMode

func _init():
    mode_id = "my_mode"
    mode_name = "我的模式"
    # ... 其他配置

# 2. 在 ModeRegistry 中注册
func _register_builtin_modes():
    register_mode(SurvivalMode.new())
    register_mode(MyNewMode.new())  # 添加这行
```

### 3. 添加新地图

```gdscript
# 在 MapRegistry._register_builtin_maps() 中
var new_map = MapConfig.new("forest", "森林地图", "res://scenes/maps/forest.tscn")
new_map.spawn_position = Vector2(500, 500)
new_map.supported_modes = ["survival", "my_mode"]
register_map(new_map)
```

### 4. 管理游戏状态

```gdscript
# 在适当的时机切换状态
func start_wave():
    GameState.change_state(GameState.State.WAVE_FIGHTING)
    
func open_shop():
    GameState.change_state(GameState.State.SHOPPING)
    
func player_died():
    GameState.change_state(GameState.State.PLAYER_DEAD)
```

### 5. 安全的场景切换

```gdscript
# ❌ 错误方式（会残留对象）
func go_to_victory():
    get_tree().change_scene_to_file("res://scenes/UI/victory_ui.tscn")

# ✅ 正确方式（自动清理）
func go_to_victory():
    await SceneCleanupManager.change_scene_safely("res://scenes/UI/victory_ui.tscn")
```

## 🔍 调试提示

### 查看当前状态

```gdscript
func _process(_delta):
    if Input.is_action_just_pressed("ui_cancel"):
        print("=== 游戏状态 ===")
        print("状态: ", GameState.current_state)
        print("金币: ", GameMain.gold)
        print("波次: ", GameMain.current_session.current_wave)
        print("模式: ", ModeRegistry.current_mode.mode_name if ModeRegistry.current_mode else "无")
```

### 常见问题排查

1. **配置未生效？**
   - 检查 `project.godot` 中 GameConfig 是否已添加到自动加载
   - 确认访问的是 `GameConfig.xxx` 而不是硬编码值

2. **状态混乱？**
   - 检查所有状态切换都使用 `GameState.change_state()`
   - 查看控制台的状态切换日志

3. **场景切换残留？**
   - 确保使用 `SceneCleanupManager.change_scene_safely()`
   - 检查对象是否正确添加到了相应的group

4. **工厂创建失败？**
   - 检查武器/Ghost ID是否正确
   - 查看控制台的错误信息
   - 确认场景文件路径正确

## 📚 扩展阅读

- `REFACTORING_SUMMARY.md` - 重构详细说明和变更记录
- `Scripts/core/` - 核心系统实现
- `Scripts/systems/` - 子系统实现
- `localization/translations.csv` - 翻译文本

---

**提示**：所有新增系统都保持向后兼容，旧代码仍然可以正常工作。建议逐步迁移到新架构，享受更好的可维护性和扩展性。

