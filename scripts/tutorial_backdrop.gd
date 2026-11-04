extends Node2D

signal crossing_completed

const START := Vector2(275, 328)
const WALK_SPEED := 95.0
const GRAVITY := 1100.0
const SLOT_CENTERS := [Vector2(1192, 77), Vector2(1192, 201)]
const INVENTORY_AREA := Rect2(1111, 0, 169, 800)
const BUILD_AREA := Rect2(0, 90, 1109, 680)
# The shaft supplies a continuous walking surface; raised forks block passage.
const SHAFTS := [
	[Vector2(12, 8), Vector2(21, 290)],
	[Vector2(3, 5), Vector2(230, 86)]
]
const FORKS := [
	[Vector2(11, 24), Vector2(1, 52), Vector2(0, 77), Vector2(14, 57)],
	[Vector2(54, 5), Vector2(77, 17), Vector2(98, 39), Vector2(84, 34)]
]
const FORK_TIPS := [Vector2(0, 77), Vector2(54, 5)]

enum Location { TREE, INVENTORY, BRIDGE }
enum Phase { EDIT, WALK, STOPPED, COMPLETE }

var locations := [Location.TREE, Location.TREE]
var phase := Phase.EDIT
var held := -1
var rotating_branch := -1
var grab_offset := Vector2.ZERO
var original_transform := Transform2D.IDENTITY
var original_location := Location.TREE
var saved_rotations := [0.0, 0.0]
var plank_surfaces: Array[CollisionPolygon2D] = []
var fork_colliders: Array[CollisionPolygon2D] = []
var images: Array[Image] = []
var feedback: Array[Tween] = [null, null]
var pickup_tweens: Array[Tween] = [null, null]
var door_animation: Tween
var step_clock := 0.0
var hovered := -1

@onready var branches: Array[Sprite2D] = [$BranchVertical, $BranchHorizontal]
@onready var traveler: CharacterBody2D = $Traveler
@onready var door: Sprite2D = $ExitDoor
@onready var star: Sprite2D = $GoalStar
@onready var play_texture: Texture2D = $PlayIcon.texture
@onready var reset_texture: Texture2D = $ResetIcon.texture
var play_selected := preload("res://assets/tutorial/final/play_selected.png")
var reset_selected := preload("res://assets/tutorial/final/reset_selected.png")
var star_complete := preload("res://assets/tutorial/final/star_complete.png")

func _ready() -> void:
	for branch in branches:
		branch.position += branch.texture.get_size() * 0.5
		branch.centered = true
		images.append(branch.texture.get_image())
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/tutorial/final/branch_glow.gdshader")
		material.set_shader_parameter("glow_strength", 0.0)
		branch.material = material
		var fork_body := StaticBody2D.new()
		fork_body.set_meta("branch_fork", true)
		add_child(fork_body)
		var fork := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for point in FORKS[fork_colliders.size()]:
			points.append(point - branch.texture.get_size() * 0.5)
		fork.polygon = points
		fork.disabled = true
		fork_body.add_child(fork)
		fork_colliders.append(fork)
		var body := StaticBody2D.new()
		body.set_meta("branch_index", plank_surfaces.size())
		add_child(body)
		var surface := CollisionPolygon2D.new()
		# Trace the actual opaque wood, including both ends and the fork.
		# A solid polygon supports contacts from above, the sides and underneath.
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(images.back(), 0.45)
		var contours := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 1.0)
		var largest_area := 0.0
		for contour in contours:
			var bounds := Rect2(contour[0], Vector2.ZERO)
			for point in contour:
				bounds = bounds.expand(point)
			if bounds.get_area() > largest_area:
				largest_area = bounds.get_area()
				var outline := PackedVector2Array()
				for point in contour:
					outline.append(point - branch.texture.get_size() * 0.5)
				surface.polygon = outline
		surface.disabled = true
		body.add_child(surface)
		plank_surfaces.append(surface)

