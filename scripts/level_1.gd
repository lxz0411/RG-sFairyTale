extends "res://scripts/level_base.gd"

signal star_obtained
signal level_passed

@export_file("*.tscn") var next_level_scene := "res://scenes/level_1.tscn"
@export var flight_speed := 105.0
@export var flower_rest_duration := 1.6
@export var petal_flight_duration := 2.8
@export var horn_trigger_radius := 105.0
@export var wind_reach := 500.0
@export_range(1.0, 89.0) var wind_cone_degrees := 55.0
@export_group("Second Horn")
@export var second_horn_wind_reach := 850.0
@export var second_horn_wind_speed := 320.0
@export var second_horn_impulse := 560.0
@export var second_horn_gust_duration := 1.0

enum Phase { EDIT, FLY, FAILED, COMPLETE }
enum FlightStage { ASCEND_FIRST, BLOW_FIRST, REST_PLATE, ASCEND_SECOND, BLOW_SECOND, APPROACH_VASE, PERCHED, FREE }
var phase := Phase.EDIT
var flight_stage := FlightStage.ASCEND_FIRST
var items: Array[Node] = []
var dragged: Node2D
var selected: Node2D
var rotating := false
var rotation_offset := 0.0
var grab_offset := Vector2.ZERO
var original_transform := Transform2D.IDENTITY
var original_inventory := false
var flight_tween: Tween
var effects: Array[Tween] = []
var rest_time := 0.0
var free_velocity := Vector2.ZERO
var gust_remaining := 0.0
var star_collected := false
var horn_blow_count := 0
var used_horns: Array[StringName] = []
@onready var butterfly: Node2D = $Butterfly
@onready var wings: AnimatedSprite2D = $Butterfly/Wings
@onready var star: Sprite2D = $GoalStar
@onready var small_horn_sound: AudioStream = $HornSound.stream
@onready var petal_home: Transform2D = $GoldenPetal.transform
var star_texture := preload("res://assets/tutorial/final/star.png")
var complete_star := preload("res://assets/tutorial/final/star_complete.png")
var low_horn_sound := preload("res://assets/level1/horn_low.wav")

func _ready() -> void:
	items = [$Horn1, $Horn2, $Flower1, $Flower2]
	wings.play("fly")
	backpack.refresh()

func _on_wings_frame_changed() -> void:
	var sprite: AnimatedSprite2D = $Butterfly/Wings
	var widths := [1.0, 0.72, 1.0, 0.72]
	sprite.scale = Vector2(widths[sprite.frame] if sprite.animation == &"fly" else 1.0, 1.0)

func item_by_id(id: StringName) -> Node2D:
	for item in items:
		if item.item_id == id:
			return item
	return null

func item_at(point: Vector2) -> Node2D:
	var stored: Sprite2D = backpack.item_at(point)
	if stored != null:
		return stored
	for index in range(items.size() - 1, -1, -1):
		if items[index].visible and items[index].hit(point):
			return items[index]
	return null

