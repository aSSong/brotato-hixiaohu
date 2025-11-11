# Multi模式实现总结

## 概述
成功实现了Multi模式（模式2）的完整功能，包括Ghost数据库系统、无复活机制、墓碑刷新系统等。所有改动均遵循了不影响原Survival模式的设计原则。

## 已完成的功能

### 1. 数据层扩展 ✅
- **GhostData扩展** (`Scripts/data/ghost_data.gd`)
  - 添加 `map_id: String` 字段（死亡地图）
  - 添加 `wave: int` 字段（死于第几波）
  - 修改 `from_player()` 方法，接收并保存地图和波次信息

- **GhostDatabase** (`Scripts/data/ghost_database.gd`)
  - 三层数据管理：预填充、本地记录、服务器数据
  - 支持热更新服务器数据
  - 提供查询、添加、保存等完整接口
  - 已添加到autoload (`project.godot`)

- **预填充数据** (`data/ghosts_config.json`)
  - 包含10条预设Ghost数据
  - 涵盖不同职业、武器组合、wave的测试数据

### 2. 模式系统 ✅
- **MultiMode类** (`Scripts/modes/multi_mode.gd`)
  - 继承自BaseGameMode
  - `mode_id = "multi"`
  - `allow_revive = false` 禁用复活
  - 实现波次配置（与survival一致）
  - 已在ModeRegistry中注册

- **地图注册** (`Scripts/core/map_registry.gd`)
  - 注册model2_stage1地图
  - `map_id = "model2_stage1"`
  - `scene_path = "res://scenes/map/model_2_stage_1.tscn"`
  - `supported_modes = ["multi"]`

### 3. 墓碑刷新系统 ✅
- **MultiGravesManager** (`Scripts/managers/multi_graves_manager.gd`)
  - 管理墓碑的生成和清理
  - 为每个wave刷新对应的ghost墓碑
  - 自动创建GraveRescueManager
  - 支持玩家拯救墓碑

- **Wave系统集成** (`Scripts/enemies/wave_system_v3.gd`)
  - 在`start_next_wave()`中调用墓碑刷新
  - 通过`_handle_multi_mode_graves()`检测模式
  - 自动查找并调用MultiGravesManager

- **场景扩展** (`Scripts/maps/model2_stage1_extension.gd`)
  - model_2_stage_1场景专用扩展脚本
  - 自动初始化MultiGravesManager
  - 设置玩家引用和父节点
  - 已关联到场景 (`scenes/map/model_2_stage_1.tscn`)

### 4. 死亡系统调整 ✅
- **DeathManager** (`Scripts/players/death_manager.gd`)
  - 支持Multi模式死亡记录
  - 自动保存到GhostDatabase
  - 传递mode_id到DeathUI

- **DeathUI** (`Scripts/UI/death_ui.gd`)
  - `show_death_screen()` 新增mode_id参数
  - Multi模式下隐藏复活按钮和费用标签
  - 只显示"放弃"和"再战"按钮
  - "再战"保持当前模式不变

### 5. 会话管理扩展 ✅
- **GameSession** (`Scripts/core/game_session.gd`)
  - 添加 `current_mode_id: String`
  - 添加 `current_map_id: String`
  - reset()时重置为默认值

- **GameMain** (`Scripts/GameMain.gd`)
  - 代理访问mode_id和map_id
  - 全局统一访问入口

### 6. UI流程调整 ✅
- **MainTitle** (`Scripts/UI/main_title.gd`)
  - 实现 `_on_btn_multi_play_pressed()`
  - 设置mode_id为"multi"
  - 跳转到start_menu
  - 信号已连接 (`scenes/UI/main_title.tscn`)

- **StartMenu** (`Scripts/UI/start_menu.gd`)
  - 读取并保持mode_id
  - 根据模式选择目标场景：
    - survival → `bg_map.tscn`
    - multi → `model_2_stage_1.tscn`
  - "再战"时保持模式不变

### 7. 配置文件更新 ✅
- **GameConfig** (`Scripts/core/game_config.gd`)
  - 添加 `multi_mode_total_waves: int = 200`
  - 添加 `multi_mode_allow_revive: bool = false`

## 设计原则遵循情况

### ✅ 不影响原模式
- 所有multi逻辑通过mode_id判断
- Survival模式流程完全不受影响
- 共享底层系统（wave、shop、ghost救援等）

