extends CanvasLayer
## Four lesson steps and a reset spotlight after failure. Static visuals live in the scene.

enum Step { COLLECT, PLACE, ROTATE, START, DONE }

@export var enabled := true
@export_range(1.0, 90.0) var required_rotation_degrees := 12.0

const DROP_AREA := Rect2(290, 275, 490, 390)
var step := Step.COLLECT
var right_rotation := 0.0
var holes: Array[Rect2] = []
var arrow_clock := 0.0
@onready var level: Node2D = get_parent()

func _on_revealed() -> void:
	# Show the first spotlight in the same frame as the entry cover disappears.
	_process(0.0)

func _process(delta: float) -> void:
	var retrying: bool = level.should_show_reset_hint()
	visible = enabled and (retrying or (step != Step.DONE and level.phase == level.Phase.EDIT)) and not level.get_node("Transition").visible
	if not visible:
		return
	# Rotation/start stay unmasked; a failed attempt leaves only reset clear.
	$Shade.visible = retrying or step in [Step.COLLECT, Step.PLACE]
	update_holes()
	var shader_holes := PackedVector4Array()
	for index in range(6):
		var rect := holes[index] if index < holes.size() else Rect2()
		shader_holes.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	$Shade.material.set_shader_parameter("holes", shader_holes)
	$Shade.material.set_shader_parameter("hole_count", holes.size())
	$Shade.material.set_shader_parameter("overlay_size", $Shade.size)
	$RightMouse.visible = not retrying and step == Step.ROTATE
	$StartArrow.visible = not retrying and step == Step.START
	if $StartArrow.visible:
		arrow_clock += delta
		var button_rect := sprite_bounds(level.get_node("PlayIcon"), 0.0)
		$StartArrow.position = Vector2(button_rect.end.x + 14.0 + 8.0 * (1.0 - cos(arrow_clock * TAU)), button_rect.get_center().y)
	else:
		arrow_clock = 0.0
	if $RightMouse.visible:
		var target: Sprite2D = level.branches[0]
		if level.selected_branch >= 0:
			target = level.branches[level.selected_branch]
		$RightMouse.position = (target.position + Vector2(60, -65)).clamp(Vector2(50, 110), Vector2(1040, 700))

func sprite_bounds(sprite: Sprite2D, padding: float = 16.0) -> Rect2:
	return (sprite.global_transform * sprite.get_rect()).grow(padding)

func update_holes() -> void:
	holes.clear()
	if level.should_show_reset_hint():
		holes.append(sprite_bounds(level.get_node("ResetIcon")))
		return
	match step:
		Step.COLLECT:
			for index in range(level.branches.size()):
				if level.locations[index] == level.Location.TREE:
					holes.append(sprite_bounds(level.branches[index]))
		Step.PLACE:
			for index in range(level.branches.size()):
				if level.locations[index] == level.Location.INVENTORY:
					holes.append(Rect2(level.backpack.slot_center(level.branches[index]) - Vector2(65, 55), Vector2(130, 110)))
			holes.append(DROP_AREA)
			if level.held >= 0:
				holes.append(sprite_bounds(level.branches[level.held]))
		Step.ROTATE:
			for index in range(level.branches.size()):
				if level.locations[index] == level.Location.BRIDGE or level.held == index:
					holes.append(sprite_bounds(level.branches[index], 30.0))
		Step.START:
			holes.append(sprite_bounds(level.get_node("PlayIcon"), 12.0))

func allows_point(point: Vector2) -> bool:
	if not enabled or (step >= Step.ROTATE and not level.should_show_reset_hint()):
		return true
	update_holes()
	for rect in holes:
		if rect.has_point(point):
			return true
	return false

func allows(action: StringName) -> bool:
	if enabled and level.should_show_reset_hint():
		return action == &"reset"
	if not enabled or step >= Step.ROTATE:
		return true
	match action:
		&"collect": return step == Step.COLLECT
		&"drag": return step in [Step.PLACE, Step.ROTATE]
		&"rotate": return step == Step.ROTATE
		&"start": return step == Step.START
	return false

func sync_progress() -> void:
	if not enabled:
		return
	if step == Step.COLLECT and not level.locations.has(level.Location.TREE):
		step = Step.PLACE
	if step == Step.PLACE and level.locations.count(level.Location.BRIDGE) == level.branches.size():
		step = Step.ROTATE
		$Shade.hide()

func record_right_rotation(angle: float) -> void:
	if enabled and step == Step.ROTATE:
		right_rotation += absf(angle)

func rotation_released() -> void:
	if step == Step.ROTATE and right_rotation >= deg_to_rad(required_rotation_degrees):
		step = Step.START

func finish() -> void:
	step = Step.DONE
	hide()

func on_level_reset() -> void:
	if step != Step.DONE:
		step = Step.COLLECT if level.locations.has(level.Location.TREE) else Step.PLACE
	right_rotation = 0.0
	_process(0.0)
