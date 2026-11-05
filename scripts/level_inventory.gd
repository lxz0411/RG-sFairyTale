extends Sprite2D
## Slots are reserved on first collection and never compacted when an item leaves.

var entries: Array[Sprite2D] = []
var dragging: Sprite2D
@onready var icons: Array[Sprite2D] = [$Icon1, $Icon2, $Icon3, $Icon4, $Icon5]

func collect(item: Sprite2D) -> bool:
	if entries.has(item) or entries.size() >= icons.size():
		return false
	entries.append(item)
	item.collected = true
	store(item)
	return true

func slot_center(item: Sprite2D) -> Vector2:
	return icons[entries.find(item)].global_position

func is_stored(item: Sprite2D) -> bool:
	return entries.has(item) and not item.deployed

func stored_items() -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for item in entries:
		if is_stored(item):
			result.append(item)
	return result

func item_at(point: Vector2) -> Sprite2D:
	for item in entries:
		if is_stored(item) and item != dragging:
			if Rect2(slot_center(item) - Vector2(56, 60), Vector2(112, 120)).has_point(point):
				return item
	return null

func begin_drag(item: Sprite2D) -> void:
	dragging = item
	item.show()
	item.z_index = 5
	refresh()

func store(item: Sprite2D) -> void:
	item.deployed = false
	item.hide()
	item.z_index = 2
	if dragging == item:
		dragging = null
	refresh()

func deploy(item: Sprite2D) -> void:
	item.deployed = true
	item.show()
	item.z_index = 2
	if dragging == item:
		dragging = null
	refresh()

func recall_all() -> void:
	dragging = null
	for item in entries:
		item.deployed = false
		item.scale = Vector2.ONE
		item.modulate = Color.WHITE
		item.z_index = 2
		item.hide()
	refresh()

func refresh() -> void:
	for index in range(icons.size()):
		var icon := icons[index]
		var item: Sprite2D = entries[index] if index < entries.size() else null
		icon.texture = item.texture if item != null and is_stored(item) else null
		icon.visible = item != dragging
		if icon.texture != null:
			var size := icon.texture.get_size()
			icon.scale = Vector2.ONE * minf(84.0 / size.x, 90.0 / size.y)
