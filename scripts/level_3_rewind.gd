extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var amount: float = get_parent().rewind_amount
	if amount <= 0.0:
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.07, 0.045, 0.03, amount * 0.98))
	var gold := Color(0.84, 0.7, 0.41, amount)
	var center := Vector2(640, 400)
	draw_arc(center, 100, 0, TAU, 64, gold, 4, true)
	for tick in range(12):
		var direction := Vector2.UP.rotated(tick * TAU / 12.0)
		draw_line(center + direction * 86, center + direction * 96, gold, 3, true)
	var spin: float = get_parent().rewind_spin
	draw_line(center, center + Vector2.UP.rotated(-spin) * 78, gold, 5, true)
	draw_line(center, center + Vector2.UP.rotated(-spin * 0.25) * 50, gold, 7, true)
