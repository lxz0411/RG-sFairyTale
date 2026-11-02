extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://test_physics.tscn"):
		push_error("Missing physics sandbox scene")
		quit(1)
		return
	var scene = load("res://test_physics.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var slots = scene.get_node("HUD/Backpack/Slots")
	assert(slots.get_child_count() == 5)
	for index in range(5):
		assert(slots.get_child(index).size == Vector2(84, 84))
		assert(is_equal_approx(slots.get_child(index).position.y, index * 159.0))
	assert(is_equal_approx(slots.get_child(4).get_global_rect().end.y, 760.0))
	assert(scene.get_node("HUD/Reset").position == Vector2(56, 48))
	var board = scene.get_node("Items/Board1")
	var board2 = scene.get_node("Items/Board2")
	var ball = scene.get_node("Items/Ball")
	assert(board.collision_layer == 0 and board2.collision_layer == 0)
	assert(ball.freeze and ball.collision_layer == 0)
	if board.visible or board2.visible or ball.visible:
		push_error("Inventory must show icons, not full-size physics bodies")
		quit(1)
		return
	assert(scene.get_node("HUD/Backpack/Slots/Slot1").size == Vector2(84, 84))
	scene.begin_drag(board, board.position)
	scene.move_drag(Vector2(570, 440))
	scene.rotate_board(deg_to_rad(15))
	scene.finish_drag()
	assert(board.visible and not scene.get_node("HUD/Backpack/Slots/Slot1/Icon").visible)
	assert(board.get_node("CollisionShape2D").shape.size == Vector2(240, 24))
	assert(board.collision_layer == 1)
	assert(is_equal_approx(board.rotation, deg_to_rad(15)))
	assert(board.scale == Vector2.ONE, "Dragging and rotation must preserve size")
	scene.begin_drag(board2, board2.position)
	scene.move_drag(Vector2(850, 550))
	scene.finish_drag()
	assert(board2.collision_layer == 1)
	await physics_frame
	await physics_frame
	scene.begin_drag(ball, ball.position)
	var release_point: Vector2 = board.to_global(Vector2(-75, -45))
	scene.move_drag(release_point)
	scene.finish_drag()
	assert(not ball.freeze and ball.collision_layer == 1)
	var touched_board := false
	for frame in range(90):
		await physics_frame
		if ball.get_colliding_bodies().has(board):
			touched_board = true
	assert(ball.continuous_cd == RigidBody2D.CCD_MODE_CAST_RAY)
	assert(touched_board, "Ball must collide with the plank")
	assert(ball.position.x > release_point.x + 35, "Gravity must move ball downhill")
	assert(absf(ball.angular_velocity) > 0.5, "Friction must produce rolling")
	for frame in range(120):
		await physics_frame
	assert(ball.position.y < 723, "Ball must not tunnel through the floor")
	scene.begin_drag(board, board.position)
	scene.move_drag(Vector2(1198, 82))
	scene.finish_drag()
	assert(not board.visible and scene.get_node("HUD/Backpack/Slots/Slot1/Icon").visible)
	assert(board.collision_layer == 0 and board.rotation == 0.0)
	# A single button press must remain effective after physics state synchronizes.
	await process_frame
	scene.get_node("HUD/Reset").pressed.emit()
	for frame in range(6):
		await physics_frame
		await process_frame
	if ball.position.distance_to(scene.home_positions[ball]) > 0.1:
		push_error("Single reset lost ball position after physics sync: %s" % ball.position)
		quit(1)
		return
	assert(ball.rotation == 0.0)
	assert(ball.linear_velocity == Vector2.ZERO and ball.angular_velocity == 0.0)
	assert(ball.freeze and ball.collision_layer == 0)
	assert(board2.collision_layer == 0)
	if "--visual-check" in OS.get_cmdline_user_args():
		await _check_pointer_controls(scene)
	print("PASS: inventory, both boards, drag, fixed size, rotation, slope collision, rolling, floor, return, reset")
	scene.queue_free()
	await process_frame
	quit(0)

func _pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)

func _drag(from: Vector2, to: Vector2) -> void:
	_pointer(from, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	_pointer(to, false)
	await process_frame

func _check_pointer_controls(scene: Node2D) -> void:
	scene.reset_items()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	root.get_texture().get_image().save_png("user://screenshots/test_physics_inventory.png")
	await _drag(Vector2(1198, 82), Vector2(570, 420))
	var board = scene.get_node("Items/Board1")
	assert(board.position.distance_to(Vector2(570, 420)) < 1.0)
	for step in range(3):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = Vector2(570, 420)
		root.push_input(wheel, true)
	assert(is_equal_approx(board.rotation, deg_to_rad(15)))
	await _drag(Vector2(1198, 241), Vector2(830, 535))
	await _drag(Vector2(1198, 400), Vector2(500, 335))
	for frame in range(55):
		await physics_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	root.get_texture().get_image().save_png("user://screenshots/test_physics_preview.png")
	# Click the actual reset button once while the ball is still rolling.
	_pointer(Vector2(82, 74), true)
	await process_frame
	_pointer(Vector2(82, 74), false)
	for frame in range(6):
		await physics_frame
		await process_frame
	var ball = scene.get_node("Items/Ball")
	assert(ball.position.distance_to(scene.home_positions[ball]) < 0.1,
		"One actual reset click must return the moving ball to inventory")
	assert(ball.freeze and ball.collision_layer == 0)
	assert(not ball.visible and scene.get_node("HUD/Backpack/Slots/Slot3/Icon").visible)
	print("PASS: pointer drag, wheel rotation, single-click reset after physics sync; preview saved")
