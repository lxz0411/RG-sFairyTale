extends Control

signal level_selected(scene_path: String)
@export var level_number := 0
# Display order is independent of the persistent completion ID.
@export var display_number := -1
@export_file("*.tscn") var level_scene: String
@export var complete_texture: Texture2D
var completed := false
var hover_tween: Tween
@onready var progress = get_node("/root/GameProgress")
@onready var normal_texture: Texture2D = $Door.texture_normal
@onready var hover_texture: Texture2D = $Door.texture_hover

func _ready() -> void:
	progress.changed.connect(refresh)
	refresh()

func refresh() -> void:
	$Number.text = str(display_number if display_number >= 0 else level_number)
	completed = progress.is_completed(level_number)
	$Door.texture_normal = complete_texture if completed else normal_texture
	$Door.texture_hover = complete_texture if completed else hover_texture
	$Door.texture_pressed = $Door.texture_hover

func _on_mouse_entered() -> void:
	set_hover(1.0)

func _on_mouse_exited() -> void:
	set_hover(0.0)

func set_hover(amount: float) -> void:
	if hover_tween != null:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property($Door.material, "shader_parameter/hover_amount", amount, 0.14)

func _on_pressed() -> void:
	level_selected.emit(level_scene)
