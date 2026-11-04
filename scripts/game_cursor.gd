extends Node

const CURSOR_TEXTURE := preload("res://assets/tutorial/final/cursor.png")
const HOTSPOT := Vector2(11, 3)

func _ready() -> void:
	# Keep the same artwork when buttons and pickable objects request a hand cursor.
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(CURSOR_TEXTURE, Input.CURSOR_POINTING_HAND, HOTSPOT)

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
