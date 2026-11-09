extends "res://scripts/level_base.gd"
## Contact-driven room machinery; only clock hands and the counterweight are removable.
signal level_passed
@export_file("*.tscn") var next_level_scene := "res://scenes/level_select.tscn"
enum Phase { EDIT, RUN, REWIND, COMPLETE }
const FIELD := Rect2(18, 96, 1080, 680)
const START := Vector2(279, 80)
var phase := Phase.EDIT
var items: Array[Sprite2D] = []
var bodies: Dictionary = {}
var snapshot: Dictionary = {}
var homes: Dictionary = {}
var dragged: Sprite2D
var selected: Sprite2D
var rotating := false
var rotation_offset := 0.0
var grab_offset := Vector2.ZERO
var drag_home := Transform2D.IDENTITY
var drag_stored := false
var animation: Tween
var ball: RigidBody2D
var book_body: AnimatableBody2D
var book_angle := 0.0
var book_velocity := 0.0
var weight_body: RigidBody2D
var physics_root: Node2D
var upper_body: AnimatableBody2D
var frame_body: AnimatableBody2D
var lower_body: AnimatableBody2D
var tray_body: AnimatableBody2D
var plate_body: StaticBody2D
var rewind_amount := 0.0
var rewind_spin := 0.0
var still_time := 0.0
var run_time := 0.0
var settled_time := 0.0
var last_ball_position := START
var book_released := false
var upper_loaded := false
var book_cap_contact := false
var upper_angle := 0.0
var lower_angle := -0.65
var upper_velocity := 0.0
var lower_velocity := 0.0
var frame_drop := 0.0
var star_dark := preload("res://assets/tutorial/final/star.png")
var star_lit := preload("res://assets/tutorial/final/star_complete.png")

func _ready() -> void:
	items.assign([$Clock, $Weight])
	for item in items:
		item.can_rotate = true
	for item in [$Book, $Frame, $Gear, $LowerLever, $Tray]:
		homes[item] = item.transform
	backpack.refresh()
	$GoalStar.modulate = Color(0.5, 0.45, 0.35)
	queue_redraw()

func reset_mechanisms() -> void:
	for item in homes:
		item.transform = homes[item]
	book_angle = 0.0
	book_velocity = 0.0
	book_released = false
	upper_loaded = false
	book_cap_contact = false
	upper_angle = 0.0
	lower_angle = -0.65
	upper_velocity = 0.0
	lower_velocity = 0.0
	frame_drop = 0.0
	settled_time = 0.0
	queue_redraw()

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
		dragged.position = (point + grab_offset).clamp(Vector2(18, 96), Vector2(1260, 775))

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
	if phase == Phase.REWIND:
		rewind_spin += delta * 5.0
	if can_edit() and not $Transition.visible:
		var direction := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		rotate_item(direction * delta * 1.5)


func add_outline(body: PhysicsBody2D, sprite: Sprite2D) -> void:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(sprite.texture.get_image(), 0.45)
	var contours := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 3.0)
	for contour in contours:
		if contour.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in contour:
			points.append((point - sprite.texture.get_size() * 0.5 + sprite.offset) * sprite.scale)
		var collision := CollisionPolygon2D.new()
		collision.polygon = points
		body.add_child(collision)


func begin_rewind() -> void:
	if phase != Phase.RUN:
		return
	phase = Phase.REWIND
	freeze_physics()
	rewind_spin = 0.0
	animation = create_tween()
	animation.tween_property(self, "rewind_amount", 1.0, 0.65)
	animation.tween_callback(restore_run)
	animation.tween_property(self, "rewind_amount", 0.0, 0.65)
	animation.tween_callback(func(): phase = Phase.EDIT)

func freeze_physics() -> void:
	if is_instance_valid(ball):
		ball.set_deferred("freeze", true)
	for body in bodies.values():
		if body is RigidBody2D:
			body.set_deferred("freeze", true)

