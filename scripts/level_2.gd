extends "res://scripts/level_base.gd"
signal level_passed
@export_file("*.tscn") var next_level_scene := "res://scenes/level_3.tscn"
enum Phase { EDIT, RUN, COMPLETE }
const FIELD := Rect2(18,18,1080,758)
const PIVOT := Vector2(552,520)
const START := Vector2(253,202)
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
var bamboo: RigidBody2D
var bamboo_home := Transform2D.IDENTITY
var ball: RigidBody2D
var beam: AnimatableBody2D
var nest: StaticBody2D
var board_angle := 0.0
var loaded := false
var attached := false
var wetness := 0.0
var growth := 0.0
var cap_contact_time := 0.0
var mushroom_can_contact := false
var poured := 0.0
var can_home := Transform2D.IDENTITY
var run_time := 0.0
var settled := 0.0
var animation: Tween
var drops: Array[Dictionary] = []
var drip_time := 0.0
var star_dark := preload("res://assets/tutorial/final/star.png")
var star_lit := preload("res://assets/tutorial/final/star_complete.png")

func _ready() -> void:
	setup_sprite($Bamboo, "bamboo", Rect2(363,311,1888,1377), Vector2(1307,1000), 0.115)
	setup_sprite($Apple, "apple", Rect2(251,150,1266,1562), Vector2(884,931), 0.032)
	setup_sprite($Mushroom, "mushroom", Rect2(80,299,1557,1893), Vector2(858,2192), 0.095)
	setup_sprite($DryMushroom, "mushroom_dry", Rect2(387,723,1579,1261), Vector2(1176,1984), 0.037)
	setup_sprite($Support, "support", Rect2(582,493,1309,711), Vector2(1190,940), 0.065)
	items.assign([$Bamboo, $Can])
	for item in items: item.image = item.texture.get_image()
	backpack.refresh()
	reset_simulation()

func setup_sprite(sprite: Sprite2D, asset: String, region: Rect2, pivot: Vector2, factor: float) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/level2/%s.png" % asset)
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
	if animation != null: animation.kill()
	if phase != Phase.EDIT:
		$Can.transform = can_home
		$Bamboo.transform = bamboo_home
	if is_instance_valid(physics_root):
		remove_child(physics_root)
		physics_root.queue_free()
	physics_root = null
	ball = null
	bamboo = null
	selected = null
	rotating = false
	$CompleteSound.stop()

func reset_simulation() -> void:
	phase = Phase.EDIT
	board_angle = 0.0
	loaded = false
	attached = false
	wetness = 0.0
	growth = 0.0
	cap_contact_time = 0.0
	mushroom_can_contact = false
	poured = 0.0
	run_time = 0.0
	settled = 0.0
	drip_time = 0.0
	drops.clear()
	$Beam.rotation = 0.0
	$Support.rotation = 0.0
	$Apple.position = START
	$Apple.rotation = 0.0
	$Mushroom.hide()
	$DryMushroom.show()
	$GoalStar.texture = star_dark
	$PlayIcon.texture = play_texture
	$ResetIcon.texture = reset_texture
	queue_redraw()

func segment(body: PhysicsBody2D, a: Vector2, b: Vector2, thickness: float = 8.0) -> void:
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(a.distance_to(b),thickness)
	c.shape = s
	c.position = (a+b)*0.5
	c.rotation = (b-a).angle()
	body.add_child(c)

func fixed_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	physics_root.add_child(body)
	return body