func _process(delta: float) -> void:
	var point := get_local_mouse_position()
	hovered = -1
	if phase != Phase.WALK and phase != Phase.COMPLETE:
		hovered = branch_at(point)
	for index in range(branches.size()):
		var active := phase == Phase.EDIT and (hovered == index or held == index or rotating_branch == index)
		var material := branches[index].material as ShaderMaterial
		var strength: float = material.get_shader_parameter("glow_strength")
		material.set_shader_parameter("glow_strength", move_toward(strength, 1.0 if active else 0.0, delta * 8.0))
		var invalid := held == index and not INVENTORY_AREA.has_point(point) and not BUILD_AREA.has_point(branches[index].position)
		material.set_shader_parameter("glow_color", Color(1.0, 0.45, 0.35, 0.55) if invalid else Color(1.0, 0.92, 0.72, 0.55))
	var over_button := icon_hit($ResetIcon, point) or icon_hit($PlayIcon, point)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over_button or hovered >= 0 else Input.CURSOR_ARROW)
	queue_redraw()

func icon_hit(icon: Sprite2D, point: Vector2) -> bool:
	return icon.get_rect().grow(5).has_point(icon.to_local(to_global(point)))

func branch_at(point: Vector2) -> int:
	for index in range(branches.size() - 1, -1, -1):
		var branch := branches[index]
		var pixel := branch.to_local(to_global(point)) + branch.texture.get_size() * 0.5
		var image := images[index]
		# Small alpha-aware padding makes thin branches easy to click independently.
		for offset in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			var sample := Vector2i(pixel + offset)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(sample) and image.get_pixelv(sample).a > 0.15:
				return index
	return -1

