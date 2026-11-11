extends "res://scripts/level_item.gd"

func hit(point: Vector2) -> bool:
	var p := to_local(point)
	return Geometry2D.is_point_in_polygon(p, PackedVector2Array([
		Vector2(-97,1),Vector2(-88,-12),Vector2(-63,-21),Vector2(-72,-27),
		Vector2(-65,-39),Vector2(-31,-50),Vector2(-9,-51),Vector2(4,-39),
		Vector2(33,20),Vector2(69,-58),Vector2(71,-75),Vector2(84,-72),
		Vector2(98,-55),Vector2(84,-48),Vector2(50,21),Vector2(50,52),
		Vector2(38,61),Vector2(-23,75),Vector2(-45,64),Vector2(-51,50),
		Vector2(-82,62),Vector2(-93,55)]))