func start_level() -> void:
	if not can_edit() or $Transition.visible: return
	cancel_drag()
	selected = null
	rotating = false
	can_home = $Can.transform
	bamboo_home = $Bamboo.transform
	phase = Phase.RUN
	$PlayIcon.texture = play_selected
	physics_root = Node2D.new()
	add_child(physics_root)
	beam = AnimatableBody2D.new()
	beam.sync_to_physics = false
	physics_root.add_child(beam)
	beam.position = PIVOT
	segment(beam, Vector2(-177,81), Vector2(200,145))
	segment(beam, Vector2(-177,81), Vector2(-182,62))
	# A low retaining lip holds the apple while the mushroom grows.
	segment(beam, Vector2(-110,91), Vector2(-110,83), 5)
	var supports := fixed_body()
	segment(supports,Vector2(225,480),Vector2(240,480),10)
	segment(supports,Vector2(335,550),Vector2(350,550),10)
	if not backpack.is_stored($Bamboo):
		bamboo = RigidBody2D.new()
		bamboo.mass = 5.0
		bamboo.linear_damp = 1.5
		bamboo.angular_damp = 3.0
		bamboo.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		var grip := PhysicsMaterial.new()
		grip.friction = 1.0
		grip.bounce = 0.0
		bamboo.physics_material_override = grip
		bamboo.position = $Bamboo.position
		bamboo.rotation = $Bamboo.rotation
		physics_root.add_child(bamboo)
		# Contact surface is the inside of the open bamboo trough.
		segment(bamboo, Vector2(-94,-50), Vector2(96,61), 9)
	var leaf := fixed_body()
	segment(leaf,Vector2(745,687),Vector2(775,706))
	segment(leaf,Vector2(775,706),Vector2(840,730))
	segment(leaf,Vector2(840,730),Vector2(870,729))
	nest = fixed_body()
	segment(nest,Vector2(880,754),Vector2(902,766),10)
	segment(nest,Vector2(902,766),Vector2(953,766),10)
	segment(nest,Vector2(953,766),Vector2(977,744),10)
	ball = RigidBody2D.new()
	ball.position = START
	ball.contact_monitor = true
	ball.max_contacts_reported = 10
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ball.linear_damp = 0.15
	var material := PhysicsMaterial.new()
	material.friction = 0.25
	material.bounce = 0.02
	ball.physics_material_override = material
	physics_root.add_child(ball)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	shape.shape = circle
	ball.add_child(shape)
	# The support must actually meet the base of the can. No answer-angle snapping.
	attached = can_touches_support()

func can_touches_support() -> bool:
	if backpack.is_stored($Can): return false
	# Test the whole painted bottom edge, not a single invisible mounting point.
	var a: Vector2 = $Can.to_global(Vector2(-23,75))
	var b: Vector2 = $Can.to_global(Vector2(38,61))
	var left := Vector2(193,681)
	var right := Vector2(277,705)
	var closest := Geometry2D.get_closest_points_between_segments(a,b,left,right)
	return closest[0].distance_to(closest[1]) <= 24.0

func _physics_process(delta: float) -> void:
	if phase != Phase.RUN: return
	run_time += delta
	if is_instance_valid(bamboo):
		$Bamboo.position = bamboo.position
		$Bamboo.rotation = bamboo.rotation
		if ball.get_colliding_bodies().has(bamboo):
			ball.linear_velocity *= 0.94
	if ball.get_colliding_bodies().has(beam) and beam.to_local(ball.position).x < -70:
		loaded = true
	if loaded and growth < 0.9 and ball.get_colliding_bodies().has(beam):
		ball.linear_velocity *= 0.92
	var target := -0.43 if loaded and growth < 0.05 else 0.0
	if growth > 0.0:
		target = lerpf(-0.43, 0.04, clampf((growth-0.43)/0.57,0.0,1.0))
		if cap_contact_time > 0.18:
			# A short push at contact, followed by damped settling under the load.
			var pulse := cap_contact_time-0.18
			target += sin(pulse*15.0)*exp(-pulse*5.0)*0.045
	board_angle = move_toward(board_angle,target,delta*0.85)
	beam.get_child(2).disabled = growth >= 0.9
	beam.rotation = board_angle
	$Beam.rotation = board_angle
	var tension := clampf(-board_angle/0.43,0,1)
	$Support.rotation = tension*0.55
	if attached:
		$Can.rotation = can_home.get_rotation() + $Support.rotation
		# Both bodies rotate around the same support axle, keeping contact fixed.
		$Can.position = $Support.position + (can_home.origin - $Support.position).rotated($Support.rotation)
		if tension > 0.65 and poured < 2.2:
			poured += delta
			drip_time += delta
			if drip_time > 0.045:
				drip_time = 0.0
				var mouth: Vector2 = $Can.to_global(Vector2(82,-64))
				var velocity := Vector2(62,-15).rotated($Can.rotation)
				drops.append({"position":mouth,"velocity":velocity,"age":0.0})
	for i in range(drops.size()-1,-1,-1):
		var drop := drops[i]
		drop.velocity += Vector2(0,650)*delta
		var old: Vector2 = drop.position
		drop.position += drop.velocity*delta
		drop.age += delta
		var cap_y := lerpf(748,610,growth)
		var cap_width := lerpf(30,75,growth)
		if old.y < cap_y and drop.position.y >= cap_y and absf(drop.position.x-420) < cap_width:
			wetness += 0.065
			drops.remove_at(i)
		elif drop.position.y > 810 or drop.age > 4.0:
			drops.remove_at(i)
	if wetness >= 0.5:
		if growth >= 0.43: cap_contact_time += delta
		if growth < 0.43 or cap_contact_time >= 0.18:
			growth = move_toward(growth,1.0,delta*0.35)
		$Mushroom.show()
		$DryMushroom.hide()
		var cap_height := lerpf(748.0,668.0,minf(growth/0.43,1.0))
		if growth >= 0.43:
			var left := PIVOT + Vector2(-177,81).rotated(board_angle)
			var right := PIVOT + Vector2(200,145).rotated(board_angle)
			cap_height = left.y + (420.0-left.x)*(right.y-left.y)/(right.x-left.x) + 6.0
		$Mushroom.scale = Vector2(lerpf(0.037,0.095,growth),(783.0-cap_height)/1893.0)
	resolve_mushroom_can_contact()
	$Apple.position = ball.position
	$Apple.rotation = ball.rotation
	if ball.get_colliding_bodies().has(nest):
		ball.linear_velocity *= 0.93
	var in_nest := Rect2(893,725,72,45).has_point(ball.position)
	if in_nest and ball.linear_velocity.length() < 24:
		settled += delta
	else: settled = 0.0
	if settled >= 0.55 and growth >= 0.95:
		pass_level()
	elif ball.position.y > 850 or ball.position.x < 0 or ball.position.x > 1105 or run_time > 22:
		reset_level()
	queue_redraw()

