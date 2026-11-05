extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var level = load("res://scenes/level_1.tscn").instantiate()
	level.next_level_scene = ""
	root.add_child(level)
	await level.get_node("Transition").revealed
	var horn = level.item_by_id(&"horn2")
	var flower = level.item_by_id(&"flower1")
	for item in [horn, flower]:
		level.collect_item(item)
		level.begin_drag(item, level.slot_center(item))
		level.move_drag(Vector2(615, 130) if item == horn else Vector2(900, 720))
		item.rotation = 0.0
		level.finish_drag()
	level.butterfly.position = horn.to_global(horn.get_meta("mouth")) + Vector2(0, 70)
	level.start_level()
	level.try_horn(&"horn2")
	if not require(level.flight_stage == level.FlightStage.BLOW_SECOND, "Second horn must reach a flower more than 500 pixels away"):
		return
	var destination: Vector2 = flower.to_global(Vector2(-81, 105))
	for frame in range(130):
		await physics_frame
		if level.flight_stage == level.FlightStage.APPROACH_VASE:
			break
	if not require(level.flight_stage == level.FlightStage.APPROACH_VASE and level.butterfly.position.distance_to(destination) < 1.0, "Second horn must carry the butterfly below the flower within two seconds"):
		return
	level.reset_level()
	level.begin_drag(horn, level.slot_center(horn))
	level.move_drag(Vector2(615, 130))
	level.finish_drag()
	level.butterfly.position = horn.to_global(horn.get_meta("mouth")) + Vector2(0, 50)
	var origin: Vector2 = level.butterfly.position
	level.start_level()
	level.try_horn(&"horn2")
	for frame in range(45):
		await physics_frame
	if not require(level.butterfly.position.y - origin.y > 250.0, "Second horn's free gust must retain enough downward momentum"):
		return
	level.reset_level()
	level.queue_free()
	await process_frame
	print("PASS: second horn range, travel speed and sustained free gust")
	quit(0)