func clear_physics() -> void:
	if is_instance_valid(physics_root):
		remove_child(physics_root)
		physics_root.queue_free()
	physics_root = null
	ball = null
	bodies.clear()

func restore_run() -> void:
	clear_physics()
	for item in snapshot:
		item.transform = snapshot[item]
	snapshot.clear()
	reset_mechanisms()
	$Apple.position = START
	$Apple.rotation = 0.0
	$Apple.modulate = Color.WHITE
	$GoalStar.texture = star_dark
	$GoalStar.modulate = Color(0.5, 0.45, 0.35)
	$PlayIcon.texture = play_texture

func reset_level() -> void:
	$Transition.cancel()
	cancel_drag()
	stop_level_activity()
	restore_run()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	phase = Phase.EDIT
	rewind_amount = 0.0
	$ResetIcon.texture = reset_texture

func stop_level_activity() -> void:
	if animation != null:
		animation.kill()
	selected = null
	rotating = false

func pass_level() -> void:
	if phase != Phase.RUN:
		return
	phase = Phase.COMPLETE
	freeze_physics()
	$GoalStar.texture = star_lit
	$GoalStar.modulate = Color(0.65, 1.0, 0.35)
	$CompleteSound.play()
	$PlayIcon.texture = play_texture
	record_completion()
	level_passed.emit()
	animation = create_tween()
	animation.tween_property($Apple, "modulate:a", 0.0, 0.3)
	animation.tween_interval(2.0)
	if not next_level_scene.is_empty():
		animation.tween_callback($Transition.play_exit)

func _on_transition_covered() -> void:
	if phase == Phase.COMPLETE and not next_level_scene.is_empty():
		get_tree().change_scene_to_file(next_level_scene)
func start_level() -> void:
	if not can_edit() or dragged != null or rotating or $Transition.visible:
		return
	snapshot.clear()
	for item in items:
		snapshot[item] = item.transform
	selected = null
	still_time = 0.0
	run_time = 0.0
	settled_time = 0.0
	last_ball_position = START
	reset_mechanisms()
	build_physics()
	phase = Phase.RUN
	$PlayIcon.texture = play_selected

func polygon_body(points: PackedVector2Array, parent: Node = null) -> StaticBody2D:
	var body := StaticBody2D.new()
	(parent if parent != null else physics_root).add_child(body)
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	return body

