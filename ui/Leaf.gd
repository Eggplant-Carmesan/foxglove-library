class_name Leaf
extends Control
## One leaf in a regular's 5-leaf affinity meter.

const FILLED := Color("#4E6B3F")
const EMPTY := Color("#DCCFB3")

@onready var _shape: Polygon2D = $Shape


func set_filled(filled: bool) -> void:
	_shape.color = FILLED if filled else EMPTY
