extends SceneTree
var level
var errors := 0
var progress
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
func place(name: String, point: Vector2, angle: float = 0.0) -> void:
	var item = level.get_node(name)
	if not item.collected: level.collect_item(item)
	level.begin_drag(item,level.slot_center(item))
	item.position = point
	level.finish_drag()
	level.selected = item
	level.rotate_item(angle-item.rotation)
func simulate(limit: int = 4000) -> Dictionary:
	var seen := {"book":false,"cap":false,"frame":false,"weight":false,"early_weight":false,"complete":false}
	level.start_level()
	for tick in range(limit):
		await physics_frame
		seen.book = seen.book or level.book_released
		seen.cap = seen.cap or level.upper_loaded
		seen.frame = seen.frame or level.frame_drop > 54
		seen.weight = seen.weight or level.lower_angle > -0.01
		seen.early_weight = seen.early_weight or (level.lower_angle > -0.01 and not level.book_released)
		if level.phase == level.Phase.COMPLETE:
			seen.complete = true
			break
		if level.phase != level.Phase.RUN:
			print("STOP ",level.ball.position if is_instance_valid(level.ball) else Vector2.ZERO," ",seen)
			break
	return seen
func run() -> void:
	progress = root.get_node("GameProgress")
	progress.save_path = "res://.godot/level3_test_progress.cfg"
	progress.completed.clear()
	level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("Transition").cancel()
	level.next_level_scene = ""
	check(level.items.size()==2,"Only clock and bottle are removable")
	check(level.item_at(Vector2(835,165)) == null,"Book is fixed machinery, not a collectible")
	check(not level.has_node("Spoon") and not level.has_node("Books"),"No spoon or four-book puzzle remains")
	check(level.find_children("*","Label",true,false).is_empty(),"No text UI")
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level3_confirmed_initial.png")
	var no_clock := await simulate()
	check(not no_clock.book and not no_clock.complete,"Lower channel cannot push the book or complete")
	level.reset_level()
	place("Weight",Vector2(1043,411))
	var bottle_only := await simulate()
	check(bottle_only.early_weight and not bottle_only.book,"Bottle acts under gravity without the upstream trigger")
	level.reset_level()
	level.backpack.store(level.get_node("Weight"))
	place("Clock",Vector2(280,113),-2.4)
	var no_bottle := await simulate()
	check(no_bottle.book and no_bottle.cap and no_bottle.frame,"Clock enables book, apple pressure and frame chain")
	check(not no_bottle.weight and not no_bottle.complete,"Missing counterweight leaves final connection incomplete")
	level.reset_level()
	place("Weight",Vector2(1043,411))
	var clock_home: Transform2D = level.get_node("Clock").transform
	var bottle_home: Transform2D = level.get_node("Weight").transform
	var success := await simulate()
	print("CHAIN ",success)
	check(success.book and success.cap and success.frame and success.early_weight and success.complete,"Full confirmed chain reaches plate")
	check(level.get_node("Gentleman").saluting,"Apple settling in the plate triggers the gentleman's salute")
	check(progress.is_completed(3) and not progress.is_completed(1),"Completion records only level 3")
	check(level.settled_time >= 0.55,"Fruit must settle in the plate, not merely cross the area")
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/level3_confirmed_complete.png")
	level.reset_level()
	check(level.get_node("Clock").transform == clock_home and level.get_node("Weight").transform == bottle_home,"Reset retains player placement and orientation")
	check(level.get_node("Frame").position.y==354 and level.get_node("Book").rotation==0,"Reset restores initial machinery")
	check(level.lower_angle == -0.65 and level.upper_angle==0 and level.physics_root==null,"Reset clears mechanical and physics state")
	level.start_level()
	await physics_frame
	level.reset_level()
	for i in range(60): await physics_frame
	check(level.phase==level.Phase.EDIT and level.frame_drop==0,"Reset cancels active simulation")
	level.return_to_level_select()
	await process_frame
	await process_frame
	check(current_scene.get_node("Level3").completed,"Menu retains completion")
	current_scene.get_node("Transition").cancel()
	current_scene._on_reset_progress_pressed()
	check(not current_scene.get_node("Level3").completed,"Clear progress refreshes level 3")
	current_scene.queue_free()
	await process_frame
	await physics_frame
	DirAccess.remove_absolute("res://.godot/level3_test_progress.cfg")
	print("Level 3 confirmed chain: ",errors," failures")
	quit(1 if errors else 0)