func _unhandled_input(event: InputEvent) -> void:
	var point := get_local_mouse_position()
	if event is InputEventMouseMotion:
		if held >= 0:
			move_drag(point)
		elif rotating_branch >= 0:
			# Relative motion also works when the cursor begins at the stick's center.
			branches[rotating_branch].rotation += event.relative.x * 0.012 - event.relative.y * 0.008
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press_at(point)
			else:
				$ResetIcon.texture = reset_texture
				if held >= 0:
					drop_at(point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				begin_rotation(point)
			else:
				if rotating_branch >= 0:
					saved_rotations[rotating_branch] = branches[rotating_branch].rotation
				rotating_branch = -1

func press_at(point: Vector2) -> void:
	if icon_hit($ResetIcon, point):
		reset_walk()
		$ResetIcon.texture = reset_selected
		return
	if phase != Phase.EDIT or held >= 0 or rotating_branch >= 0:
		return
	if icon_hit($PlayIcon, point):
		start_walk()
		return
	var index := branch_at(point)
	if index < 0:
		return
	if locations[index] == Location.TREE:
		collect_branch(index)
	else:
		begin_drag(index, point)

func collect_branch(index: int) -> void:
	var branch := branches[index]
	var tree_transform := branch.transform
	locations[index] = Location.INVENTORY
	return_to_inventory(index)
	var destination := branch.position
	var target_rotation := branch.rotation
	branch.transform = tree_transform
	branch.z_index = 4
	pickup_tweens[index] = create_tween().set_parallel(true)
	pickup_tweens[index].set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	pickup_tweens[index].tween_property(branch, "position", destination, 0.3)
	pickup_tweens[index].tween_property(branch, "rotation", target_rotation, 0.3)
	pickup_tweens[index].tween_property(branch, "scale", Vector2.ONE * 0.32, 0.3)
	pulse_branch(index)
	$PickupSound.play()

func pulse_branch(index: int) -> void:
	if feedback[index] != null:
		feedback[index].kill()
	branches[index].modulate = Color(1.5, 1.35, 1.05)
	feedback[index] = create_tween()
	feedback[index].tween_property(branches[index], "modulate", Color.WHITE, 0.25)

func return_to_inventory(index: int) -> void:
	var branch := branches[index]
	branch.position = SLOT_CENTERS[index]
	branch.scale = Vector2.ONE * 0.32
	branch.rotation = -PI * 0.5 if index == 0 else -0.34
	branch.z_index = 2

func begin_drag(index: int, point: Vector2) -> void:
	if phase != Phase.EDIT:
		return
	if pickup_tweens[index] != null and pickup_tweens[index].is_running():
		pickup_tweens[index].kill()
		return_to_inventory(index)
	held = index
	var branch := branches[index]
	original_transform = branch.transform
	original_location = locations[index]
	if locations[index] == Location.INVENTORY:
		branch.scale = Vector2.ONE
		branch.rotation = saved_rotations[index]
		branch.position = point
	grab_offset = branch.position - point
	branch.z_index = 5

func move_drag(point: Vector2) -> void:
	if held >= 0:
		branches[held].position = point + grab_offset

func drop_at(point: Vector2) -> void:
	move_drag(point)
	var index := held
	held = -1
	var branch := branches[index]
	branch.z_index = 2
	if INVENTORY_AREA.has_point(point):
		if original_location == Location.BRIDGE:
			saved_rotations[index] = branch.rotation
		locations[index] = Location.INVENTORY
		return_to_inventory(index)
	elif BUILD_AREA.has_point(branch.position):
		locations[index] = Location.BRIDGE
		saved_rotations[index] = branch.rotation
		pulse_branch(index)
		$PlaceSound.play()
	else:
		branch.transform = original_transform
		locations[index] = original_location

func begin_rotation(point: Vector2) -> void:
	if phase != Phase.EDIT or held >= 0:
		return
	var index := branch_at(point)
	if index >= 0 and locations[index] == Location.BRIDGE:
		rotating_branch = index

func sync_plank_surfaces() -> void:
	for index in range(branches.size()):
		var surface := plank_surfaces[index]
		surface.disabled = locations[index] != Location.BRIDGE
		fork_colliders[index].disabled = true
		if surface.disabled:
			continue
		var branch := branches[index]
		var half := branch.texture.get_size() * 0.5
		var start := to_local(branch.to_global(SHAFTS[index][0] - half))
		var end := to_local(branch.to_global(SHAFTS[index][1] - half))
		if start.x > end.x:
			var swap := start
			start = end
			end = swap
		var span := end - start
		surface.get_parent().transform = branch.transform
		var fork := fork_colliders[index]
		fork.get_parent().transform = branch.transform
		var tip := to_local(branch.to_global(FORK_TIPS[index] - half))
		# Only the exposed upper fork blocks walking. A half-turn puts it underneath.
		fork.disabled = span.cross(tip - start) >= 0.0

func start_walk() -> void:
	if phase != Phase.EDIT or held >= 0 or rotating_branch >= 0:
		return
	sync_plank_surfaces()
	traveler.position = START
	traveler.velocity = Vector2.ZERO
	traveler.show()
	step_clock = 0.0
	phase = Phase.WALK
	$PlayIcon.texture = play_selected

func touches_raised_fork(collision: KinematicCollision2D) -> bool:
	var body := collision.get_collider()
	if body.has_meta("branch_fork"):
		return true
	if not body.has_meta("branch_index"):
		return false
	var index: int = body.get_meta("branch_index")
	if fork_colliders[index].disabled:
		return false
	var branch := branches[index]
	var point := branch.to_local(collision.get_position()) + branch.texture.get_size() * 0.5
	var fork := PackedVector2Array(FORKS[index])
	if Geometry2D.is_point_in_polygon(point, fork):
		return true
	for edge in range(fork.size()):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, fork[edge], fork[(edge + 1) % fork.size()])) <= 3.0:
			return true
	return false

