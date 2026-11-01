extends Node2D
## Only interaction/state lives here. All scenery and UI nodes live in the .tscn.

var inventory: Dictionary = {}

@onready var pickups: Node2D = $Room/Pickups
@onready var slots: HBoxContainer = $HUD/Backpack/Slots

func _ready() -> void:
	for pickup in pickups.get_children():
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

func _reset() -> void:
	inventory.clear()
	for pickup in pickups.get_children():
		pickup.reset()
	for slot in slots.get_children():
		slot.get_node("Icon").texture = null
