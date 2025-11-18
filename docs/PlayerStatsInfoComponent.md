# 玩家属性显示组件使用说明

## 📋 组件介绍

`PlayerStatsInfo` 是一个实时显示玩家所有属性数值的UI组件，方便观察和调试。

**文件位置**：
- 场景：`res://scenes/UI/components/player_stats_info.tscn`
- 脚本：`res://Scripts/UI/components/player_stats_info.gd`

---

## 🎨 功能特性

### 1. 实时属性显示

显示所有关键属性：

#### 基础属性
- 最大HP
- 当前HP（带HP百分比颜色提示）
- 移动速度
- 防御
- 幸运

#### 战斗属性
- 暴击率
- 暴击伤害
- 减伤

#### 全局武器属性
- 全局伤害倍数
- 全局攻速倍数

#### 近战武器属性
- 近战伤害倍数
- 近战攻速倍数
- 近战范围倍数
- 近战击退倍数

#### 远程武器属性
- 远程伤害倍数
- 远程攻速倍数
- 远程范围倍数

#### 魔法武器属性
- 魔法伤害倍数
- 魔法攻速倍数
- 魔法范围倍数
- 爆炸范围倍数

#### 加成统计
- 永久加成数量
- 临时加成数量

### 2. 智能高亮

- **修改过的属性会高亮显示**（不是默认值1.0的属性）
- **HP低于50%时显示红色**
- **HP在50%-80%时显示黄色**
- 不同类型的属性用不同颜色区分

### 3. 自动更新

- 监听 `AttributeManager.stats_changed` 信号
- 每0.5秒更新当前HP等动态数据
- 购买升级、使用技能时自动刷新

---

## 📦 如何使用

### 方法1：添加到游戏主UI

在 `game_ui.tscn` 中添加：

```gdscript
1. 打开 game_ui.tscn
2. 添加节点 → 选择"实例化子场景"
3. 选择 res://scenes/UI/components/player_stats_info.tscn
4. 设置位置（建议放在右上角或右侧）
5. 调整大小（默认300x400，可自定义）
```

**推荐位置**：
- 右上角：`anchors_preset = 1` (Top Right)
- 右侧居中：`anchors_preset = 6` (Center Right)

### 方法2：通过快捷键切换显示

在游戏脚本中添加：

```gdscript
var stats_panel: PlayerStatsInfo

func _ready():
    stats_panel = $PlayerStatsInfo
    stats_panel.visible = false  # 默认隐藏

func _input(event):
    if event.is_action_pressed("toggle_stats"):  # 需要定义按键
        stats_panel.toggle_visibility()
```

### 方法3：仅调试时显示

```gdscript
func _ready():
    if OS.is_debug_build():
        $PlayerStatsInfo.visible = true
    else:
        $PlayerStatsInfo.visible = false
```

---

## 🎮 推荐的快捷键设置

在 `项目设置 → 输入映射` 中添加：

```
toggle_stats: F1 或 Tab
```

---

## 🎨 自定义样式

### 修改背景颜色

在 `player_stats_info.tscn` 中，修改 `StyleBoxFlat_bg`：

```gdscript
bg_color = Color(0.1, 0.1, 0.1, 0.85)  # 半透明黑色
border_color = Color(0.4, 0.6, 1, 0.8)  # 蓝色边框
```

### 修改大小

选中根节点 `PlayerStatsInfo`，修改：

```gdscript
custom_minimum_size = Vector2(300, 400)  # 宽度x高度
```

### 修改字体大小

在脚本中修改：

```gdscript
theme_override_font_sizes/font_size = 20  # 标题
theme_override_font_sizes/font_size = 16  # 分类标签
theme_override_font_sizes/font_size = 14  # 数值
```

---

## 📊 高亮颜色说明

| 颜色 | 含义 | 示例 |
|-----|------|-----|
| 黄色 | 全局属性已修改 | 全局伤害: ×1.15 |
| 橙色 | 近战属性已修改 | 近战攻速: ×1.30 |
| 绿色 | 远程属性已修改 | 远程伤害: ×1.25 |
| 蓝色 | 魔法属性已修改 | 魔法范围: ×1.40 |
| 红色 | HP低于50% | 当前HP: 25/60 |
| 黄色 | HP在50%-80% | 当前HP: 40/60 |

---

## 🔧 常见问题

### Q: 组件不显示数据？

**A**: 检查以下几点：
1. 确保玩家节点在 `player` 组中
2. 确保玩家有 `AttributeManager` 子节点
3. 检查控制台是否有错误

### Q: 如何隐藏某些不需要的属性？

**A**: 在场景中删除对应的Label节点，或在脚本中添加：

```gdscript
func _ready():
    # 隐藏不需要的属性
    magic_explosion_radius_mult_label.visible = false
```

### Q: 数值更新不及时？

**A**: 修改更新频率：

```gdscript
update_timer.wait_time = 0.1  # 改为0.1秒更新一次（更频繁）
```

---

## 📝 示例：集成到游戏UI

```gdscript
# 在 game_ui.gd 中
extends CanvasLayer

@onready var stats_panel: PlayerStatsInfo = $PlayerStatsInfo

func _ready():
    # 默认隐藏，按F1显示
    stats_panel.visible = false

func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F1:
            stats_panel.toggle_visibility()
```

---

## 🎯 开发建议

### 调试时显示

在开发和测试时，建议始终显示此面板：
- 可以实时观察属性变化
- 验证升级是否正确应用
- 检查技能效果是否生效
- 观察加成数量

### 发布时隐藏

在正式发布版本中，可以：
- 完全移除此组件
- 或通过快捷键（如F1）切换显示
- 或仅在Debug模式下显示

---

## 🚀 未来扩展

可以添加的功能：
- [ ] 折叠/展开各个分类
- [ ] 搜索/过滤特定属性
- [ ] 显示属性来源（哪个升级提供）
- [ ] 显示技能剩余时间
- [ ] 导出属性快照（截图/文本）

---

*创建日期：2024年11月18日*
*组件版本：1.0*
*状态：可用*

