extends "res://scripts/level_base.gd"
## Level 4: free placement, contact-driven lever, ballistic key and hollow funnel.
signal level_passed
@export_file("*.tscn") var next_level_scene := "res://scenes/level_select.tscn"
# Replace this SpriteFrames resource with the artist's complete opening sequence.
@export var cabinet_frames: SpriteFrames

enum Phase { EDIT, RUN, OPENING, COMPLETE }
const FIELD := Rect2(18, 18, 1080, 758)
const SHOVEL_PIVOT := Vector2(542, 663)
const SHOVEL_SOURCE := Vector2(1000, 755)
const RAKE_SOURCE := Vector2(310, 175)
const FUNNEL_SOURCE := Vector2(920, 860)
var phase := Phase.EDIT
var items: Array[Sprite2D] = []
var dragged: Sprite2D
var selected: Sprite2D
var rotating := false
var rotation_offset := 0.0
var grab_offset := Vector2.ZERO
var drag_home := Transform2D.IDENTITY
var drag_stored := false
var physics_root: Node2D
var ball: RigidBody2D
var key: RigidBody2D
var rake_body: AnimatableBody2D
var shovel_body: AnimatableBody2D
var funnel_body: StaticBody2D
var fork_body: StaticBody2D
var rake_angle := -0.245
var shovel_angle := -0.62
var shovel_velocity := 0.0
var lever_acceleration := 0.0
var run_time := 0.0
var key_released := false
var key_seated := false
var ball_on_fork := false
var lever_loaded := false
var key_launched := false
var funnel_entered := false
var funnel_exited := false
var animation: Tween
var previous_key_position := Vector2.ZERO

func _ready() -> void:
	setup_sprite($Rake, "rake", Rect2(73,111,1751,504), RAKE_SOURCE, 0.44)
	setup_sprite($Shovel, "shovel", Rect2(210,306,1607,786), SHOVEL_SOURCE, 0.43)
	setup_sprite($Fork, "fork", Rect2(478,95,678,1316), Vector2(820,750), 0.28)
	setup_sprite($Funnel, "funnel", Rect2(298,143,1023,1228), FUNNEL_SOURCE, 0.16)
	setup_sprite($Ball, "ball", Rect2(555,534,430,466), Vector2(770,767), 0.064)
	items.assign([$Fork, $Funnel])
	# Item caches are refreshed after assigning the cropped textures.
	for item in items:
		item.image = item.texture.get_image()
	if cabinet_frames != null:
		$Cabinet.sprite_frames = cabinet_frames
	backpack.refresh()
	reset_simulation()

func setup_sprite(sprite: Sprite2D, asset: String, region: Rect2, pivot: Vector2, factor: float) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/level4/%s.png" % asset)
	atlas.region = region
	sprite.texture = atlas
	sprite.offset = region.get_center() - pivot
	sprite.scale = Vector2.ONE * factor

func can_edit() -> bool:
	return phase == Phase.EDIT

func item_at(point: Vector2) -> Sprite2D:
	var stored: Sprite2D = backpack.item_at(point)
	if stored != null:
		return stored
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		if not item.visible:
			continue
		# Alpha-aware padding, measured in screen pixels, like the tutorial.
		for delta in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			if item.hit(point + delta):
				return item
	return null

func _unhandled_input(event: InputEvent) -> void:
	if handle_level_input(event) or $Transition.visible or not can_edit():
		return
	var point: Vector2 = event.position if event is InputEventMouse else get_local_mouse_position()
	if event is InputEventMouseMotion:
		if rotating and selected != null:
			rotate_item((point - selected.position).angle() - rotation_offset - selected.rotation)
		elif dragged != null:
			move_drag(point)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var item := item_at(point)
				if item == null:
					selected = null
				elif not item.collected:
					collect_item(item)
				else:
					begin_drag(item, point)
			elif dragged != null:
				move_drag(point)
				finish_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var item := item_at(point)
				if item != null and (item.deployed or item == dragged):
					selected = item
					rotating = true
					rotation_offset = (point - item.position).angle() - item.rotation
			else:
				rotating = false
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_item(deg_to_rad(-5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 5))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		rotating = false
		selected = null

