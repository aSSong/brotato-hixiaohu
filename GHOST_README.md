# Ghost测试功能使用说明

## 功能概述
Ghost测试功能允许在游戏中按下N键创建随机的Ghost角色，跟随玩家并自动攻击敌人。

## 使用方法
1. 启动游戏并进入主游戏场景
2. 按下 **N键** (Add_ghost输入) 创建一个新的Ghost
3. 每次按下N键都会创建一个新的Ghost，跟随在队列末尾

## Ghost特性
- **随机职业外观**: 每个Ghost会随机选择一个玩家外观（player1或player2）
- **随机武器配置**: 
  - 武器数量：1-6把（随机）
  - 武器类型：从所有可用武器中随机选择
  - 武器等级：1-5级（随机）
- **跟随行为**:
  - 第一个Ghost跟随玩家
  - 后续Ghost跟随前一个Ghost，形成队列
  - 跟随距离：150像素
  - 跟随速度：与玩家当前速度同步
- **战斗特性**:
  - Ghost的武器会自动攻击敌人
  - Ghost不会受到敌人攻击
  - Ghost没有HP，不会受伤或死亡
- **视觉效果**:
  - Ghost具有半透明效果（透明度0.7）
  - z_index设置为9（略低于玩家的10）
- **不影响游戏进程**:
  - Ghost不会拾取金币或道具
  - Ghost不影响玩家的商店、成长、升级等系统

## 技术细节

### 文件结构
- `Scripts/players/ghost.gd`: Ghost脚本，处理跟随逻辑和随机数据生成
- `Scripts/players/ghost_manager.gd`: Ghost管理器，管理所有Ghost的队列和速度同步
- `scenes/players/ghost.tscn`: Ghost场景，基于玩家场景结构

### 修改的文件
- `Scripts/players/player.gd`: 添加了Ghost管理器和N键响应
- `project.godot`: 已配置Add_ghost输入映射（N键）

## 调试信息
Ghost创建时会在控制台输出以下信息：
- Ghost的职业ID
- Ghost的武器数量
- Ghost创建成功的确认消息

## 注意事项
- Ghost完全独立于玩家的游戏进度
- Ghost数量没有限制，但创建过多可能影响性能
- Ghost的武器攻击敌人时会正常造成伤害
- 游戏重启后所有Ghost会被清除

