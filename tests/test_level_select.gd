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
		root.get_texture().get_image().save_png("user://screenshots/level_select_%s.png" % name)

func run() -> void:
	if not require(ResourceLoader.exists("res://scenes/level_select.tscn"), "Missing level selection scene"):
		return
	var progress = root.get_node("GameProgress")
	progress.save_path = "user://tests/level_select_progress.cfg"
	progress.completed.clear()
	progress.save_progress()
	var menu = load("res://scenes/level_select.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await menu.get_node("Transition").revealed
	var zero = menu.get_node("Level0")
	var one = menu.get_node("Level1")
	if not require(zero.get_node("Number").text == "0" and one.get_node("Number").text == "1", "Labels beneath the doors must follow their own level numbers"):
		return
	if not require(zero.get_node("Door").size.x <= 180 and one.get_node("Door").size.x <= 180, "Doors must leave room for four columns of levels"):
		return
	if not require(not zero.completed and not one.completed, "Fresh save must not show fake completions"):
		return
	await snapshot("normal")
	zero.get_node("Door").mouse_entered.emit()
	await create_timer(0.2).timeout
	if not require(float(zero.get_node("Door").material.get_shader_parameter("hover_amount")) > 0.95, "Hover must show a gold halo around the whole silhouette"):
		return
	await snapshot("hover")
	zero.get_node("Door").mouse_exited.emit()
	for path in ["res://scenes/tutorial_backdrop.tscn", "res://scenes/level_1.tscn"]:
		var level = load(path).instantiate()
		level.next_level_scene = ""
		root.add_child(level)
		level.get_node("Transition").cancel()
		if not require(not progress.is_completed(level.level_number), "Entering a level must not mark it complete"):
			return
		level.pass_level()
		if not require(zero.get_node("Number").text == "0" and one.get_node("Number").text == "1", "Completion must never change either level number"):
			return
		if level.level_number == 0 and not require(zero.completed and not one.completed, "Completing tutorial must not mark level 1 complete"):
			return
		if not require(progress.is_completed(level.level_number), "The real pass_level event must persist completion"):
			return
		level.reset_level()
		if not require(progress.is_completed(level.level_number), "Reset must not erase earned progress"):
			return
		level.queue_free()
		await process_frame
	progress.completed.clear()
	progress.load_progress()
	if not require(progress.is_completed(0) and progress.is_completed(1) and zero.completed and one.completed, "Progress must survive reload and refresh the door states"):
		return
	zero.get_node("Door").mouse_entered.emit()
	await create_timer(0.2).timeout
	await snapshot("complete")
	for number in [0, 1]:
		menu = current_scene
		var button = menu.get_node("Level%d/Door" % number)
		click(button.get_global_rect().get_center())
		await menu.get_node("Transition").covered
		await process_frame
		await process_frame
		if not require(current_scene.has_node("Traveler" if number == 0 else "Butterfly"), "Door must open the actual corresponding level"):
			return
		await current_scene.get_node("Transition").revealed
		if not require(current_scene.get_node("MenuLink/Button") is TextureButton, "Levels must share the hand-painted return button"):
			return
		await snapshot("return_%d" % number)
		click(Vector2(228, 48))
		await process_frame
		await process_frame
		if not require(current_scene.scene_file_path == "res://scenes/level_select.tscn", "Shared menu button must return to selection"):
			return
		await current_scene.get_node("Transition").revealed
		if not require(current_scene.get_node("Level0/Number").text == "0" and current_scene.get_node("Level1/Number").text == "1", "Returning from either level must keep 0/1 labels distinct"):
			return
	if not require(current_scene.has_node("ResetProgress"), "Selection needs a reset-progress button"):
		return
	var reset: TextureButton = current_scene.get_node("ResetProgress")
	if not require(reset.texture_normal.resource_path.ends_with("reset.png") and reset.texture_pressed.resource_path.ends_with("reset_selected.png"), "Progress reset must use the supplied UI textures"):
		return
	progress.complete_level(7)
	click(reset.get_global_rect().get_center())
	if not require(progress.completed.is_empty() and not current_scene.get_node("Level0").completed and not current_scene.get_node("Level1").completed, "One click must clear every completion and refresh both doors"):
		return
	progress.load_progress()
	if not require(progress.completed.is_empty(), "Cleared progress must persist after reloading the save"):
		return
	click(reset.get_global_rect().get_center())
	if not require(current_scene.get_node("Level0/Number").text == "0" and current_scene.get_node("Level1/Number").text == "1", "Clearing progress must preserve the level numbers"):
		return
	current_scene.queue_free()
	await process_frame
	print("PASS: 0/1 selection, golden hover halo, real completion/persistence, return navigation and one-click persistent reset of all progress")
	quit(0)
