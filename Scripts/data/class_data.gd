extends Resource
class_name ClassData

## 职业数据 Resource 类（重构版）
## 
## 职责：作为只读的职业模板，定义职业的基础属性和技能信息
## 
## 重要说明：
##   - 这是只读模板，不应在运行时修改
##   - 使用新的CombatStats系统存储所有战斗属性
##   - 保留旧属性字段以兼容现有代码，但优先使用base_stats
## 
## 使用方法：
##   var class_data = ClassDatabase.get_class_data("warrior")
##   var runtime_stats = class_data.base_stats.clone()  # 克隆用于运行时修改

@export var name: String = "默认职业"
@export var description: String = ""

## ===== 进阶外观配置 =====
## 直接引用编辑器中制作好的 SpriteFrames 资源 (.tres)
## 优点：支持多动画(idle, run, hurt)，支持编辑器预览，无需代码切图
@export var skin_frames: SpriteFrames 
@export var scale: Vector2 = Vector2(1.0, 1.0)

## ===== UI 资源配置 =====
## 职业选择界面使用的图片资源
@export var portrait: Texture2D  # 头像资源
@export var poster: Texture2D  # 海报资源
@export var name_image: Texture2D  # 名字资源

## 技能数据（新系统）
@export var skill_data: SkillData

## 新属性系统：使用CombatStats统一管理所有战斗属性
@export var base_stats: CombatStats = null

## ===== 以下为旧属性（保留以兼容现有代码） =====
## 注意：这些属性将在未来版本中被移除
## 新代码应优先使用 base_stats

## 基础属性（已废弃，请使用base_stats）
@export var max_hp: int = 100
@export var speed: float = 400.0
@export var attack_multiplier: float = 1.0
@export var defense: int = 0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 1.5

## 战斗属性系数（已废弃，请使用base_stats）
@export var damage_reduction_multiplier: float = 1.0
@export var luck: float = 0.0

## 武器通用系数（已废弃，请使用base_stats）
@export var attack_speed_multiplier: float = 1.0

## 近战武器系数（已废弃，请使用base_stats）
@export var melee_damage_multiplier: float = 1.0
@export var melee_range_multiplier: float = 1.0
@export var melee_speed_multiplier: float = 1.0
@export var melee_knockback_multiplier: float = 1.0

## 远程武器系数（已废弃，请使用base_stats）
@export var ranged_damage_multiplier: float = 1.0
@export var ranged_range_multiplier: float = 1.0
@export var ranged_speed_multiplier: float = 1.0

## 魔法武器系数（已废弃，请使用base_stats）
@export var magic_damage_multiplier: float = 1.0
@export var magic_range_multiplier: float = 1.0
@export var magic_speed_multiplier: float = 1.0
@export var magic_explosion_radius_multiplier: float = 1.0

## 特殊技能配置
@export var skill_name: String = ""
@export var skill_description: String = ""
@export var skill_params: Dictionary = {}

## 职业特性描述（自动生成）
@export var traits: Array = []

## 初始化函数
## 
## 保留旧的初始化参数以兼容现有代码
## 但同时创建并填充base_stats
func _init(
	p_name: String = "默认职业",
	p_max_hp: int = 100,
	p_speed: float = 400.0,
	p_attack_multiplier: float = 1.0,
	p_defense: int = 0,
	p_crit_chance: float = 0.0,
	p_crit_damage: float = 1.5,
	p_skill_name: String = "",
	p_skill_params: Dictionary = {}
) -> void:
	name = p_name
	
	# 填充旧属性（向后兼容）
	max_hp = p_max_hp
	speed = p_speed
	attack_multiplier = p_attack_multiplier
	defense = p_defense
	crit_chance = p_crit_chance
	crit_damage = p_crit_damage
	skill_name = p_skill_name
	skill_params = p_skill_params
	
	# 创建新的CombatStats并填充基础值
	base_stats = CombatStats.new()
	base_stats.max_hp = p_max_hp
	base_stats.speed = p_speed
	base_stats.defense = p_defense
	base_stats.crit_chance = p_crit_chance
	base_stats.crit_damage = p_crit_damage
	base_stats.global_damage_mult = p_attack_multiplier
	
	# 其他属性保持默认值，由调用者在创建后手动设置

