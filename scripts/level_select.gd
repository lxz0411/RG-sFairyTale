extends Control

var destination := ""

func _on_reset_progress_pressed() -> void:
	if $Transition.visible or not destination.is_empty():
		return
	get_node("/root/GameProgress").reset_all()

func _on_level_selected(scene_path: String) -> void:
	if $Transition.visible or not destination.is_empty():
		return
	destination = scene_path
	$Transition.play_exit()

func _on_transition_covered() -> void:
	if not destination.is_empty():
		get_tree().change_scene_to_file(destination)
