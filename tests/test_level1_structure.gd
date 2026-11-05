extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func run() -> void:
	var tutorial = load("res://scenes/tutorial_backdrop.tscn").instantiate()
	var level = load("res://scenes/level_1.tscn").instantiate()
	if not require(level.get_script().get_base_script().resource_path == "res://scripts/level_base.gd" and tutorial.get_script().get_base_script().resource_path == "res://scripts/level_base.gd", "Both levels must inherit common UI, inventory and reset behavior"):
		return
	for path in ["Background", "GoalStar", "GoalStar/Trigger", "Inventory", "ResetIcon", "PlayIcon", "PlaceSound", "PickupSound", "CompleteSound", "Transition"]:
		if not require(level.has_node(path) and level.get_node(path).get_class() == tutorial.get_node(path).get_class(), "Level and tutorial must share node structure: " + path):
			return
	if not require(not level.has_node("HUD") and not level.has_node("Items"), "UI and props must live directly under the level root, as in the tutorial"):
		return
	for id in ["Horn1", "Horn2", "Flower1", "Flower2"]:
		if not require(level.get_node(id) is Sprite2D, "Props must use tutorial-style Sprite2D nodes"):
			return
	if not require(level.get_node("Inventory").scene_file_path == tutorial.get_node("Inventory").scene_file_path and not level.get_node("Inventory").scene_file_path.is_empty(), "Both scenes must reuse the same inventory scene"):
		return
	if not require(level.get_node("GoalStar/Trigger").is_in_group("star"), "Star detection must use the tutorial's star group"):
		return
	for index in range(1, 6):
		if not require(level.has_node("Inventory/Icon%d" % index), "Inventory must contain five authored icon nodes"):
			return
	tutorial.free()
	level.next_level_scene = ""
	root.add_child(level)
	await level.get_node("Transition").revealed
	level.start_level()
	if not require(level.get_node("PlayIcon").texture.resource_path.ends_with("play_selected.png"), "Start must use the tutorial's selected button texture"):
		return
	level.reset_level()
	if not require(level.get_node("PlayIcon").texture.resource_path.ends_with("play.png"), "Reset must restore the start button texture"):
		return
	level.queue_free()
	await process_frame
	print("PASS: tutorial-compatible scene structure, shared five-slot inventory and button feedback")
	quit(0)
