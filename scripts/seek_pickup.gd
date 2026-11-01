extends Button
## Place this button in the scene and configure the item in the Inspector.

signal collected(pickup: Button)

@export var item_id: StringName
@export var item_name: String
@export var item_description: String
@export var item_icon: Texture2D

var is_collected := false

func _ready() -> void:
	pressed.connect(_collect)

func _collect() -> void:
	if is_collected:
		return
	collected.emit(self)

func mark_collected() -> void:
	is_collected = true
	disabled = true
	hide()

func reset() -> void:
	is_collected = false
	disabled = false
	modulate = Color.WHITE
	show()
