extends Node
## The shared completion record. Test runs may select a separate save file.

signal changed
var save_path := "user://progress.cfg"
var completed: Dictionary = {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--progress-file="):
			save_path = argument.trim_prefix("--progress-file=")
	load_progress()

func is_completed(number: int) -> bool:
	return completed.get(number, false)

func is_unlocked(number: int) -> bool:
	if number < 0 or number > 4: return false
	# Keep the current frontier accessible for resuming an unfinished run.
	for previous in range(number):
		if not is_completed(previous): return false
	return true

func complete_level(number: int) -> void:
	if number < 0 or is_completed(number):
		return
	completed[number] = true
	save_progress()
	changed.emit()

func reset_all() -> void:
	completed.clear()
	save_progress()
	changed.emit()

func save_progress() -> void:
	var config := ConfigFile.new()
	for number in completed:
		config.set_value("completed", str(number), bool(completed[number]))
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var error := config.save(save_path)
	if error != OK:
		push_warning("Cannot save level progress: %s" % error)

func load_progress() -> void:
	completed.clear()
	var config := ConfigFile.new()
	if config.load(save_path) == OK and config.has_section("completed"):
		for key in config.get_section_keys("completed"):
			if key.is_valid_int() and config.get_value("completed", key, false) == true:
				completed[int(key)] = true
	changed.emit()
