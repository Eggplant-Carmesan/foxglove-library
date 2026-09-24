class_name Heart
extends Control
## One heart in a 1-5 rating. Placeholder art: a Polygon2D heart that real
## art can replace without touching the pop-in animation.

const FILLED := Color("#E0B156")
const EMPTY := Color("#DCCFB3")

@onready var _shape: Polygon2D = $Shape


func set_filled(filled: bool) -> void:
	_shape.color = FILLED if filled else EMPTY


## Hearts pop in one at a time as the review is read out.
func pop(delay: float) -> void:
	_shape.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(_shape, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
