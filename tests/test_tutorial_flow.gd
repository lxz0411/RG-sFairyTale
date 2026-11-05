extends SceneTree

var scene: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)

func place(index: int, start: Vector2, angle: float, flat_side_up: bool = true) -> void:
	var branch: Sprite2D = scene.branches[index]
	scene.begin_drag(index, branch.position)
	var axis: Vector2 = scene.SHAFTS[index][1] - scene.SHAFTS[index][0]
	var reverse := index == 1 and flat_side_up
	branch.rotation = angle - axis.angle() + (PI if reverse else 0.0)
	var local_start: Vector2 = scene.SHAFTS[index][1 if reverse else 0] - branch.texture.get_size() * 0.5
	var center := start - local_start.rotated(branch.rotation)
	scene.drop_at(center)

func run() -> void:
	scene = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	scene.get_node("Guide").enabled = false
	root.add_child(scene)
	await scene.get_node("Transition").revealed
	await process_frame
	check(scene.traveler.visible and scene.phase == scene.Phase.EDIT, "Character must wait at spawn")
	scene.press_at(Vector2(940, 240))
	check(scene.locations == [scene.Location.INVENTORY, scene.Location.TREE], "Vertical click collected wrong branch")
	scene.press_at(Vector2(870, 114))
	check(scene.locations == [scene.Location.INVENTORY, scene.Location.INVENTORY], "Horizontal collection failed")
	place(1, Vector2(313, 321), 0.18)
	place(0, Vector2(541, 364), 0.18)
	# The same bridge must fail with its fork up and succeed after a half-turn.
	place(1, Vector2(313, 321), 0.18, false)
	scene.start_level()
	for frame in range(300):
		await physics_frame
		if scene.phase != scene.Phase.WALK:
			break
	check(scene.phase == scene.Phase.STOPPED and scene.traveler.visible, "Upper fork must stop the character at %s phase %s" % [scene.traveler.position, scene.phase])
	check(scene.traveler.position.x < 430, "Character crossed the raised fork")
	scene.reset_level()
	await physics_frame
	await physics_frame
	place(1, Vector2(313, 321), 0.18)
	place(0, Vector2(541, 364), 0.18)
	var before: Transform2D = scene.branches[0].transform
	var mid: Vector2 = (scene.SHAFTS[0][0] + scene.SHAFTS[0][1]) * 0.5 - scene.branches[0].texture.get_size() * 0.5
	var grip: Vector2 = scene.branches[0].to_global(mid)
	scene.begin_rotation(grip)
	check(scene.rotating_branch == 0, "Right mouse could not select placed shaft")
	var motion := InputEventMouseMotion.new()
	motion.position = scene.branches[0].position + (grip - scene.branches[0].position).rotated(-0.12)
	scene._unhandled_input(motion)
	check(absf(angle_difference(before.get_rotation() - 0.12, scene.branches[0].rotation)) < 0.001, "Rotation must follow the pointer around the branch pivot")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	scene._unhandled_input(release)
	check(scene.rotating_branch == -1, "Right release failed")
	scene.branches[0].transform = before
	# Returning a branch to inventory and dragging it out preserves its angle.
	scene.saved_rotations[0] = scene.branches[0].rotation
	scene.begin_drag(0, scene.branches[0].position)
	scene.drop_at(Vector2(1192, 77))
	check(scene.locations[0] == scene.Location.INVENTORY, "Return to inventory failed")
	place(0, Vector2(541, 364), 0.18)
	scene.start_level()
	scene.press_at(Vector2(1192, 77))
	scene.begin_drag(0, Vector2.ZERO)
	check(scene.held == -1, "Editing was possible during run")
	for frame in range(900):
		await physics_frame
		if scene.phase != scene.Phase.WALK:
			break
	check(scene.phase == scene.Phase.COMPLETE, "Connected angled bridge did not complete. Position %s phase %s" % [scene.traveler.position, scene.phase])
	scene.reset_level()
	await physics_frame
	await physics_frame
	check(scene.traveler.position == scene.START and scene.phase == scene.Phase.EDIT, "Reset did not restore idle character")
	check(scene.locations == [scene.Location.INVENTORY, scene.Location.INVENTORY] and not scene.branches[0].visible and not scene.branches[1].visible, "Reset must recall both bridge props")
	# Move the second bridge down: walking off the first must fall onto it naturally.
	place(1, Vector2(313, 321), 0.18)
	place(0, Vector2(541, 379), 0.10)
	scene.start_level()
	for frame in range(900):
		await physics_frame
		if scene.phase != scene.Phase.WALK:
			break
	check(scene.phase == scene.Phase.COMPLETE, "Natural drop between bridges failed at %s" % scene.traveler.position)
	scene.reset_level()
	await physics_frame
	await physics_frame
	place(0, Vector2(541, 379), 0.10)
	scene.begin_drag(1, scene.branches[1].position)
	scene.drop_at(Vector2(1192, 201))
	scene.start_level()
	for frame in range(240):
		await physics_frame
		if scene.phase != scene.Phase.WALK:
			break
	check(scene.phase == scene.Phase.STOPPED and not scene.traveler.visible, "Gap must cause disappearance and manual reset")
	var fallen_position: Vector2 = scene.traveler.position
	for frame in range(10):
		await physics_frame
	check(scene.traveler.position == fallen_position, "Failed character moved before reset")
	scene.reset_level()
	await physics_frame
	await physics_frame
	check(scene.locations == [scene.Location.INVENTORY, scene.Location.INVENTORY], "Failure reset must recall all collected props")
	# Slightly overlapping visible ends with different slopes must remain supported.
	place(1, Vector2(313, 321), 0.25)
	place(0, Vector2(542, 378), 0.15)
	scene.start_level()
	for frame in range(900):
		await physics_frame
		if scene.phase != scene.Phase.WALK:
			break
	check(scene.phase == scene.Phase.COMPLETE, "Visible overlapping seam dropped or trapped traveler at %s" % scene.traveler.position)
	scene.reset_level()
	await physics_frame
	await physics_frame
	# Isolate the wood from scenery and verify both faces and both end caps.
	place(1, Vector2(400, 220), 0.0)
	place(0, Vector2(700, 220), 0.0)
	scene.sync_plank_surfaces()
	await physics_frame
	await physics_frame
	for index in range(2):
		var branch: Sprite2D = scene.branches[index]
		var half := branch.texture.get_size() * 0.5
		var a: Vector2 = branch.to_global(scene.SHAFTS[index][0] - half)
		var b: Vector2 = branch.to_global(scene.SHAFTS[index][1] - half)
		var axis := (b - a).normalized()
		var normal := axis.orthogonal()
		for fraction in [0.02, 0.5, 0.98]:
			var point := a.lerp(b, fraction)
			for side in [-1.0, 1.0]:
				var ray := PhysicsRayQueryParameters2D.create(point + normal * 40 * side, point - normal * 40 * side)
				var hit := scene.get_world_2d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and hit.collider.has_meta("branch_index"), "Wood must be solid from both faces")
		for endpoints in [[a - axis * 20, a + axis * 20], [b + axis * 20, b - axis * 20]]:
			var ray := PhysicsRayQueryParameters2D.create(endpoints[0], endpoints[1])
			var hit := scene.get_world_2d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider.has_meta("branch_index"), "Wood end cap must be solid")
	print("PASS: solid faces and end caps, overlapping seam, raised fork blocks, flat side passes, independent pickup, drag, return, rotation, edit lock, angled crossing, step-down crossing, fall, recall on reset")
	scene.queue_free()
	await process_frame
	quit()