func mushroom_can_overlap() -> float:
	if not $Mushroom.visible or backpack.is_stored($Can): return 0.0
	var top: float = 783.0-1893.0*$Mushroom.scale.y
	var radius: float = 778.5*$Mushroom.scale.x
	var penetration := 0.0
	# Sample the painted underside, including the spout, rather than a rectangle.
	var underside := PackedVector2Array([Vector2(-23,75),Vector2(38,61),Vector2(50,52),Vector2(50,21),Vector2(84,-48),Vector2(98,-55)])
	for edge in range(underside.size()-1):
		for sample in range(9):
			var point: Vector2 = $Can.to_global(underside[edge].lerp(underside[edge+1],sample/8.0))
			var u: float = (point.x-420.0)/radius
			if absf(u) >= 1.0: continue
			var surface: float = top + (1.0-sqrt(1.0-u*u))*radius*0.7
			if point.y > surface and point.y < surface+radius*0.85:
				penetration = maxf(penetration,point.y-surface)
	return penetration

func resolve_mushroom_can_contact() -> void:
	if mushroom_can_overlap() <= 0.0: return
	mushroom_can_contact = true
	# The support and can remain coupled: the mushroom pushes against their axle.
	for step in range(40):
		var depth := mushroom_can_overlap()
		if depth <= 0.1: break
		if attached:
			$Support.rotation -= 0.015
			$Can.rotation = can_home.get_rotation()+$Support.rotation
			$Can.position = $Support.position+(can_home.origin-$Support.position).rotated($Support.rotation)
		else:
			$Can.position.y -= minf(depth,2.0)

func pass_level() -> void:
	if phase != Phase.RUN: return
	phase = Phase.COMPLETE
	ball.freeze = true
	$GoalStar.texture = star_lit
	$CompleteSound.play()
	record_completion()
	level_passed.emit()
	if not next_level_scene.is_empty():
		animation = create_tween()
		animation.tween_interval(2.2)
		animation.tween_callback($Transition.play_exit)

func _on_transition_covered() -> void:
	if phase == Phase.COMPLETE and not next_level_scene.is_empty():
		get_tree().change_scene_to_file(next_level_scene)

func _draw() -> void:
	var end := PIVOT + Vector2(-63,109).rotated(board_angle)
	var start := Vector2(206,715) + Vector2(0,clampf(-board_angle/0.43,0,1)*-12)
	var points := PackedVector2Array([start,Vector2(378,119),Vector2(393,119),end])
	draw_polyline(points,Color("795535"),7,true)
	draw_polyline(points,Color("cfad76"),4,true)
	# Rope is an articulated line, never a baked copy of the full storyboard.
	for drop in drops:
		draw_line(drop.position,drop.position-Vector2(1,7),Color(0.49,0.78,0.82,0.85),3,true)

