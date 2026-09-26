class_name VisitorBell
extends Button
## The door chime, sitting quietly in the corner with a count of who's
## waiting. Tapping it invites the next visitor in, so the player decides
## when to be interrupted.

const RING_SCALE := 1.35

@onready var _badge: Panel = %CountBadge
@onready var _count_label: Label = %CountLabel

var _count := 0


func _ready() -> void:
	pivot_offset = size * 0.5


## Returns true when the number waiting has gone up, so the caller can ring.
func set_count(count: int) -> bool:
	var grew := count > _count
	_count = count
	_count_label.text = str(count)
	_badge.visible = count > 0
	return grew


## A little shake so a new arrival is noticed without taking the screen over.
func ring() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(RING_SCALE, RING_SCALE), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
