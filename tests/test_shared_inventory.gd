extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func click(point: Vector2) -> void:
	mouse(point, true)
	mouse(point, false)

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func drag(from: Vector2, to: Vector2) -> void:
	mouse(from, true)
	motion(to)
	mouse(to, false)

func opaque_point(item: Sprite2D) -> Vector2:
	var image := item.texture.get_image()
	var nearest := Vector2.ZERO
	var distance := INF
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var offset := Vector2(x, y) - Vector2(image.get_size()) * 0.5
			if image.get_pixel(x, y).a > 0.8 and offset.length_squared() < distance:
				distance = offset.length_squared()
				nearest = offset
	return item.to_global(nearest)

func run() -> void:
	for path in ["res://scenes/tutorial_backdrop.tscn", "res://scenes/level_1.tscn"]:
		if not await check_level(path):
			return
	if not await check_guide_reset():
		return
	print("PASS: both levels share ordered slots, reserved holes, original-slot return and one-click reset during dragging/running; uncollected props stay in the scene")
	quit(0)

func check_level(path: String) -> bool:
	var level = load(path).instantiate()
	level.next_level_scene = ""
	if level.has_node("Guide"):
		level.get_node("Guide").enabled = false
	root.add_child(level)
	await level.get_node("Transition").revealed
	var order: Array[Sprite2D] = []
	if level.has_node("BranchHorizontal"):
		order = [level.get_node("BranchHorizontal"), level.get_node("BranchVertical")]
	else:
		order = [level.get_node("Flower2"), level.get_node("Horn2"), level.get_node("Horn1"), level.get_node("Flower1")]
	var untouched: Transform2D = order[1].transform
	click(opaque_point(order[0]))
	await create_timer(0.35).timeout
	var first: Sprite2D = level.get_node("Inventory/Icon1")
	if not require(first.texture == order[0].texture, path + ": first clicked prop must occupy the first slot"):
		return false
	drag(first.global_position, Vector2(500, 420))
	click(Vector2(48, 45))
	if not require(first.texture == order[0].texture and not order[0].visible, path + ": one reset click must recall the deployed prop"):
		return false
	if not require(order[1].visible and order[1].transform == untouched, path + ": reset must leave uncollected props untouched"):
		return false
	drag(first.global_position, Vector2(500, 420))
	for index in range(1, order.size()):
		click(opaque_point(order[index]))
		await create_timer(0.35).timeout
		var icon: Sprite2D = level.get_node("Inventory/Icon%d" % (index + 1))
		if not require(icon.texture == order[index].texture and first.texture == null, path + ": collection must respect click order without filling a reserved hole"):
			return false
	var first_grip := opaque_point(order[0])
	drag(first_grip, level.get_node("Inventory/Icon5").global_position)
	if not require(first.texture == order[0].texture, path + ": returning to any backpack area must restore the original slot"):
		return false
	drag(first.global_position, Vector2(500, 420))
	var second: Sprite2D = level.get_node("Inventory/Icon2")
	if not require(second.texture == order[1].texture, path + ": later props must stay in their original slots"):
		return false
	mouse(second.global_position, true)
	motion(Vector2(650, 420))
	click(Vector2(48, 45))
	for index in range(order.size()):
		var icon: Sprite2D = level.get_node("Inventory/Icon%d" % (index + 1))
		if not require(icon.texture == order[index].texture and not order[index].visible, path + ": reset during a drag must recall every collected prop once"):
			return false
	click(Vector2(48, 45))
	drag(first.global_position, Vector2(500, 420))
	click(Vector2(126, 45))
	click(Vector2(48, 45))
	if not require(level.phase == 0 and first.texture == order[0].texture, path + ": reset during a run must restore editing and the inventory"):
		return false
	level.queue_free()
	await process_frame
	return true

func check_guide_reset() -> bool:
	var level = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	root.add_child(level)
	await level.get_node("Transition").revealed
	var guide = level.get_node("Guide")
	click(opaque_point(level.get_node("BranchHorizontal")))
	click(Vector2(48, 45))
	if not require(guide.step == guide.Step.COLLECT and level.get_node("BranchVertical").visible, "Partial collection reset must preserve the remaining collection lesson"):
		return false
	click(opaque_point(level.get_node("BranchVertical")))
	guide.update_holes()
	var first: Sprite2D = level.get_node("Inventory/Icon1")
	var second: Sprite2D = level.get_node("Inventory/Icon2")
	if not require(guide.step == guide.Step.PLACE and guide.allows_point(first.global_position) and guide.allows_point(second.global_position), "Place guidance must expose the actual reserved slots"):
		return false
	drag(first.global_position, Vector2(500, 420))
	drag(second.global_position, Vector2(650, 420))
	click(Vector2(48, 45))
	if not require(guide.step == guide.Step.PLACE and first.texture != null and second.texture != null, "Reset after placement must recall props and allow placing them again"):
		return false
	level.queue_free()
	await process_frame
	return true
