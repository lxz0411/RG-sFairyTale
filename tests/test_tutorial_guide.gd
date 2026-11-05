extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func snapshot(name: String) -> void:
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/guide_%s.png" % name)

func mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func click(point: Vector2) -> void:
	mouse(point, MOUSE_BUTTON_LEFT, true)
	mouse(point, MOUSE_BUTTON_LEFT, false)

func drag(from: Vector2, to: Vector2) -> void:
	mouse(from, MOUSE_BUTTON_LEFT, true)
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	root.push_input(event, true)
	mouse(to, MOUSE_BUTTON_LEFT, false)

func run() -> void:
	var scene = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	root.add_child(scene)
	await scene.get_node("Transition").revealed
	await process_frame
	if not require(scene.has_node("Guide"), "Missing four-step tutorial spotlight"):
		return
	var guide = scene.get_node("Guide")
	await snapshot("1_collect")
	click(Vector2(126, 45))
	if not require(scene.phase == scene.Phase.EDIT, "Guide allowed starting before collecting"):
		return
	click(Vector2(940, 240))
	if not require(guide.step == guide.Step.COLLECT, "Collect step ended after only one branch"):
		return
	click(Vector2(870, 114))
	await create_timer(0.35).timeout
	if not require(guide.step == guide.Step.PLACE, "Collecting both branches did not advance"):
		return
	await snapshot("2_place")
	drag(scene.slot_center(scene.branches[0]), Vector2(500, 420))
	if not require(guide.step == guide.Step.PLACE, "Place step ended after only one branch"):
		return
	drag(scene.slot_center(scene.branches[1]), Vector2(650, 420))
	if not require(guide.step == guide.Step.ROTATE, "Placing both branches did not advance"):
		return
	if not require(not guide.get_node("Shade").visible and guide.allows_point(Vector2(50, 50)), "Step 3 must remove the mask and unblock the scene"):
		return
	if not require(guide.allows(&"start") and guide.allows(&"drag") and guide.allows(&"rotate"), "Step 3 must not require rotation before starting"):
		return
	await snapshot("3_rotate")
	scene.selected_branch = 0
	scene.rotate_branch(0.3)
	if not require(guide.step == guide.Step.ROTATE, "Wheel/keyboard rotation incorrectly completed right-mouse lesson"):
		return
	var branch: Sprite2D = scene.branches[0]
	var local_point: Vector2 = scene.SHAFTS[0][0].lerp(scene.SHAFTS[0][1], 0.7) - branch.texture.get_size() * 0.5
	var grip := branch.to_global(local_point)
	mouse(grip, MOUSE_BUTTON_RIGHT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = branch.position + (grip - branch.position).rotated(0.4)
	root.push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	root.push_input(release, true)
	if not require(guide.step == guide.Step.START, "Actual right-mouse rotation did not advance"):
		return
	await snapshot("4_start")
	await process_frame
	await process_frame
	var arrow: Node2D = guide.get_node("StartArrow")
	if not require(arrow.is_visible_in_tree(), "Start guidance arrow is missing"):
		return
	var arrow_before := arrow.position
	await create_timer(0.25).timeout
	if not require(absf(arrow.position.x - arrow_before.x) > 1.0 and is_equal_approx(arrow.position.y, arrow_before.y), "Start arrow must move horizontally"):
		return
	if not require(not guide.get_node("Shade").visible and guide.allows_point(Vector2(500, 420)), "Step 4 must stay unmasked and allow free operation"):
		return
	click(Vector2(126, 45))
	await process_frame
	if not require(guide.step == guide.Step.DONE and not guide.visible and scene.phase == scene.Phase.WALK, "Start did not finish and hide guide"):
		return
	scene.reset_level()
	if not require(guide.step == guide.Step.DONE, "Retry unexpectedly restarted the guide"):
		return
	for sound in scene.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	print("PASS: masked collection/placement, unmasked non-blocking rotation/start, optional right-mouse hint, start, retry")
	quit(0)
