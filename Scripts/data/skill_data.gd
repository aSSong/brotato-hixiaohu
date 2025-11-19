extends Resource
class_name SkillData

## 技能数据资源
## 
## 定义技能的基础信息和属性加成
## 替代原有的硬编码技能逻辑

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## 冷却时间（秒）
@export var cooldown: float = 10.0

## 持续时间（秒）
@export var duration: float = 5.0

## 技能激活时的属性加成
## 建议使用 StatsModifier 资源以确保默认值正确
@export var stats_modifier: CombatStats