func begin_drag(item: Sprite2D, point: Vector2) -> void:
	if not can_edit() or $Transition.visible:
		return
	dragged = item
	selected = item
	rotating = false
	drag_home = item.transform
	drag_stored = backpack.is_stored(item)
	if drag_stored:
		item.position = point
	grab_offset = item.position - point
	backpack.begin_drag(item)

func move_drag(point: Vector2) -> void:
	if dragged != null:
		dragged.position = (point + grab_offset).clamp(Vector2(18, 18), Vector2(1260, 775))

func finish_drag() -> void:
	if dragged == null:
		return
	var item := dragged
	dragged = null
	rotating = false
	if item.position.x >= 1111:
		backpack.store(item)
	elif FIELD.has_point(item.position):
		backpack.deploy(item)
		$PlaceSound.play()
	else:
		item.transform = drag_home
		if drag_stored:
			backpack.store(item)
		else:
			backpack.deploy(item)

func cancel_drag() -> void:
	if dragged == null:
		return
	dragged.transform = drag_home
	if drag_stored:
		backpack.store(dragged)
	else:
		backpack.deploy(dragged)
	dragged = null

func rotate_item(angle: float) -> void:
	if can_edit() and not $Transition.visible and selected != null and (selected.deployed or selected == dragged):
		selected.rotation = wrapf(selected.rotation + angle, -PI, PI)

func _process(delta: float) -> void:
	if can_edit() and not $Transition.visible:
		var direction := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		rotate_item(direction * delta * 1.5)

func reset_level() -> void:
	$Transition.cancel()
	cancel_drag()
	stop_level_activity()
	reset_simulation()

func stop_level_activity() -> void:
	if animation != null:
		animation.kill()
	selected = null
	rotating = false
	$CompleteSound.stop()
	if is_instance_valid(physics_root):
		remove_child(physics_root)
		physics_root.queue_free()
	physics_root = null
	ball = null
	key = null

func reset_simulation() -> void:
	phase = Phase.EDIT
	rake_angle = -0.245
	shovel_angle = -0.62
	shovel_velocity = 0.0
	lever_acceleration = 0.0
	run_time = 0.0
	key_released = false
	key_seated = false
	ball_on_fork = false
	lever_loaded = false
	key_launched = false
	funnel_entered = false
	funnel_exited = false
	$Rake.rotation = rake_angle
	$Shovel.rotation = shovel_angle
	$Ball.position = Vector2(359, 149)
	$Ball.rotation = 0.0
	$Key.position = Vector2(270, 150)
	$Key.rotation = 0.0
	$Key.show()
	$Seed.hide()
	$Cabinet.stop()
	$Cabinet.animation = &"open"
	$Cabinet.frame = 0
	$PlayIcon.texture = play_texture
	$ResetIcon.texture = reset_texture