## 同步旧属性到base_stats
## 
## 当手动设置旧属性后，调用此方法同步到base_stats
## 确保两个系统的数据一致性
func sync_to_base_stats() -> void:
	if not base_stats:
		base_stats = CombatStats.new()
	
	# ⭐ 清零所有加法属性的默认值（防止意外累加）
	base_stats.max_hp = 0
	base_stats.speed = 0.0
	base_stats.defense = 0
	base_stats.luck = 0.0
	base_stats.crit_chance = 0.0
	base_stats.crit_damage = 0.0
	base_stats.damage_reduction = 0.0
	# 乘法属性保持1.0（正确行为）
	
	# 基础属性（设置实际值）
	base_stats.max_hp = max_hp
	base_stats.speed = speed
	base_stats.defense = defense
	base_stats.luck = luck
	base_stats.crit_chance = crit_chance
	base_stats.crit_damage = crit_damage
	
	# 减伤（注意：旧系统是乘数，新系统是减免比例）
	base_stats.damage_reduction = 1.0 - damage_reduction_multiplier
	
	# 全局武器属性
	base_stats.global_damage_mult = attack_multiplier
	base_stats.global_attack_speed_mult = attack_speed_multiplier
	
	# 近战武器属性
	base_stats.melee_damage_mult = melee_damage_multiplier
	base_stats.melee_speed_mult = melee_speed_multiplier
	base_stats.melee_range_mult = melee_range_multiplier
	base_stats.melee_knockback_mult = melee_knockback_multiplier
	
	# 远程武器属性
	base_stats.ranged_damage_mult = ranged_damage_multiplier
	base_stats.ranged_speed_mult = ranged_speed_multiplier
	base_stats.ranged_range_mult = ranged_range_multiplier
	
	# 魔法武器属性
	base_stats.magic_damage_mult = magic_damage_multiplier
	base_stats.magic_speed_mult = magic_speed_multiplier
	base_stats.magic_range_mult = magic_range_multiplier
	base_stats.magic_explosion_radius_mult = magic_explosion_radius_multiplier

## 自动生成职业特性描述
func generate_traits_description() -> void:
	traits.clear()
	
	# 基础属性
	if max_hp != 100:
		var diff = max_hp - 100
		traits.append("血量%+d" % diff if diff > 0 else "血量%d" % diff)
	
	if speed != 400.0:
		var percent = int((speed / 400.0 - 1.0) * 100)
		if percent != 0:
			traits.append("移动速度%+d%%" % percent if percent > 0 else "移动速度%d%%" % percent)
	
	if defense != 0:
		traits.append("防御%+d" % defense if defense > 0 else "防御%d" % defense)
	
	# 战斗属性
	if damage_reduction_multiplier != 1.0:
		var percent = int((1.0 - damage_reduction_multiplier) * 100)
		if percent != 0:
			traits.append("受到伤害%+d%%" % -percent if percent > 0 else "受到伤害%d%%" % -percent)
	
	# 总攻击速度
	if attack_speed_multiplier != 1.0:
		var percent = int((attack_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("攻击速度%+d%%" % percent if percent > 0 else "攻击速度%d%%" % percent)
	
	# 总武器伤害
	if attack_multiplier != 1.0:
		var percent = int((attack_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("所有武器伤害%+d%%" % percent if percent > 0 else "所有武器伤害%d%%" % percent)
	
	# 近战武器
	if melee_damage_multiplier != 1.0:
		var percent = int((melee_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器伤害%+d%%" % percent if percent > 0 else "近战武器伤害%d%%" % percent)
	
	if melee_speed_multiplier != 1.0:
		var percent = int((melee_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器速度%+d%%" % percent if percent > 0 else "近战武器速度%d%%" % percent)
	
	if melee_range_multiplier != 1.0:
		var percent = int((melee_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器范围%+d%%" % percent if percent > 0 else "近战武器范围%d%%" % percent)
	
	if melee_knockback_multiplier != 1.0:
		var percent = int((melee_knockback_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("近战武器击退%+d%%" % percent if percent > 0 else "近战武器击退%d%%" % percent)
	
	# 远程武器
	if ranged_damage_multiplier != 1.0:
		var percent = int((ranged_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器伤害%+d%%" % percent if percent > 0 else "远程武器伤害%d%%" % percent)
	
	if ranged_speed_multiplier != 1.0:
		var percent = int((ranged_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器速度%+d%%" % percent if percent > 0 else "远程武器速度%d%%" % percent)
	
	if ranged_range_multiplier != 1.0:
		var percent = int((ranged_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("远程武器范围%+d%%" % percent if percent > 0 else "远程武器范围%d%%" % percent)
	
	# 魔法武器
	if magic_damage_multiplier != 1.0:
		var percent = int((magic_damage_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法武器伤害%+d%%" % percent if percent > 0 else "魔法武器伤害%d%%" % percent)
	
	if magic_speed_multiplier != 1.0:
		var percent = int((magic_speed_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法冷却%+d%%" % percent if percent > 0 else "魔法冷却%d%%" % percent)
	
	if magic_range_multiplier != 1.0:
		var percent = int((magic_range_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("魔法武器范围%+d%%" % percent if percent > 0 else "魔法武器范围%d%%" % percent)
	
	if magic_explosion_radius_multiplier != 1.0:
		var percent = int((magic_explosion_radius_multiplier - 1.0) * 100)
		if percent != 0:
			traits.append("爆炸范围%+d%%" % percent if percent > 0 else "爆炸范围%d%%" % percent)
