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
		root.get_texture().get_image().save_png("user://screenshots/level3_salute_%s.png" % name)

func run() -> void:
	root.get_node("GameProgress").save_path = "user://tests/level3_salute.cfg"
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.next_level_scene = ""
	level.get_node("Transition").cancel()
	# Fixed-fps headless runs finish before the real-time audio thread drains.
	if DisplayServer.get_name() == "headless":
		level.get_node("CompleteSound").stream = null
	if not require(level.has_node("Gentleman/Pose"), "The salute must use full-character animation frames"):
		return
	var actor = level.get_node("Gentleman")
	var pose: AnimatedSprite2D = actor.get_node("Pose")
	if not require(pose.sprite_frames.get_frame_count("salute") == 8 and pose.frame == 0 and not pose.is_playing(), "Idle must hold the first of eight complete character poses"):
		return
	pose.frame_changed.connect(func(): snapshot("frame_%02d" % pose.frame))
	await snapshot("idle")
	await snapshot("frame_00")
	level.start_level()
	await physics_frame
	if not require(not actor.saluting, "Starting a level must not trigger the salute"):
		return
	level.pass_level()
	if not require(actor.saluting, "Level completion must start the salute"):
		return
	await create_timer(1.7).timeout
	if not require(pose.frame == 7 and not pose.is_playing(), "The complete salute sequence must end on its final held pose"):
		return
	if not require(not level.get_node("Transition").visible, "The salute must remain visible before the exit transition"):
		return
	await snapshot("raised")
	await actor.salute_finished
	var held_pose := pose.frame
	await create_timer(0.4).timeout
	if not require(pose.frame == held_pose and not pose.is_playing(), "The raised-hat pose must remain held and never return to the idle frame automatically"):
		return
	level.reset_level()
	if not require(pose.frame == 0 and not pose.is_playing() and not actor.saluting, "Reset must restore the original worn-hat frame"):
		return
	level.start_level()
	level.pass_level()
	await create_timer(0.4).timeout
	level.reset_level()
	await create_timer(2.8).timeout
	if not require(level.phase == level.Phase.EDIT and pose.frame == 0 and not pose.is_playing() and not level.get_node("Transition").visible, "Reset during the salute must cancel every pending frame and transition"):
		return
	level.next_level_scene = "res://scenes/level_select.tscn"
	level.start_level()
	level.pass_level()
	await actor.salute_finished
	await process_frame
	if not require(level.get_node("Transition").visible, "The exit transition must wait for the salute to finish"):
		return
	await level.get_node("Transition").covered
	await process_frame
	await process_frame
	if not require(current_scene.scene_file_path == "res://scenes/level_select.tscn", "Completion must still return to level selection"):
		return
	current_scene.queue_free()
	await process_frame
	await physics_frame
	print("PASS: eight full-character frames, success-only playback, held final pose, reset cancellation and delayed exit")
	quit()
