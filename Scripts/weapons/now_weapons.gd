extends Node2D

var weapon_radius = 230
var weapon_num = 0

func _ready() -> void:
	var weapon_num = self.get_child_count()
	var unit = TAU / weapon_num
	var weapons = self.get_children()
	
	for i in len(weapons):
		var weapon = weapons[i]
		var weapon_rad = unit * i
		var end_pos = weapon.position + Vector2(weapon_radius,0).rotated(weapon_rad)
		weapon.position = end_pos
	pass