func step_over_seam(delta: float) -> void:
	if not traveler.is_on_floor():
		return
	var forward := Vector2(WALK_SPEED * delta + 1.0, 0)
	var wall := KinematicCollision2D.new()
	if not traveler.test_move(traveler.transform, forward, wall):
		return
	if wall.get_normal().x > -0.4 or touches_raised_fork(wall):
		return
	# Allow a small wooden seam, but never climb a raised fork or cross empty air.
	var lift := Vector2(0, -12)
	if traveler.test_move(traveler.transform, lift):
		return
	var raised := traveler.transform.translated(lift)
	if traveler.test_move(raised, forward):
		return
	var landing := KinematicCollision2D.new()
	if not traveler.test_move(raised.translated(forward), Vector2(0, 14), landing):
		return
	if landing.get_normal().y > -cos(traveler.floor_max_angle) or touches_raised_fork(landing):
		return
	traveler.position += lift + forward + landing.get_travel()
	traveler.velocity.y = 0.0

func _physics_process(delta: float) -> void:
	if phase != Phase.WALK:
		return
	step_over_seam(delta)
	traveler.velocity.x = WALK_SPEED
	traveler.velocity.y += GRAVITY * delta
	traveler.move_and_slide()
	for index in range(traveler.get_slide_collision_count()):
		var collision := traveler.get_slide_collision(index)
		if touches_raised_fork(collision):
			traveler.velocity = Vector2.ZERO
			phase = Phase.STOPPED
			$PlayIcon.texture = play_texture
			$FootstepSound.stop()
			return
	if traveler.is_on_floor():
		step_clock += delta
		if step_clock >= 0.43:
			step_clock = 0.0
			$FootstepSound.play()
		traveler.get_node("Art").position.y = -173 + sin(step_clock / 0.43 * TAU) * 1.3
	# Preserve the existing grounded, near-door completion rule on the new ledge.
	if traveler.is_on_floor() and traveler.position.x >= 1060 and traveler.position.x <= 1110 and absf(traveler.position.y - 392) <= 24:
		complete_crossing()
	elif traveler.position.y > 860:
		traveler.hide()
		traveler.velocity = Vector2.ZERO
		phase = Phase.STOPPED
		$PlayIcon.texture = play_texture

func complete_crossing() -> void:
	phase = Phase.COMPLETE
	traveler.velocity = Vector2.ZERO
	$PlayIcon.texture = play_texture
	star.texture = star_complete
	star.position = Vector2(1008, 335)
	door_animation = create_tween().set_parallel(true)
	door_animation.tween_property(door, "scale:x", 0.16, 0.45)
	door_animation.tween_property(traveler, "modulate:a", 0.0, 0.4).set_delay(0.35)
	door_animation.tween_property(star, "modulate", Color(1.6, 1.4, 1.0), 0.4)
	$CompleteSound.play()
	crossing_completed.emit()

func reset_walk() -> void:
	if door_animation != null:
		door_animation.kill()
	if held >= 0:
		branches[held].transform = original_transform
		branches[held].z_index = 2
		locations[held] = original_location
	held = -1
	rotating_branch = -1
	for index in range(branches.size()):
		if pickup_tweens[index] != null and pickup_tweens[index].is_running():
			pickup_tweens[index].kill()
			return_to_inventory(index)
	for surface in plank_surfaces:
		surface.disabled = true
	for fork in fork_colliders:
		fork.disabled = true
	traveler.position = START
	traveler.velocity = Vector2.ZERO
	traveler.modulate = Color.WHITE
	traveler.get_node("Art").position = Vector2(-252, -173)
	traveler.show()
	door.scale = Vector2.ONE
	star.texture = preload("res://assets/tutorial/final/star.png")
	star.position = Vector2(1018, 344)
	star.modulate = Color.WHITE
	phase = Phase.EDIT
	$PlayIcon.texture = play_texture
	$FootstepSound.stop()
	$CompleteSound.stop()

func _draw() -> void:
	if phase == Phase.COMPLETE:
		draw_circle(Vector2(1041, 365), 39, Color(1, 0.85, 0.35, 0.22))
