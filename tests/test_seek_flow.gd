extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://test_seek.tscn"):
		push_error("Missing test_seek.tscn: pickup-to-inventory flow is not implemented")
		quit(1)
		return
	var scene = load("res://test_seek.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var slots = scene.get_node("HUD/Backpack/Slots")
	assert(slots.get_child_count() == 5)
	for index in range(5):
		assert(slots.get_child(index).size == Vector2(84, 84))
		assert(is_equal_approx(slots.get_child(index).position.y, index * 159.0))
	assert(is_equal_approx(slots.get_child(4).get_global_rect().end.y, 760.0))
	assert(scene.get_node("HUD/Reset").position == Vector2(56, 48))
	assert(scene.inventory.is_empty(), "Backpack must start empty")
	var pickups = scene.get_node("Room/Pickups").get_children()
	for pickup in pickups:
		pickup.pressed.emit()
		assert(not pickup.visible, "Collected object must leave the room")
		assert(scene.inventory.has(pickup.item_id), "Collected object must enter backpack")
		var count: int = scene.inventory.size()
		pickup.pressed.emit()
		assert(scene.inventory.size() == count, "Repeated pickup must not duplicate items")
	assert(scene.inventory.size() == 3, "All three objects must be collectible")
	assert(scene.get_node("HUD/Backpack/Slots/Slot1/Icon").texture != null)
	assert(scene.get_node("HUD/Backpack/Slots/Slot3/Icon").texture != null)
	if "--visual-check" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		root.get_texture().get_image().save_png("user://screenshots/test_seek_inventory.png")
	var first_id = pickups[0].item_id
	var first_slot = scene.get_node("HUD/Backpack/Slots/Slot1")
	assert(first_slot.size == Vector2(84, 84))
	if "--visual-check" in OS.get_cmdline_user_args():
		_pointer(first_slot.get_global_rect().get_center(), true)
		await process_frame
	else:
		scene.begin_inventory_drag(first_slot.get_global_rect().get_center())
	assert(pickups[0].visible and not first_slot.get_node("Icon").visible)
	if "--visual-check" in OS.get_cmdline_user_args():
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(550, 350)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		_pointer(Vector2(550, 350), false)
		await process_frame
	else:
		scene.move_inventory_drag(Vector2(550, 350))
		scene.finish_inventory_drag()
	assert(not scene.inventory.has(first_id) and not pickups[0].disabled)
	assert(pickups[0].size == Vector2(76, 76))
	pickups[0].pressed.emit()
	assert(scene.inventory.size() == 3)
	scene.get_node("HUD/Reset").pressed.emit()
	assert(scene.inventory.is_empty(), "Reset must empty the backpack")
	for pickup in pickups:
		assert(pickup.visible and not pickup.disabled, "Reset must restore every pickup")
	pickups[0].pressed.emit()
	assert(scene.inventory.size() == 1, "Pickup must still work after reset")
	print("PASS: empty backpack, three pickups, duplicate prevention, UI, reset, recollection")
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
