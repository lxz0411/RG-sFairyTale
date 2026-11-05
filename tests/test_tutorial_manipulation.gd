extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func run() -> void:
	var scene = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	scene.get_node("Guide").enabled = false
	root.add_child(scene)
	await scene.get_node("Transition").revealed
	if not require(scene.has_method("rotate_branch"), "Tutorial lacks physics-style selected-item rotation"):
		return
	scene.collect_branch(0)
	await create_timer(0.35).timeout
	var branch: Sprite2D = scene.branches[0]
	mouse(scene.slot_center(scene.branches[0]), MOUSE_BUTTON_LEFT, true)
	motion(Vector2(480, 350))
	mouse(Vector2(480, 350), MOUSE_BUTTON_LEFT, false)
	if not require(branch.position.distance_to(Vector2(480, 350)) < 0.01, "Inventory drag did not follow pointer"):
		return
	if not require(branch.scale == Vector2.ONE, "Placed branch changed size"):
		return
	# Grab an opaque point away from the pivot, then orbit by exactly 90 degrees.
	var local_grip: Vector2 = scene.SHAFTS[0][0].lerp(scene.SHAFTS[0][1], 0.7) - branch.texture.get_size() * 0.5
	var grip := branch.to_global(local_grip)
	var initial_angle := branch.rotation
	mouse(grip, MOUSE_BUTTON_RIGHT, true)
	if not require(scene.rotating_branch == 0, "Right press could not select the branch"):
		return
	if not require(is_equal_approx(branch.rotation, initial_angle), "Right press caused an angle jump"):
		return
	motion(branch.position + (grip - branch.position).rotated(PI * 0.5))
	if not require(absf(angle_difference(initial_angle + PI * 0.5, branch.rotation)) < 0.001, "Rotation did not match the pointer orbit"):
		return
	if not require(branch.position.distance_to(Vector2(480, 350)) < 0.01, "Rotation moved the pivot"):
		return
	mouse(grip, MOUSE_BUTTON_RIGHT, false)
	var rotated := branch.rotation
	motion(Vector2(900, 100))
	if not require(is_equal_approx(branch.rotation, rotated), "Right release did not end rotation"):
		return
	mouse(grip, MOUSE_BUTTON_WHEEL_DOWN, true)
	if not require(absf(angle_difference(rotated + deg_to_rad(5), branch.rotation)) < 0.001, "Wheel rotation differs from physics scene"):
		return
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var before_key := branch.rotation
	scene._process(0.2)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	if not require(absf(angle_difference(before_key + 0.3, branch.rotation)) < 0.001, "E rotation speed differs from physics scene: %s -> %s" % [before_key, branch.rotation]):
		return
	scene.begin_drag(0, branch.position)
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)
	if not require(scene.held == -1 and scene.locations[0] == scene.Location.INVENTORY, "Esc did not return the dragged branch"):
		return
	for sound in scene.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	print("PASS: real pointer inventory drag, fixed size/pivot, angular orbit, no press jump, right release, wheel, E speed, Esc")
	quit(0)