func _process(delta: float) -> void:
	if phase == Phase.EDIT and not $Transition.visible and selected != null:
		var direction := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		rotate_item(direction * delta * 1.5)
	var point := get_local_mouse_position()
	var over_button := icon_hit($ResetIcon, point) or icon_hit($PlayIcon, point)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not $Transition.visible and (over_button or item_at(point) != null) else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if handle_level_input(event):
		return
	if $Transition.visible:
		return
	if event is InputEventMouseButton:
		var point: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if phase == Phase.EDIT:
					var item := item_at(point)
					if item == null:
						selected = null
					elif not item.collected:
						collect_item(item)
					else:
						begin_drag(item, point)
			else:
				if dragged != null:
					move_drag(point)
					finish_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and phase == Phase.EDIT:
				var item := item_at(point)
				if item != null and item.visible and item.collected:
					selected = item
					rotating = true
					rotation_offset = (point - item.position).angle() - item.rotation
			else:
				rotating = false
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_item(deg_to_rad(-5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 5))
	elif event is InputEventMouseMotion:
		if rotating and selected != null:
			rotate_item((event.position - selected.position).angle() - rotation_offset - selected.rotation)
		elif dragged != null:
			move_drag(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and dragged != null:
		dragged.transform = original_transform
		if original_inventory:
			backpack.store(dragged)
		else:
			backpack.deploy(dragged)
		dragged = null
		rotating = false

func begin_drag(item: Node2D, point: Vector2) -> void:
	if phase != Phase.EDIT or $Transition.visible:
		return
	dragged = item
	selected = item
	rotating = false
	original_transform = item.transform
	original_inventory = backpack.is_stored(item)
	if original_inventory:
		item.position = point
	grab_offset = item.position - point
	backpack.begin_drag(item)

func move_drag(point: Vector2) -> void:
	if dragged != null:
		dragged.position = (point + grab_offset).clamp(Vector2(20, 20), Vector2(1260, 780))

func finish_drag() -> void:
	if dragged == null:
		return
	if dragged.position.x >= 1111:
		backpack.store(dragged)
	else:
		backpack.deploy(dragged)
		$PlaceSound.play()
	dragged = null

func rotate_item(angle: float) -> void:
	if phase == Phase.EDIT and selected != null and selected.visible:
		selected.rotation = wrapf(selected.rotation + angle, -PI, PI)

func can_edit() -> bool:
	return phase == Phase.EDIT

func start_level() -> void:
	if phase != Phase.EDIT or dragged != null or rotating or $Transition.visible:
		return
	phase = Phase.FLY
	flight_stage = FlightStage.ASCEND_FIRST
	selected = null
	wings.play("fly")
	$PlayIcon.texture = play_selected

func _physics_process(delta: float) -> void:
	if phase != Phase.FLY:
		return
	match flight_stage:
		FlightStage.ASCEND_FIRST:
			butterfly.position.y -= flight_speed * delta
			try_horn(&"horn1")
		FlightStage.ASCEND_SECOND:
			butterfly.position += Vector2(55, -flight_speed) * delta
			try_horn(&"horn2")
		FlightStage.REST_PLATE:
			rest_time -= delta
			if rest_time <= 0.0:
				wings.play("fly")
				flight_stage = FlightStage.ASCEND_SECOND
		FlightStage.APPROACH_VASE:
			if item_by_id(&"flower1").deployed:
				fly_to(item_by_id(&"flower1").to_global(Vector2(-21, -75)), Vector2(-30, -90), 1.8, FlightStage.PERCHED)
			else:
				flight_stage = FlightStage.FREE
				free_velocity = Vector2(45, -flight_speed)
		FlightStage.FREE:
			if gust_remaining > 0.0:
				gust_remaining = maxf(gust_remaining - delta, 0.0)
			else:
				free_velocity = free_velocity.lerp(Vector2(0, -flight_speed), delta * 0.6)
			butterfly.position += free_velocity * delta
	if butterfly.position.y < -100 or butterfly.position.x < -100 or butterfly.position.x > 1220 or butterfly.position.y > 900:
		phase = Phase.FAILED
		butterfly.hide()
		$PlayIcon.texture = play_texture

func try_horn(id: StringName) -> void:
	var horn := item_by_id(id)
	if not horn.deployed or used_horns.has(id):
		return
	var mouth: Vector2 = horn.to_global(horn.get_meta("mouth"))
	if butterfly.position.distance_to(mouth) > horn_trigger_radius:
		return
	used_horns.append(id)
	blow_horn(horn)
	var local_direction := Vector2(1, 0.5) if id == &"horn1" else Vector2.DOWN
	var direction := local_direction.normalized().rotated(horn.rotation)
	var flower := item_by_id(&"flower2" if id == &"horn1" else &"flower1")
	var offset := Vector2(-10, -45) if id == &"horn1" else Vector2(-81, 105)
	var destination := flower.to_global(offset)
	var displacement := destination - butterfly.position
	var reach := second_horn_wind_reach if id == &"horn2" else wind_reach
	var speed := second_horn_wind_speed if id == &"horn2" else 160.0
	# 气流只依据实际朝向和距离，不检查道具是否位于某个预设区域。
	if flower.deployed and displacement.length() <= reach and direction.dot(displacement.normalized()) >= cos(deg_to_rad(wind_cone_degrees)):
		var arrival := FlightStage.REST_PLATE if id == &"horn1" else FlightStage.APPROACH_VASE
		fly_to(destination, direction * 180.0, maxf(displacement.length() / speed, 0.3), arrival)
		return
	flight_stage = FlightStage.FREE
	free_velocity = direction * (second_horn_impulse if id == &"horn2" else 260.0)
	gust_remaining = second_horn_gust_duration if id == &"horn2" else 0.0

func blow_horn(horn: Node2D) -> void:
	horn_blow_count += 1
	var pulse := create_tween()
	pulse.tween_method(_pulse_horn.bind(horn), 0.0, 1.0, 0.3)
	effects.append(pulse)
	var wind: Node2D = horn.get_node("Wind")
	wind.modulate.a = 1.0
	wind.scale = Vector2.ONE
	wind.show()
	var fade := create_tween().set_parallel(true)
	var duration := 1.3 if horn.item_id == &"horn2" else 0.85
	fade.tween_property(wind, "modulate:a", 0.0, duration)
	fade.tween_property(wind, "scale", Vector2(1.5, 2.8) if horn.item_id == &"horn2" else Vector2(1.7, 1.7), duration)
	effects.append(fade)
	$HornSound.stream = small_horn_sound if horn.item_id == &"horn1" else low_horn_sound
	$HornSound.pitch_scale = 1.0
	$HornSound.play()

func _pulse_horn(weight: float, horn: Sprite2D) -> void:
	var size := 1.0 + sin(weight * PI) * 0.18
	# Sprite scale affects its mouth and wind too, so restore the exact scale at rest.
	horn.scale = Vector2.ONE * size

func fly_to(destination: Vector2, bend: Vector2, seconds: float, arrival: FlightStage) -> void:
	flight_stage = FlightStage.BLOW_FIRST if arrival == FlightStage.REST_PLATE else FlightStage.BLOW_SECOND
	var origin := butterfly.position
	flight_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	flight_tween.tween_method(_follow_curve.bind(origin, origin + bend, destination - bend * 0.3, destination), 0.0, 1.0, seconds)
	flight_tween.finished.connect(_arrive.bind(arrival))

func _follow_curve(weight: float, origin: Vector2, first: Vector2, second: Vector2, destination: Vector2) -> void:
	butterfly.position = origin.bezier_interpolate(first, second, destination, weight)

func _arrive(arrival: FlightStage) -> void:
	flight_stage = arrival
	if arrival == FlightStage.REST_PLATE:
		rest_time = flower_rest_duration
		wings.play("rest")
	elif arrival == FlightStage.PERCHED:
		wings.play("rest")
		if star_collected:
			pass_level()
		else:
			phase = Phase.FAILED

func _on_star_detector_area_entered(area: Area2D) -> void:
	if not area.is_in_group("star") or phase != Phase.FLY or star_collected:
		return
	star_collected = true
	star.texture = complete_star
	$CompleteSound.play()
	star_obtained.emit()

func pass_level() -> void:
	if phase == Phase.COMPLETE:
		return
	phase = Phase.COMPLETE
	$PlayIcon.texture = play_texture
	level_passed.emit()
	var origin: Vector2 = $GoldenPetal.position
	var destination: Vector2 = $Anchors/WindowExit.position
	var ending := create_tween().set_parallel(true)
	ending.tween_method(_move_petal.bind(origin, destination), 0.0, 1.0, petal_flight_duration)
	ending.tween_property($GoldenPetal, "rotation", -TAU, petal_flight_duration)
	ending.tween_property($GoldenPetal, "modulate:a", 0.0, 0.35).set_delay(petal_flight_duration - 0.35)
	ending.finished.connect(_ending_finished)
	effects.append(ending)

func _move_petal(weight: float, origin: Vector2, destination: Vector2) -> void:
	$GoldenPetal.position = origin.bezier_interpolate(origin + Vector2(80, -80), destination + Vector2(-110, 80), destination, weight) + Vector2(sin(weight * TAU * 3) * 10, 0)

func _ending_finished() -> void:
	if phase == Phase.COMPLETE and not next_level_scene.is_empty():
		$Transition.play_exit()

func _on_transition_covered() -> void:
	if phase == Phase.COMPLETE and not next_level_scene.is_empty():
		get_tree().change_scene_to_file(next_level_scene)

func stop_level_activity() -> void:
	if flight_tween != null:
		flight_tween.kill()
	for effect in effects:
		effect.kill()
	effects.clear()
	dragged = null
	selected = null
	rotating = false

func reset_simulation() -> void:
	phase = Phase.EDIT
	flight_stage = FlightStage.ASCEND_FIRST
	butterfly.position = $Anchors/ButterflyStart.position
	butterfly.show()
	wings.play("fly")
	used_horns.clear()
	horn_blow_count = 0
	gust_remaining = 0.0
	star_collected = false
	star.texture = star_texture
	$GoldenPetal.transform = petal_home
	$GoldenPetal.modulate = Color.WHITE
	for item in items:
		if item.has_node("Wind"):
			item.get_node("Wind").hide()
			item.get_node("Wind").scale = Vector2.ONE
