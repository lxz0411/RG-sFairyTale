extends "res://scripts/level_inventory.gd"

func refresh() -> void:
	super.refresh()
	for i in range(icons.size()):
		icons[i].material = entries[i].material if i < entries.size() else null