func start_level() -> void:
	if not can_edit() or $Transition.visible:
		return
	cancel_drag()
	selected = null
	rotating = false
	phase = Phase.RUN
	$PlayIcon.texture = play_selected
	physics_root = Node2D.new()
	add_child(physics_root)
	rake_body = moving_outline($Rake)
	shovel_body = moving_outline($Shovel)
	# The blade is a shallow tray in this side view. Its interior contact surface
	# follows the painted scoop rather than filling its entire bounding rectangle.
	for child in shovel_body.get_children():
		shovel_body.remove_child(child)
		child.queue_free()
	source_segment(shovel_body, Vector2(250,380), Vector2(425,550), SHOVEL_SOURCE, 0.43, 10)
	source_segment(shovel_body, Vector2(425,550), Vector2(550,565), SHOVEL_SOURCE, 0.43, 10)
	source_segment(shovel_body, Vector2(550,565), Vector2(1710,985), SHOVEL_SOURCE, 0.43, 16)
	source_segment(shovel_body, Vector2(1710,985), Vector2(1770,955), SHOVEL_SOURCE, 0.43, 14)
	fork_body = null
	funnel_body = null
	if not backpack.is_stored($Fork):
		fork_body = StaticBody2D.new()
		physics_root.add_child(fork_body)
		fork_body.position = $Fork.position
		fork_body.rotation = $Fork.rotation
		# The ball rolls on the visible fork face, from the tines to the handle.
		source_segment(fork_body, Vector2(650,1250), Vector2(810,1000), Vector2(820,750), 0.28, 10)
		source_segment(fork_body, Vector2(810,1000), Vector2(1125,140), Vector2(820,750), 0.28, 12)
	if not backpack.is_stored($Funnel):
		funnel_body = StaticBody2D.new()
		# The cabinet/funnel channel is behind the upper rake in the illustration.
		funnel_body.collision_layer = 2
		funnel_body.collision_mask = 2
		physics_root.add_child(funnel_body)
		funnel_body.position = $Funnel.position
		funnel_body.rotation = $Funnel.rotation
		# Hollow side walls: the painted mouth is not a solid collision disk.
		source_segment(funnel_body, Vector2(490,1275), Vector2(490,220), FUNNEL_SOURCE, 0.16, 6)
		source_segment(funnel_body, Vector2(1260,395), Vector2(555,180), FUNNEL_SOURCE, 0.16, 6)
	ball = make_rigid($Ball, 14.0, 3.0)
	key = make_rigid($Key, 8.0, 0.18)
	# The key hangs between the rake teeth; tilting releases this support.
	key.freeze = true
	key.add_collision_exception_with(rake_body)
	previous_key_position = key.position

func add_outline(body: PhysicsBody2D, sprite: Sprite2D) -> void:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(sprite.texture.get_image(), 0.45)
	for contour in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 3.0):
		if contour.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in contour:
			points.append((point - sprite.texture.get_size() * 0.5 + sprite.offset) * sprite.scale)
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		body.add_child(shape)

func moving_outline(sprite: Sprite2D) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = false
	physics_root.add_child(body)
	body.position = sprite.position
	body.rotation = sprite.rotation
	add_outline(body, sprite)
	return body

func source_segment(body: PhysicsBody2D, a: Vector2, b: Vector2, pivot: Vector2, factor: float, width: float) -> void:
	var start := (a-pivot)*factor
	var end := (b-pivot)*factor
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(start.distance_to(end), width)
	shape.shape = rectangle
	shape.position = (start+end)*0.5
	shape.rotation = (end-start).angle()
	body.add_child(shape)