func rectangle(body: PhysicsBody2D, center: Vector2, size: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func segment(body: PhysicsBody2D, a: Vector2, b: Vector2, width: float) -> void:
	var normal := (b-a).normalized().orthogonal() * width * 0.5
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([a+normal,b+normal,b-normal,a-normal])
	body.add_child(shape)

func rigid(sprite: Sprite2D, mass_value: float) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.position = sprite.position
	body.rotation = sprite.rotation
	body.mass = mass_value
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.linear_damp = 0.02
	body.angular_damp = 0.2
	var material := PhysicsMaterial.new()
	material.friction = 0.6
	material.bounce = 0.0
	body.physics_material_override = material
	physics_root.add_child(body)
	add_outline(body,sprite)
	bodies[sprite] = body
	return body

func moving_body(sprite: Sprite2D) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = false
	body.position = sprite.position
	body.rotation = sprite.rotation
	physics_root.add_child(body)
	add_outline(body, sprite)
	return body

func build_physics() -> void:
	physics_root = Node2D.new()
	physics_root.name = "Simulation"
	add_child(physics_root)
	var rail_index := 0
	for outline in [
		PackedVector2Array([Vector2(299,132),Vector2(460,157),Vector2(813,178),Vector2(815,186),Vector2(455,166),Vector2(297,141)]),
		PackedVector2Array([Vector2(254,177),Vector2(482,201),Vector2(846,214),Vector2(857,212),Vector2(857,236),Vector2(481,219),Vector2(252,200)]),
		PackedVector2Array([Vector2(298,387),Vector2(641,356),Vector2(955,323),Vector2(956,341),Vector2(641,372),Vector2(298,402)]),
		PackedVector2Array([Vector2(287,447),Vector2(568,455),Vector2(870,469),Vector2(869,487),Vector2(568,473),Vector2(287,460)]),
		PackedVector2Array([Vector2(450,590),Vector2(565,591),Vector2(901,519),Vector2(905,536),Vector2(569,607),Vector2(459,603),Vector2(441,619),Vector2(430,614)]),
		
		PackedVector2Array([Vector2(380,608),Vector2(386,608),Vector2(392,621),Vector2(380,621)])
	]:
		var rail := polygon_body(outline)
		if rail_index == 4:
			rail.set_meta("final_rail",true)
		rail_index += 1
	plate_body = polygon_body(PackedVector2Array([Vector2(380,607),Vector2(396,611),Vector2(433,611),Vector2(451,605),Vector2(452,619),Vector2(380,623)]))
	# Upper connection, pressure cap, and lower stop are visible pieces of the machine.
	upper_body = AnimatableBody2D.new()
	upper_body.sync_to_physics = false
	upper_body.position = Vector2(1008,185)
	physics_root.add_child(upper_body)
	segment(upper_body,Vector2.ZERO,Vector2(-18,24),7)
	segment(upper_body,Vector2(-18,24),Vector2(-96,61),8)
	rectangle(upper_body,Vector2(-96,43),Vector2(14,23))
	var stop := polygon_body(PackedVector2Array([Vector2(979,275),Vector2(992,275),Vector2(992,293),Vector2(979,293)]))
	stop.name = "UpperStop"
	frame_body = moving_body($Frame)
	lower_body = moving_body($LowerLever)
	tray_body = moving_body($Tray)
	# The bottle tray stays level on its own small axle as the brown crank turns.
	polygon_body(PackedVector2Array([Vector2(1021,500),Vector2(1048,500),Vector2(1048,527),Vector2(1021,527)]))
	book_body = moving_body($Book)
	weight_body = null
	if $Clock.deployed:
		var clock_body := StaticBody2D.new()
		clock_body.transform = Transform2D($Clock.rotation,$Clock.position)
		physics_root.add_child(clock_body)
		add_outline(clock_body,$Clock)
	if $Weight.deployed:
		weight_body = rigid($Weight,2.0)
	ball = RigidBody2D.new()
	ball.name = "FruitBody"
	ball.position = START
	ball.mass = 0.8
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ball.contact_monitor = true
	ball.max_contacts_reported = 16
	ball.linear_damp = 0.01
	ball.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.01
	var material := PhysicsMaterial.new()
	material.friction = 0.2
	material.bounce = 0.02
	ball.physics_material_override = material
	physics_root.add_child(ball)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	collision.shape = circle
	ball.add_child(collision)
	ball.body_entered.connect(on_fruit_contact)


func on_fruit_contact(body: Node) -> void:
	if phase != Phase.RUN:
		return
	if body.has_meta("final_rail"):
		ball.angular_damp = 1.6
	if body == plate_body:
		ball.linear_damp = 12.0
		ball.angular_damp = 12.0
	if body == book_body and not book_released and ball.position.y < 193.0:
		book_released = true
		book_velocity = clampf(absf(ball.linear_velocity.x)*0.006,0.3,1.2)
	if body == upper_body:
		upper_loaded = true

func book_pressing_cap() -> bool:
	var cap := PackedVector2Array()
	for p in [Vector2(-103,31),Vector2(-89,31),Vector2(-89,55),Vector2(-103,55)]:
		cap.append(upper_body.to_global(p))
	for shape in book_body.get_children():
		if shape is CollisionPolygon2D:
			var outline := PackedVector2Array()
			for p in shape.polygon:
				outline.append(book_body.to_global(p))
			if not Geometry2D.intersect_polygons(outline,cap).is_empty():
				return true
	return false

func step_mechanisms(delta: float) -> void:
	if book_released and book_angle < 1.78:
		book_velocity = minf(book_velocity + sin(book_angle) * 4.0 * delta,1.4)
		book_angle = minf(1.78,book_angle+book_velocity*delta)
		var center := Vector2(835,165).lerp(Vector2(860,201),book_angle/1.78)
		book_body.position = center + Vector2(0,47).rotated(book_angle)
		book_body.rotation = book_angle
		$Book.position = book_body.position
		$Book.rotation = book_angle
		if book_pressing_cap():
			book_cap_contact = true
	# Gravity on the pressed cap supplies the upper linkage's motion. Its displacement
	# drives the gear train and the sliding frame; the fruit itself is never tweened.
	var upper_stop := -0.7 if upper_loaded else -0.12 if book_cap_contact else 0.0
	if upper_angle > upper_stop:
		upper_velocity = minf(upper_velocity + 1.8 * delta,0.75)
		upper_angle = maxf(upper_stop,upper_angle-upper_velocity*delta)
	upper_body.rotation = upper_angle
	# The pressure cap retracts into the linkage at the lower limit, leaving the exit clear.
	upper_body.get_child(2).position.y = 43 + clampf((-upper_angle-0.5)/0.2,0.0,1.0)*24
	var old_drop := frame_drop
	frame_drop = clampf((-upper_angle-0.45)/0.25,0.0,1.0)*55.0
	if old_drop == 0.0 and frame_drop > 0.0:
		$BellSound.play()
	$Frame.position.y = 354 + frame_drop
	frame_body.position = $Frame.position
	$Gear.rotation = PI - frame_drop/55.0 * PI
	# The counterweight is free from the first physics tick. It needs no prior trigger.
	var loaded := is_instance_valid(weight_body) and weight_body.get_colliding_bodies().has(tray_body)
	if loaded and lower_angle < 0.0:
		lower_velocity = minf(lower_velocity + 2.2*delta,0.7)
	elif not loaded:
		lower_velocity = move_toward(lower_velocity,0.0,delta*2.0)
	lower_angle = minf(0.0,lower_angle+lower_velocity*delta)
	$LowerLever.rotation = lower_angle
	lower_body.rotation = lower_angle
	$Tray.position = Vector2(951,445) + Vector2(62,53).rotated(lower_angle) + Vector2(17,-2)
	tray_body.position = $Tray.position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if phase != Phase.RUN or not is_instance_valid(ball):
		return
	step_mechanisms(delta)
	$Apple.position = ball.position
	$Apple.rotation = ball.rotation
	for item in bodies:
		item.position = bodies[item].position
		item.rotation = bodies[item].rotation
	run_time += delta
	var in_plate := Rect2(380,581,70,36).has_point(ball.position)
	if in_plate and ball.linear_velocity.length() < 22.0:
		settled_time += delta
	else:
		settled_time = 0.0
	if settled_time > 0.55:
		pass_level()
		return
	if ball.position.distance_to(last_ball_position) > 3.0:
		still_time = 0.0
		last_ball_position = ball.position
	else:
		still_time += delta
	if ball.position.y > 830 or ball.position.x < -50 or ball.position.x > 1130 or still_time > 7.0 or run_time > 65.0:
		begin_rewind()

func _draw() -> void:
	var pivot := Vector2(1008,185)
	var elbow := pivot + Vector2(-18,24).rotated(upper_angle)
	var end := pivot + Vector2(-96,61).rotated(upper_angle)
	var edge := Color("6f644c")
	var metal := Color("b7ad8b")
	for pair in [[pivot,elbow],[elbow,end]]:
		draw_line(pair[0],pair[1],edge,8,true)
		draw_line(pair[0],pair[1],metal,4,true)
	for point in [pivot,elbow,end]:
		draw_circle(point,6,edge)
		draw_circle(point,3,metal)
	if frame_drop > 0.0:
		for wheel in [Vector2(1016,78),Vector2(1036,94)]:
			for spoke in range(4):
				var direction := Vector2.RIGHT.rotated(frame_drop * 0.08 + spoke * PI * 0.5)
				draw_line(wheel + direction * 4,wheel + direction * 11,Color("806d49"),2,true)
