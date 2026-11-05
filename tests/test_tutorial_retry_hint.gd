extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func place(level: Node2D, index: int, start: Vector2, angle: float, flat_side_up: bool = true) -> void:
	var branch: Sprite2D = level.branches[index]
	level.begin_drag(index, level.slot_center(branch))
	var axis: Vector2 = level.SHAFTS[index][1] - level.SHAFTS[index][0]
	var reverse := index == 1 and flat_side_up
	branch.rotation = angle - axis.angle() + (PI if reverse else 0.0)
	var local_start: Vector2 = level.SHAFTS[index][1 if reverse else 0] - branch.texture.get_size() * 0.5
	level.drop_at(start - local_start.rotated(branch.rotation))

func check_hint(level: Node2D, name: String, delay: float = 0.0) -> bool:
	if delay > 0.0:
		for frame in range(ceili(delay * Engine.physics_ticks_per_second) - 4):
			await physics_frame
			if not require(not level.get_node("Guide").visible, name + ": retry spotlight appeared before its delay"):
				return false
		for frame in range(8):
			await physics_frame
	await process_frame
	await process_frame
	var guide = level.get_node("Guide")
	var button: Sprite2D = level.get_node("ResetIcon")
	var center := (button.global_transform * button.get_rect()).get_center()
	if not require(guide.visible and guide.get_node("Shade").visible, name + ": failure must show the reset spotlight"):
		return false
	if not require(guide.holes.size() == 1 and guide.holes[0].has_point(center), name + ": the reset button must be the only clear area"):
		return false
	if not require(guide.allows_point(center) and not guide.allows_point(Vector2(500, 420)), name + ": reset must remain clickable through the mask"):
		return false
	if not require(not guide.get_node("StartArrow").visible and not guide.get_node("RightMouse").visible, name + ": failure must hide unrelated lesson hints"):
		return false
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/tutorial_retry_%s.png" % name)
	click(center)
	await process_frame
	if not require(level.phase == level.Phase.EDIT and not guide.visible and level.inventory.size() == 2, name + ": one reset click must clear the hint and recall collected props"):
		return false
	return true

func run() -> void:
	var level = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	level.next_level_scene = ""
	root.add_child(level)
	await level.get_node("Transition").revealed
	level.collect_branch(0)
	level.collect_branch(1)
	level.get_node("Guide").finish()
	place(level, 0, Vector2(541, 364), 0.18)
	place(level, 1, Vector2(313, 321), 0.18, false)
	level.start_level()
	for frame in range(360):
		await physics_frame
		if level.phase == level.Phase.STOPPED:
			break
	if not require(level.phase == level.Phase.STOPPED and level.traveler.visible, "Raised fork must stop the traveler"):
		return
	if not await check_hint(level, "fork", 2.0):
		return
	level.start_level()
	for frame in range(360):
		await physics_frame
		if level.phase == level.Phase.STOPPED:
			break
	if not require(level.phase == level.Phase.STOPPED and not level.traveler.visible, "Falling out of the scene must stop the run"):
		return
	if not await check_hint(level, "fall", 1.0):
		return
	# An ordinary wall has no branch/fork tags: lack of progress must detect it.
	var wall := StaticBody2D.new()
	wall.position = Vector2(310, 260)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 200)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await physics_frame
	await physics_frame
	level.start_level()
	for frame in range(360):
		await physics_frame
		if level.phase == level.Phase.STOPPED:
			break
	if not require(level.phase == level.Phase.STOPPED and level.traveler.visible, "An untagged obstacle must be detected as a stalled run"):
		return
	if not await check_hint(level, "wall"):
		return
	# Reset before a pending hint expires must cancel it, including on a later run.
	level.start_level()
	level.stop_walk(true)
	level.reset_level()
	for frame in range(90):
		await physics_frame
	if not require(level.phase == level.Phase.EDIT and not level.get_node("Guide").visible, "Reset must cancel a pending spotlight"):
		return
	level.queue_free()
	await process_frame
	print("PASS: stuck hint waits 2s, fallen hint waits 1s, generic stall and reset cancellation")
	quit(0)
