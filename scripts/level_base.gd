extends Node2D
## Common inventory, UI and reset flow. Levels only reset their own simulation.

@onready var backpack = $Inventory
@onready var play_texture: Texture2D = $PlayIcon.texture
@onready var reset_texture: Texture2D = $ResetIcon.texture
var play_selected := preload("res://assets/tutorial/final/play_selected.png")
var reset_selected := preload("res://assets/tutorial/final/reset_selected.png")
var inventory: Array[Sprite2D]:
	get:
		return backpack.stored_items()

func slot_center(item: Sprite2D) -> Vector2:
	return backpack.slot_center(item)

func collect_item(item: Sprite2D) -> bool:
	if not can_edit() or $Transition.visible or not backpack.collect(item):
		return false
	$PickupSound.play()
	return true

func icon_hit(icon: Sprite2D, point: Vector2) -> bool:
	return icon.get_rect().grow(5).has_point(icon.to_local(to_global(point)))

func handle_level_input(event: InputEvent) -> bool:
	if not $Transition.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			return handle_level_press(event.position)
		$ResetIcon.texture = reset_texture
	return false

func handle_level_press(point: Vector2) -> bool:
	if $Transition.visible:
		return false
	if icon_hit($ResetIcon, point):
		reset_level()
		$ResetIcon.texture = reset_selected
		return true
	if icon_hit($PlayIcon, point):
		if allows_start(point):
			start_level()
		return true
	return false

func reset_level() -> void:
	$Transition.cancel()
	stop_level_activity()
	backpack.recall_all()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	$PlayIcon.texture = play_texture
	$ResetIcon.texture = reset_texture
	reset_simulation()

func can_edit() -> bool:
	return false

func allows_start(_point: Vector2) -> bool:
	return true

func start_level() -> void:
	pass

func stop_level_activity() -> void:
	pass

func reset_simulation() -> void:
	pass
