extends Node2D
## Scenery, bodies, collision shapes and inventory are authored in the scene.
## Planks are fixed supports after placement; the ball uses Godot rigid-body physics.

const FIELD := Rect2(52, 44, 1056, 692)
const BOARD_HALF := Vector2(120, 12)
const BALL_RADIUS := 20.0

var dragged: PhysicsBody2D
var selected_board: StaticBody2D
var drag_offset := Vector2.ZERO
var rotating := false
var rotation_offset := 0.0
var ccd_warmup := 0
var home_positions: Dictionary = {}
var item_slots: Dictionary = {}

@onready var ball: RigidBody2D = $Items/Ball

func _ready() -> void:
	var items := $Items.get_children()
	for index in range(items.size()):
		var item: PhysicsBody2D = items[index]
		home_positions[item] = item.position
		item_slots[item] = $HUD/Backpack/Slots.get_child(index)
		item_slots[item].get_node("Icon").texture = item.get_meta("inventory_icon")
		return_to_inventory(item)
	$HUD/Reset.pressed.connect(reset_items)

func _physics_process(_delta: float) -> void:
	# Dragging is a teleport, not a physical sweep from the inventory.
	# Resume CCD only after the physics server has accepted the new transform.
	if ccd_warmup > 0:
		ccd_warmup -= 1
		if ccd_warmup == 0 and not ball.freeze:
			ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY

func _process(delta: float) -> void:
	if selected_board != null:
		var direction := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		if direction != 0.0:
			rotate_board(direction * delta * 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var item := item_at(event.position)
				if item != null:
					begin_drag(item, event.position)
				else:
					selected_board = null
			elif dragged != null:
				move_drag(event.position)
				finish_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var item := item_at(event.position)
				if item is StaticBody2D and item.visible:
					selected_board = item
					rotating = true
					rotation_offset = (event.position - item.position).angle() - item.rotation
			else:
				rotating = false
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_board(deg_to_rad(-5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 5))
	elif event is InputEventMouseMotion:
		if rotating and selected_board != null:
			var angle: float = (event.position - selected_board.position).angle() - rotation_offset
			rotate_board(angle - selected_board.rotation)
		elif dragged != null:
			move_drag(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if dragged != null:
			return_to_inventory(dragged)
			dragged = null
		rotating = false

func item_at(point: Vector2) -> PhysicsBody2D:
	for item in item_slots:
		if not item.visible and item_slots[item].get_global_rect().has_point(point):
			return item
	# Ball is drawn over the boards, so test it first.
	if ball.visible and ball.to_local(point).length() <= BALL_RADIUS:
		return ball
	for board in [$Items/Board2, $Items/Board1]:
		if board.visible and Rect2(-BOARD_HALF, BOARD_HALF * 2).has_point(board.to_local(point)):
			return board
	return null

func begin_drag(item: PhysicsBody2D, point: Vector2) -> void:
	if not item.visible:
		item.position = point
		item.show()
		item_slots[item].get_node("Icon").hide()
	dragged = item
	drag_offset = item.position - point
	rotating = false
	item.collision_layer = 0
	item.collision_mask = 0
	if item is RigidBody2D:
		ccd_warmup = 0
		item.freeze = true
		item.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
		item.linear_velocity = Vector2.ZERO
		item.angular_velocity = 0.0
		selected_board = null
	else:
		selected_board = item

func move_drag(point: Vector2) -> void:
	if dragged != null:
		var target := point + drag_offset
		dragged.position = target.clamp(Vector2(20, 20), Vector2(1260, 780))

func finish_drag() -> void:
	if dragged == null:
		return
	if dragged.position.x >= $HUD/Backpack.get_global_rect().position.x - 20.0:
		return_to_inventory(dragged)
	else:
		clamp_to_field(dragged)
		dragged.collision_layer = 1
		dragged.collision_mask = 1
		if dragged is RigidBody2D:
			ccd_warmup = 2
			dragged.freeze = false
			dragged.sleeping = false
	dragged = null

func rotate_board(angle: float) -> void:
	if selected_board == null:
		return
	selected_board.rotation = wrapf(selected_board.rotation + angle, -PI, PI)
	if selected_board.position.x < $HUD/Backpack.get_global_rect().position.x - 20.0:
		clamp_to_field(selected_board)

func clamp_to_field(item: PhysicsBody2D) -> void:
	var half := Vector2.ONE * BALL_RADIUS
	if item is StaticBody2D:
		var c := absf(cos(item.rotation))
		var s := absf(sin(item.rotation))
		half = Vector2(BOARD_HALF.x * c + BOARD_HALF.y * s, BOARD_HALF.x * s + BOARD_HALF.y * c)
	item.position = item.position.clamp(FIELD.position + half, FIELD.end - half)

func return_to_inventory(item: PhysicsBody2D) -> void:
	item.collision_layer = 0
	item.collision_mask = 0
	if item is RigidBody2D:
		ccd_warmup = 0
		item.freeze = true
		item.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
		item.linear_velocity = Vector2.ZERO
		item.angular_velocity = 0.0
	item.position = home_positions[item]
	item.rotation = 0.0
	item.hide()
	item_slots[item].get_node("Icon").show()
	if item is RigidBody2D:
		# Synchronize the server as well as the node, so the final active-body
		# state callback cannot restore the pre-reset position after freezing.
		PhysicsServer2D.body_set_state(item.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, item.global_transform)
	if item == selected_board:
		selected_board = null

func reset_items() -> void:
	dragged = null
	selected_board = null
	rotating = false
	for item in $Items.get_children():
		return_to_inventory(item)
