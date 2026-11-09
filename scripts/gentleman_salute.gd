extends Node2D

signal salute_finished

var saluting := false
var played := false
var motion: Tween

func _ready() -> void:
	reset_pose()

func reset_pose() -> void:
	if motion != null:
		motion.kill()
	saluting = false
	played = false
	$Pose.stop()
	$Pose.animation = &"salute"
	$Pose.frame = 0

func play_salute() -> void:
	if played:
		return
	played = true
	saluting = true
	$Pose.play(&"salute")

func _on_pose_animation_finished() -> void:
	if not saluting:
		return
	# Hold the closed-eye smile and raised hat before the exit transition.
	motion = create_tween()
	motion.tween_interval(1.1)
	motion.tween_callback(_finish_salute)

func _finish_salute() -> void:
	saluting = false
	salute_finished.emit()