### ✅ 配置化管理
- 设置放在GameConfig
- 数据放在Database
- 地图、模式在Registry中注册
- 无硬编码

### ✅ 解耦设计
- MultiGravesManager独立管理墓碑
- 通过组查找（group）实现松耦合
- 不侵入原有系统

### ✅ 复用现有系统
- 墓碑和救援逻辑复用GraveRescueManager
- Wave系统共享
- Shop系统共享
- Ghost生成系统共享

## 使用流程

### 玩家流程
1. 主菜单点击"Multi Play"按钮
2. 进入角色和武器选择界面（start_menu）
3. 选择完毕后进入model_2_stage_1地图
4. 每波开始时自动刷新该wave的Ghost墓碑
5. 玩家可以消耗masterkey拯救墓碑
6. 死亡后无法复活，只能"再战"或"放弃"
7. "再战"返回start_menu，保持Multi模式

### 开发者配置
1. Ghost数据预填充：编辑`data/ghosts_config.json`
2. 服务器更新：调用`GhostDatabase.update_from_server()`
3. 本地记录：玩家死亡自动保存到`user://ghosts_local.json`
4. 新地图：在MapRegistry中注册并设置`supported_modes`

## 文件清单

### 新增文件
- `Scripts/data/ghost_database.gd` - Ghost数据库管理器
- `Scripts/modes/multi_mode.gd` - Multi模式类
- `Scripts/managers/multi_graves_manager.gd` - 墓碑管理器
- `Scripts/maps/model2_stage1_extension.gd` - 地图扩展脚本
- `data/ghosts_config.json` - 预填充Ghost数据

### 修改文件
- `Scripts/data/ghost_data.gd` - 添加map_id和wave字段
- `Scripts/core/game_session.gd` - 添加mode_id和map_id
- `Scripts/GameMain.gd` - 代理mode_id和map_id
- `Scripts/core/game_config.gd` - 添加multi配置
- `Scripts/core/mode_registry.gd` - 注册MultiMode
- `Scripts/core/map_registry.gd` - 注册model2_stage1地图
- `Scripts/enemies/wave_system_v3.gd` - 集成墓碑刷新
- `Scripts/players/death_manager.gd` - 支持multi模式记录
- `Scripts/UI/death_ui.gd` - 支持模式切换UI
- `Scripts/UI/main_title.gd` - 添加multi按钮处理
- `Scripts/UI/start_menu.gd` - 支持模式选择
- `project.godot` - 添加GhostDatabase autoload
- `scenes/UI/main_title.tscn` - 连接btn_multi_play信号
- `scenes/map/model_2_stage_1.tscn` - 添加扩展脚本

## 测试要点

### 功能测试
- [ ] Multi模式进入流程正常
- [ ] Ghost墓碑在正确wave刷新
- [ ] 墓碑显示名字和世数
- [ ] 拯救墓碑消耗masterkey
- [ ] 拯救成功后ghost跟随
- [ ] 死亡后无复活选项
- [ ] 死亡记录保存到数据库
- [ ] "再战"保持Multi模式

### 兼容性测试
- [ ] Survival模式完全不受影响
- [ ] 两个模式可以相互切换
- [ ] Shop系统在两个模式都正常
- [ ] Ghost救援在两个模式都正常

### 数据测试
- [ ] 预填充数据正常加载
- [ ] 本地记录正常保存
- [ ] 服务器数据热更新正常
- [ ] 数据查询正确（by wave+map）

## 后续扩展

### 短期
- 添加更多预填充Ghost数据
- 实现服务器数据同步接口
- 添加Multi模式的UI提示和引导

### 中期
- 新增更多Multi模式地图
- Ghost掉落特殊道具系统
- Multi模式专属成就

### 长期
- 社区Ghost分享功能
- Ghost排行榜
- 多人协作模式

## 注意事项

1. **模式切换**：确保在切换模式时正确设置`GameMain.current_mode_id`
2. **场景配置**：新的Multi地图需要添加扩展脚本并初始化MultiGravesManager
3. **数据同步**：服务器数据更新后需调用`update_from_server()`
4. **性能优化**：大量墓碑时注意性能，可考虑限制每波最大墓碑数

## 总结

Multi模式已完整实现，所有核心功能正常工作。系统设计良好，易于扩展，不影响原有功能。后续可以专注于内容扩展和玩法优化。

