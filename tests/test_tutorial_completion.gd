extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var scene = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var entry = scene.get_node("Transition")
	if not require(entry.visible and entry.entering, "New scene must start covered by its entry transition"):
		return
	if not require(is_equal_approx(entry.get_node("Cover").material.get_shader_parameter("progress"), 1.05), "Entry did not start fully black"):
		return
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var first_frame := root.get_texture().get_image()
		if not require(first_frame.get_pixel(5, 5).get_luminance() < 0.01, "First frame flashed before entry"):
			return
		await create_timer(entry.expansion_duration * 0.5).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/tutorial_circle_entry.png")
	await entry.revealed
	if not require(not entry.visible, "Entry did not clear its final dot"):
		return
	await process_frame
	if not require(scene.has_method("pass_level"), "Completion must expose an independent pass_level()"):
		return
	var detector: Area2D = scene.get_node("Traveler/StarDetector")
	var star_area: Area2D = scene.get_node("GoalStar/Trigger")
	if not require(star_area.is_in_group("star"), "Star trigger needs the star group"):
		return
	# Old destination coordinates must no longer pass the level when the star moves.
	scene.star.position = Vector2(500, 120)
	scene.traveler.position = Vector2(1070, 392)
	scene.phase = scene.Phase.WALK
	for frame in range(4):
		await physics_frame
	if not require(scene.phase != scene.Phase.COMPLETE, "Old coordinate rule is still active"):
		return
	# A real overlap with a relocated star must trigger, even far from the exit.
	scene.reset_walk()
	scene.star.position = Vector2(400, 250)
	scene.traveler.position = Vector2(425, 315)
	for frame in range(5):
		await physics_frame
	if not require(scene.phase == scene.Phase.COMPLETE, "Touching the relocated star did not pass the level"):
		return
	var active_tween = scene.get_node("Transition").animation
	scene.pass_level()
	if not require(active_tween == scene.get_node("Transition").animation, "Repeated contact restarted completion"):
		return
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var starting_image := root.get_texture().get_image()
		var starting_center := starting_image.get_size() / 2
		if not require(starting_image.get_pixelv(starting_center).get_luminance() < 0.01, "Starting dot is missing"):
			return
		for offset in [Vector2i(8, 0), Vector2i(-8, 0), Vector2i(0, 8), Vector2i(0, -8)]:
			if not require(starting_image.get_pixelv(starting_center + offset).get_luminance() > 0.02, "Starting circle is larger than a tiny dot"):
				return
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		starting_image.save_png("user://screenshots/tutorial_transition_start.png")
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		var center := screenshot.get_size() / 2
		if not require(screenshot.get_pixelv(center).get_luminance() < 0.01, "Transition center is not black"):
			return
		if not require(screenshot.get_pixel(5, 5).get_luminance() > 0.02, "Circle covered corners before expanding"):
			return
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		screenshot.save_png("user://screenshots/tutorial_circle_transition.png")
	# The cover must complete before the current scene is replaced.
	var original_id: int = scene.get_instance_id()
	await scene.get_node("Transition").covered
	if "--visual-check" in OS.get_cmdline_user_args():
		var covered_image := root.get_texture().get_image()
		var size := covered_image.get_size()
		for corner in [Vector2i.ZERO, Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), size - Vector2i.ONE]:
			if not require(covered_image.get_pixelv(corner).get_luminance() < 0.01, "Scene switched before a fully covered frame"):
				return
	await process_frame
	await process_frame
	if not require(current_scene != null and current_scene.get_instance_id() != original_id, "Covered screen did not load the next scene"):
		return
	if not require(current_scene.phase == current_scene.Phase.EDIT, "Reloaded tutorial did not start fresh"):
		return
	var next_entry = current_scene.get_node("Transition")
	if not require(next_entry.visible and next_entry.entering, "Reload did not automatically start entry"):
		return
	await next_entry.revealed
	if not require(not next_entry.visible, "Reloaded scene stayed black"):
		return
	# The public completion function also works without any star contact.
	current_scene.pass_level()
	if not require(current_scene.phase == current_scene.Phase.COMPLETE, "pass_level depends on collision state"):
		return
	current_scene.reset_walk()
	if not require(not current_scene.get_node("Transition").visible, "Reset did not cancel the cover"):
		return
	# The two Inspector timings must independently control expansion and black hold.
	var transition = current_scene.get_node("Transition")
	transition.expansion_duration = 0.1
	transition.black_hold_duration = 0.3
	var covered := [false]
	transition.covered.connect(func(): covered[0] = true, CONNECT_ONE_SHOT)
	transition.play_exit()
	while float(transition.get_node("Cover").material.get_shader_parameter("progress")) < 1.05:
		await process_frame
	await create_timer(0.1).timeout
	if not require(not covered[0], "Black hold was skipped after expansion"):
		return
	await create_timer(0.3).timeout
	if not require(covered[0], "Black hold did not finish using its configured duration"):
		return
	transition.cancel()
	current_scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("PASS: star group, real overlap, no coordinate gate, independent/idempotent completion, exit/entry transitions, cover then reload, reset")
	quit(0)
