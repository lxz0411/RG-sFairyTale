extends SceneTree
var level
var errors := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
func place(item_name: String, point: Vector2, angle: float) -> void:
	var item = level.get_node(item_name)
	if not item.collected: level.collect_item(item)
	level.begin_drag(item, level.slot_center(item))
	item.position = point
	level.finish_drag()
	level.selected = item
	level.rotate_item(angle-item.rotation)
func simulate() -> Dictionary:
	var seen := {"seated":false, "fork":false, "lever":false, "launch":false, "mouth":false, "outlet":false, "complete":false}
	level.start_level()
	for tick in range(1500):
		await physics_frame
		seen.seated = seen.seated or level.key_seated
		seen.fork = seen.fork or level.ball_on_fork
		seen.lever = seen.lever or level.lever_loaded
		seen.launch = seen.launch or level.key_launched
		seen.mouth = seen.mouth or level.funnel_entered
		seen.outlet = seen.outlet or level.funnel_exited
		if level.phase == level.Phase.COMPLETE:
			seen.complete = true
			break
		if level.phase == level.Phase.EDIT: break
	return seen

func screenshot(file_name: String) -> void:
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + file_name + ".png")

func run() -> void:
	var progress = root.get_node("GameProgress")
	progress.save_path = "res://.godot/level4_test_progress.cfg"
	progress.completed.clear()
	level = load("res://scenes/level_4.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.next_level_scene = ""
	level.get_node("Transition").cancel()
	check(level.items.size()==2, "Only fork and funnel are movable")
	check(level.find_children("*", "Label", true, false).is_empty(), "No text in level")
	await screenshot("level4_initial")
	place("Fork", Vector2(400,400), 1.7)
	level.rotate_item(TAU)
	check(is_equal_approx(level.get_node("Fork").rotation,1.7), "Full 360 degree rotation")
	check(level.get_node("Fork").position == Vector2(400,400), "Free placement without snapping")
	level.backpack.store(level.get_node("Fork"))
	place("Funnel", Vector2(580,170), -2.596)
	var no_fork := await simulate()
	print("NO FORK ",no_fork)
	check(no_fork.seated and not no_fork.lever and not no_fork.complete, "Without fork key waits on blade and ball misses lever")
	check(not progress.is_completed(4), "Failure cannot record progress")
	level.reset_level()
	place("Fork", Vector2(940,475), PI+0.2)
	level.backpack.store(level.get_node("Funnel"))
	var no_funnel := await simulate()
	print("NO FUNNEL ",no_funnel)
	check(no_funnel.fork and no_funnel.lever and no_funnel.launch and not no_funnel.complete, "Fork and lever work but absent funnel cannot unlock")
	level.reset_level()
	place("Funnel", Vector2(390,170), -2.596)
	var wrong := await simulate()
	check(wrong.launch and not wrong.complete, "Misplaced funnel cannot unlock cabinet")
	level.reset_level()
	place("Funnel", Vector2(580,170), -2.596)
	var fork_pose: Transform2D = level.get_node("Fork").transform
	var funnel_pose: Transform2D = level.get_node("Funnel").transform
	await screenshot("level4_solution")
	var success := await simulate()
	print("CHAIN ",success)
	check(success.seated and success.fork and success.lever and success.launch and success.mouth and success.outlet and success.complete, "Full physical chain completes through funnel mouth and outlet")
	check(progress.is_completed(4) and not progress.is_completed(3), "Only fourth level progress is recorded")
	check(level.get_node("Seed").visible and level.get_node("Cabinet").frame == 1, "Open frame and seed are visible")
	await screenshot("level4_result")
	level.reset_level()
	check(level.get_node("Fork").transform == fork_pose and level.get_node("Funnel").transform == funnel_pose, "Retry preserves both placed transforms")
	check(level.get_node("Cabinet").frame == 0 and not level.get_node("Seed").visible and level.physics_root == null, "Reset restores cabinet, seed and physics")
	level.start_level()
	await physics_frame
	level.reset_level()
	for tick in range(30): await physics_frame
	check(level.phase == level.Phase.EDIT and not level.key_launched, "Reset cancels in-flight actions")
	# A nearby alternative layout must work too; the result is not a pose lookup.
	place("Funnel", Vector2(588,170), -2.596)
	var alternative := await simulate()
	check(alternative.complete, "Nearby alternative placement also succeeds")
	level.return_to_level_select()
	await process_frame
	await process_frame
	check(current_scene.get_node("Level4").completed, "Selection screen shows saved level 4 completion")
	current_scene.get_node("Transition").cancel()
	current_scene._on_reset_progress_pressed()
	check(not current_scene.get_node("Level4").completed, "Clear progress refreshes level 4")
	# Exercise the actual menu signal and transition, not just the scene resource.
	current_scene.get_node("Level4/Door").pressed.emit()
	await current_scene.get_node("Transition").covered
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://scenes/level_4.tscn", "Fourth door opens the fourth scene")
	check(current_scene.phase == current_scene.Phase.EDIT, "Re-entry starts a fresh editable puzzle")
	current_scene.get_node("Transition").cancel()
	current_scene.get_node("MenuLink/Button").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://scenes/level_select.tscn", "Level return button opens selection")
	current_scene.queue_free()
	await process_frame
	await physics_frame
	DirAccess.remove_absolute("res://.godot/level4_test_progress.cfg")
	# Let MP3 playback release before the accelerated headless runner exits.
	root.get_node("GameAudio").stop()
	await process_frame
	await process_frame
	print("Level 4 flow: ",errors," failures")
	quit(1 if errors else 0)
