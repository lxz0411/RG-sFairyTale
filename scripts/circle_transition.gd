extends CanvasLayer
## Emits after the circle covers the viewport and the black hold has elapsed.

signal covered
signal revealed

## Shared duration for exit expansion and its exact reverse on entry.
@export_range(0.05, 10.0, 0.05, "or_greater", "suffix:s") var expansion_duration := 0.6
## Seconds to stay fully black before loading the next level.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var black_hold_duration := 0.6
var animation: Tween
var entering := false

func _ready() -> void:
	# Cover the very first frame, then reveal only after the new scene is ready.
	play_enter()

func play_enter() -> void:
	cancel()
	entering = true
	_set_progress(1.05)
	show()
	animation = create_tween()
	animation.pause()
	# Exact time reverse of the exit's QUAD/EASE_IN expansion.
	animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animation.tween_method(_set_progress, 1.05, 0.0, expansion_duration)
	animation.tween_interval(0.12)
	animation.finished.connect(_on_animation_finished)
	_start_after_initial_frame(animation)

func play_exit() -> void:
	cancel()
	show()
	animation = create_tween()
	animation.pause()
	animation.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	animation.tween_interval(0.12)
	animation.tween_method(_set_progress, 0.0, 1.05, expansion_duration)
	animation.tween_interval(black_hold_duration)
	animation.finished.connect(_on_animation_finished)
	_start_after_initial_frame(animation)

func _start_after_initial_frame(expected_animation: Tween) -> void:
	# Render the starting state and finish scene setup before advancing the tween.
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if not is_inside_tree(): return
	if animation == expected_animation and visible:
		animation.play()

func _on_animation_finished() -> void:
	var finished_animation := animation
	if entering:
		cancel()
		revealed.emit()
		return
	# Keep the fully black cover on screen for one rendered frame before switching.
	await get_tree().process_frame
	if animation == finished_animation and visible:
		covered.emit()

func cancel() -> void:
	if animation != null:
		animation.kill()
		animation = null
	entering = false
	_set_progress(0.0)
	hide()

func _set_progress(value: float) -> void:
	$Cover.material.set_shader_parameter("progress", value)
