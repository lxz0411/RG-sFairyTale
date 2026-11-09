extends Sprite2D
## Collectible state shared by props in every level.

@export var item_id: StringName
@export var can_rotate := true
var collected := false
var deployed := false
@onready var image: Image = texture.get_image()

func hit(point: Vector2) -> bool:
	var pixel := Vector2i(to_local(point) - offset + texture.get_size() * 0.5)
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a > 0.15
