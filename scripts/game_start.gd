extends Control

@export_file("*.tscn") var next_scene := "res://scenes/level_select.tscn"
@export var open_texture: Texture2D
@export_range(0.1, 3.0, 0.05) var open_hold_duration := 0.55
@export_range(-90.0, 90.0, 1.0) var gear_speed_degrees := 26.0
var opening := false
var idle_glow: Tween
var gear_angle := 0.0
var ambient_time := 0.0

@onready var large_gear: Sprite2D = $Mechanism/LargeGear
@onready var small_gear: Sprite2D = $Mechanism/SmallGear
@onready var butterfly_origin: Vector2 = $Butterfly.position

func _ready() -> void:
	_update_mechanism()
	idle_glow = create_tween().set_loops()
	idle_glow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_glow.tween_property($DoorGlow.material, "shader_parameter/hover_amount", 1.0, 1.3)
	idle_glow.tween_property($DoorGlow.material, "shader_parameter/hover_amount", 0.65, 1.3)

func _process(delta: float) -> void:
	gear_angle += deg_to_rad(gear_speed_degrees) * delta
	_update_mechanism()
	ambient_time += delta
	$Butterfly.position = butterfly_origin + Vector2(0, sin(ambient_time * 1.7) * 4.0)
	$Traveler/Scarf.material.set_shader_parameter("wave_time", ambient_time)

func _update_mechanism() -> void:
	large_gear.rotation = gear_angle
	# Twelve teeth drive eight teeth in the opposite direction.
	small_gear.rotation = -gear_angle * 1.5
	$Mechanism/TitleGear.rotation = -gear_angle * 0.7
	# The illustrated rod caps are centered axles, not eccentric crank pins.
	_place_rod($Mechanism/ShortRod, large_gear.position, small_gear.position, Vector2(42, 49), Vector2(224, 53))
	_place_rod($Mechanism/LongRod, small_gear.position, Vector2(552, 594), Vector2(32, 71), Vector2(352, 42))

func _place_rod(rod: Sprite2D, from: Vector2, to: Vector2, local_from: Vector2, local_to: Vector2) -> void:
	var rod_scale := from.distance_to(to) / local_from.distance_to(local_to)
	rod.rotation = (to - from).angle() - (local_to - local_from).angle()
	rod.scale = Vector2.ONE * rod_scale
	rod.position = from - local_from.rotated(rod.rotation) * rod_scale

func _on_door_pressed() -> void:
	if opening or $Transition.visible:
		return
	opening = true
	idle_glow.kill()
	$DoorGlow.hide()
	$Door.texture_normal = open_texture
	$Door.texture_disabled = open_texture
	$Door.disabled = true
	var entrance := create_tween()
	entrance.tween_interval(open_hold_duration)
	entrance.tween_callback($Transition.play_exit)

func _on_transition_covered() -> void:
	if opening:
		get_tree().change_scene_to_file(next_scene)