func make_rigid(sprite: Sprite2D, radius: float, mass_value: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = sprite.position
	body.mass = mass_value
	body.contact_monitor = true
	body.max_contacts_reported = 12
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.linear_damp = 0.05
	body.angular_damp = 0.1
	var material := PhysicsMaterial.new()
	material.friction = 0.35
	material.bounce = 0.03
	body.physics_material_override = material
	physics_root.add_child(body)
	var collision := CollisionShape2D.new()
	if sprite == $Key:
		body.collision_layer = 2
		body.collision_mask = 3
		var capsule := CapsuleShape2D.new()
		capsule.radius = 5.0
		capsule.height = 34.0
		collision.shape = capsule
		collision.rotation = PI*0.5
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision.shape = circle
	body.add_child(collision)
	return body

func _physics_process(delta: float) -> void:
	if phase != Phase.RUN:
		return
	run_time += delta
	rake_angle = move_toward(rake_angle, -0.04, delta*0.12)
	rake_body.rotation = rake_angle
	$Rake.rotation = rake_angle
	if not key_released and rake_angle > -0.20:
		key_released = true
		key.freeze = false
	var key_contacts := key.get_colliding_bodies()
	var ball_contacts := ball.get_colliding_bodies()
	if key_contacts.has(shovel_body) and not key_launched:
		key_seated = true
	if is_instance_valid(fork_body) and ball_contacts.has(fork_body):
		ball_on_fork = true
	if not lever_loaded and ball_contacts.has(shovel_body) and shovel_body.to_local(ball.position).x > 140:
		lever_loaded = true
		# Torque grows with the distance from the fixed wooden fulcrum.
		var arm_length := shovel_body.to_local(ball.position).x
		lever_acceleration = clampf(ball.mass * 980.0 * arm_length / 44000.0, 10.0, 18.0)
	# Gravity/impact at the right arm supplies angular momentum. Once loaded,
	# momentum continues to move the lever until its mechanical end stop.
	if lever_loaded and shovel_angle < 0.15:
		shovel_velocity = minf(shovel_velocity + delta*lever_acceleration, 5.5)
		shovel_angle = minf(0.15, shovel_angle + shovel_velocity*delta)
	shovel_body.rotation = shovel_angle
	$Shovel.rotation = shovel_angle
	if key_seated and not key_launched and lever_loaded and shovel_angle > -0.10 and key.position.distance_to($Shovel.to_global(Vector2(-560,-205))) < 110:
		# Contact impulse from the scoop at release. Direction comes from the lever,
		# never from the funnel's position; the remaining flight is rigid-body gravity.
		var arm := key.position - SHOVEL_PIVOT
		var tangent := Vector2(-arm.y, arm.x) * shovel_velocity
		key.linear_velocity = tangent
		key.angular_velocity = -3.0
		key_launched = true
		key.add_collision_exception_with(shovel_body)
	check_funnel()
	$Ball.position = ball.position
	$Ball.rotation = ball.rotation
	$Key.position = key.position
	$Key.rotation = key.rotation
	previous_key_position = key.position
	if run_time > 24.0 or key.position.y > 900 or key.position.x < -120 or key.position.x > 1180 or (not lever_loaded and ball.position.y > 950):
		reset_level()

func funnel_local(point: Vector2) -> Vector2:
	# x across the mouth, y down the throat, in screen units at the default scale.
	var source: Vector2 = $Funnel.to_local(point)
	return (source.rotated(-2.596) * 0.16)

func check_funnel() -> void:
	if not key_launched or not is_instance_valid(funnel_body):
		return
	var now := funnel_local(key.position)
	var before := funnel_local(previous_key_position)
	if not funnel_entered and before.y < 0 and now.y >= 0 and absf(now.x) < 75:
		funnel_entered = true
	# Only a key which has crossed the mouth and emerged from the narrow outlet
	# can unlock. A misplaced funnel or a touch on its exterior does nothing.
	if funnel_entered and not funnel_exited and before.y <= 107 and now.y > 107 and absf(now.x) < 20:
		funnel_exited = true
	if funnel_exited and Rect2(540,270,90,65).has_point(key.position):
		open_cabinet()

func open_cabinet() -> void:
	if phase != Phase.RUN:
		return
	phase = Phase.OPENING
	key.freeze = true
	ball.freeze = true
	$Key.hide()
	$Cabinet.play(&"open")

func _on_cabinet_animation_finished() -> void:
	if phase != Phase.OPENING:
		return
	$Seed.show()
	phase = Phase.COMPLETE
	record_completion()
	$CompleteSound.play()
	level_passed.emit()
	if not next_level_scene.is_empty():
		animation = create_tween()
		animation.tween_interval(2.2)
		animation.tween_callback($Transition.play_exit)

func _on_transition_covered() -> void:
	if phase == Phase.COMPLETE and not next_level_scene.is_empty():
		get_tree().change_scene_to_file(next_level_scene)



