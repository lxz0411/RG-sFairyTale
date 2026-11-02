extends Node2D
## Only interaction/state lives here. All scenery and UI nodes live in the .tscn.

var inventory: Dictionary = {}
var dragged_pickup: Button
var pickup_homes: Dictionary = {}

@onready var pickups: Node2D = $Room/Pickups
@onready var slots: VBoxContainer = $HUD/Backpack/Slots

func _ready() -> void:
	for pickup in pickups.get_children():
		pickup_homes[pickup] = pickup.position
		pickup.collected.connect(_on_pickup_collected)
	$HUD/Reset.pressed.connect(_reset)

func _on_pickup_collected(pickup: Button) -> void:
	if inventory.has(pickup.item_id) or inventory.size() >= slots.get_child_count():
		return
	inventory[pickup.item_id] = {
		"name": pickup.item_name,
		"description": pickup.item_description,
		"icon": pickup.item_icon,
	}
	var slot: Panel = slots.get_child(inventory.size() - 1)
	slot.get_node("Icon").texture = pickup.item_icon
	pickup.mark_collected()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_inventory_drag(event.position)
		elif dragged_pickup != null:
			move_inventory_drag(event.position)
			finish_inventory_drag()
	elif event is InputEventMouseMotion and dragged_pickup != null:
		move_inventory_drag(event.position)

func begin_inventory_drag(point: Vector2) -> void:
	var ids := inventory.keys()
	for index in range(ids.size()):
		if slots.get_child(index).get_global_rect().has_point(point):
			for pickup in pickups.get_children():
				if pickup.item_id == ids[index]:
					dragged_pickup = pickup
					pickup.show()
					slots.get_child(index).get_node("Icon").hide()
					move_inventory_drag(point)
					return

func move_inventory_drag(point: Vector2) -> void:
	if dragged_pickup != null:
		var half: Vector2 = dragged_pickup.size * dragged_pickup.get_global_transform().get_scale() * 0.5
		dragged_pickup.global_position = point.clamp(Vector2(40, 35) + half, Vector2(1240, 800) - half) - half

func finish_inventory_drag() -> void:
	var pickup := dragged_pickup
	var center: Vector2 = pickup.global_position + pickup.size * pickup.get_global_transform().get_scale() * 0.5
	if center.x < $HUD/Backpack.get_global_rect().position.x - 20.0:
		inventory.erase(pickup.item_id)
		var half: Vector2 = pickup.size * pickup.get_global_transform().get_scale() * 0.5
		pickup.global_position = center.clamp(Vector2(40, 35) + half, Vector2(1120, 760) - half) - half
		pickup.reset()
	else:
		pickup.mark_collected()
	dragged_pickup = null
	refresh_inventory()

func refresh_inventory() -> void:
	var items := inventory.values()
	for index in range(slots.get_child_count()):
		var icon: TextureRect = slots.get_child(index).get_node("Icon")
		icon.show()
		icon.texture = items[index]["icon"] if index < items.size() else null

func _reset() -> void:
	dragged_pickup = null
	inventory.clear()
	for pickup in pickups.get_children():
		pickup.position = pickup_homes[pickup]
		pickup.reset()
	refresh_inventory()
