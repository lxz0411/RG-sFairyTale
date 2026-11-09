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

func snapshot(name: String) -> void:
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/game_start_%s.png" % name)

func run() -> void:
	if not require(ResourceLoader.exists("res://scenes/game_start.tscn"), "Missing startup scene"):
		return
	var scene = load("res://scenes/game_start.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var progress: Dictionary = root.get_node("GameProgress").completed.duplicate()
	await scene.get_node("Transition").revealed
	if not require(scene.has_node("Butterfly") and scene.has_node("Traveler/Scarf") and scene.has_node("Traveler/Body"), "Butterfly and traveler must be separate animated scene layers"):
		return
	var butterfly: AnimatedSprite2D = scene.get_node("Butterfly")
	var scarf: Sprite2D = scene.get_node("Traveler/Scarf")
	var traveler: Node2D = scene.get_node("Traveler")
	var butterfly_start := butterfly.position
	var frame_start := butterfly.frame
	var scarf_start: float = scarf.material.get_shader_parameter("wave_time")
	var traveler_start := traveler.position
	await create_timer(0.18).timeout
	if not require(butterfly.is_playing() and butterfly.frame != frame_start and absf(butterfly.position.y - butterfly_start.y) > 0.01 and absf(butterfly.position.y - 455.0) <= 4.1, "Butterfly must flap its wings while hovering gently"):
		return
	if not require(scarf.material.get_shader_parameter("wave_time") > scarf_start and traveler.position == traveler_start, "Only the scarf must wave while the traveler remains standing"):
		return
	if not require(scene.gear_speed_degrees > 20.0 and scene.gear_speed_degrees <= 30.0, "Gears must rotate slightly faster"):
		return
	if not require(scene.has_node("Mechanism/LargeGear") and scene.has_node("Mechanism/SmallGear") and scene.has_node("Mechanism/TitleGear"), "Cover gears must be independent scene nodes"):
		return
	var large: Sprite2D = scene.get_node("Mechanism/LargeGear")
	var small: Sprite2D = scene.get_node("Mechanism/SmallGear")
	var title: Sprite2D = scene.get_node("Mechanism/TitleGear")
	var short_rod: Sprite2D = scene.get_node("Mechanism/ShortRod")
	var long_rod: Sprite2D = scene.get_node("Mechanism/LongRod")
	scene.set_process(false)
	for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
		scene.gear_angle = angle
		scene._update_mechanism()
		# Measured hub centers in the source PNGs, relative to their canvas centers.
		var large_hub := large.to_global(Vector2(0, -1) + large.offset)
		var small_hub := small.to_global(Vector2(-1, -1) + small.offset)
		if not require(large_hub.distance_to(large.global_position) < 0.1 and small_hub.distance_to(small.global_position) < 0.1, "Visible gear hubs must stay on the rotation axes"):
			return
		if not require(short_rod.to_global(Vector2(42, 49)).distance_to(large_hub) < 0.1 and short_rod.to_global(Vector2(224, 53)).distance_to(small_hub) < 0.1 and long_rod.to_global(Vector2(32, 71)).distance_to(small_hub) < 0.1, "Rod axle caps must remain centered on both gear hubs throughout rotation"):
			return
	scene.gear_angle = 0.0
	scene._update_mechanism()
	scene.set_process(true)
	var large_start := large.rotation
	var small_start := small.rotation
	var title_start := title.rotation
	var large_center := large.position
	var small_center := small.position
	await create_timer(1.0).timeout
	if not require((large.rotation - large_start) * (small.rotation - small_start) < 0.0 and absf(title.rotation - title_start) > 0.05, "Meshing gears must turn in opposite directions and the title gear must rotate"):
		return
	if not require(large.position == large_center and small.position == small_center, "Rotating gears must remain on their fixed axles"):
		return
	if not require(long_rod.to_global(Vector2(352, 42)).distance_to(Vector2(552, 594)) < 0.1, "Connecting rod must remain attached to the bellows pivot"):
		return
	var door: TextureButton = scene.get_node("Door")
	if not require(not scene.opening and not door.disabled and door.size.x < 180, "Idle door must glow and have a doorway-sized click region"):
		return
	await snapshot("closed")
	click(Vector2(500, 400))
	if not require(not scene.opening, "Clicking the illustration must not start the game"):
		return
	click(door.get_global_rect().get_center())
	if not require(scene.opening and door.disabled and door.texture_normal == scene.open_texture and not scene.get_node("DoorGlow").visible, "Door click must show the open state, extinguish its glow and reject repeated clicks"):
		return
	await snapshot("open")
	if not require(current_scene == scene and not scene.get_node("Transition").visible, "The opened door must remain visible before the exit transition"):
		return
	await scene.get_node("Transition").covered
	await process_frame
	await process_frame
	if not require(current_scene.scene_file_path == "res://scenes/level_select.tscn", "Startup must enter level selection"):
		return
	if not require(root.get_node("GameProgress").completed == progress, "Opening the cover must preserve progress"):
		return
	current_scene.queue_free()
	await process_frame
	print("PASS: butterfly flapping and hovering, scarf wave, faster gears, fixed axles, attached rod, doorway-only click, open-door hold, transition to selection and unchanged progress")
	quit(0)
