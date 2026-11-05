extends SceneTree

const SAMPLE_LAYOUT := {
	&"horn1": Vector2(75, 190),
	&"horn2": Vector2(615, 130),
	&"flower1": Vector2(871, 485),
	&"flower2": Vector2(480, 440),
}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> bool:
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

func snapshot(name: String) -> void:
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/level1_%s.png" % name)

func arrange(scene: Node2D) -> void:
	for item in scene.items:
		scene.begin_drag(item, scene.slot_center(item))
		scene.move_drag(SAMPLE_LAYOUT[item.item_id])
		item.rotation = 0.0
		scene.finish_drag()

func run() -> void:
	if not check(ResourceLoader.exists("res://scenes/level_1.tscn"), "Missing first level"):
		return
	var scene = load("res://scenes/level_1.tscn").instantiate()
	scene.next_level_scene = ""
	root.add_child(scene)
	await scene.get_node("Transition").revealed
	await snapshot("initial")
	scene.start_level()
	for frame in range(500):
		await physics_frame
		if scene.phase == scene.Phase.FAILED:
			break
	if not check(scene.phase == scene.Phase.FAILED, "Uncontrolled butterfly must fly offscreen"):
		return
	scene.reset_level()
	for item in scene.items:
		var image: Image = item.texture.get_image()
		var closest := Vector2.ZERO
		var distance := INF
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var offset := Vector2(x, y) - Vector2(image.get_size()) * 0.5
				if image.get_pixel(x, y).a > 0.8 and offset.length_squared() < distance:
					distance = offset.length_squared()
					closest = offset
		click(item.to_global(closest))
	if not check(scene.inventory.size() == 4, "All four props must enter inventory"):
		return
	for item in scene.items:
		var press := InputEventMouseButton.new()
		press.position = scene.slot_center(item)
		press.global_position = press.position
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		root.push_input(press, true)
		var move := InputEventMouseMotion.new()
		move.position = SAMPLE_LAYOUT[item.item_id] + Vector2(23, -17)
		move.global_position = move.position
		root.push_input(move, true)
		item.rotation = 0.23
		var release := InputEventMouseButton.new()
		release.position = move.position
		release.global_position = move.position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		root.push_input(release, true)
		if not check(item.position.is_equal_approx(move.position) and is_equal_approx(item.rotation, 0.23), "Dropping a prop must preserve the exact position and rotation"):
			return
		item.position = SAMPLE_LAYOUT[item.item_id]
		item.rotation = 0.0
	if not check(scene.inventory.is_empty(), "Deployed props must leave the inventory"):
		return
	await snapshot("arrangement")
	var horn = scene.get_node("Horn1")
	var flower = scene.get_node("Flower2")
	horn.position += Vector2(160, 70)
	horn.rotation = 0.4
	flower.position += Vector2(200, 50)
	flower.rotation = -0.2
	scene.butterfly.position = horn.to_global(horn.get_meta("mouth")) + Vector2(0, 40)
	scene.start_level()
	for frame in range(300):
		await physics_frame
		if scene.flight_stage == scene.FlightStage.REST_PLATE or scene.phase == scene.Phase.FAILED:
			break
	if not check(scene.flight_stage == scene.FlightStage.REST_PLATE and scene.butterfly.position.distance_to(flower.to_global(Vector2(-10, -45))) < 1.0, "Horn and flower must work at freely chosen positions and rotations"):
		return
	scene.reset_level()
	arrange(scene)
	horn.rotation = PI
	scene.start_level()
	for frame in range(600):
		await physics_frame
		if scene.phase == scene.Phase.FAILED:
			break
	if not check(scene.phase == scene.Phase.FAILED, "A reversed horn must not solve the level"):
		return
	scene.reset_level()
	arrange(scene)
	horn.rotation = 0.0
	scene.start_level()
	var landed_plate := false
	var captured_rest := false
	for frame in range(1800):
		await physics_frame
		landed_plate = landed_plate or scene.flight_stage == scene.FlightStage.REST_PLATE
		if landed_plate and not captured_rest:
			captured_rest = true
			await snapshot("plate_rest")
		if scene.phase in [scene.Phase.COMPLETE, scene.Phase.FAILED]:
			break
	if not check(landed_plate, "Butterfly did not pause at the plate flower"):
		return
	if not check(scene.phase == scene.Phase.COMPLETE and scene.star_collected, "Correct arrangement must cross the star and perch"):
		return
	if not check(scene.horn_blow_count == 2, "Each horn should blow once as butterfly approaches"):
		return
	for frame in range(240):
		await physics_frame
	if not check(scene.get_node("GoldenPetal").modulate.a < 0.05, "Golden petal must leave through the window"):
		return
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/level1_completed.png")
	scene.reset_level()
	if not check(not scene.star_collected and scene.get_node("GoldenPetal").modulate.a == 1.0, "Reset must restore star and petal"):
		return
	for sound in scene.get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
	await create_timer(0.1).timeout
	print("PASS: exact drop position/rotation, free placement response, inventory/deployment, uncontrolled flight, wrong orientation, two horns, plate rest, star collision, vase perch, golden petal, reset")
	scene.queue_free()
	await process_frame
	quit(0)
