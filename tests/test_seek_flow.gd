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
