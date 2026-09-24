class_name MainHall
extends Node2D
## The starting zone: entrance door, counter, and bookcases along the back
## wall. Bookcases live in the .tscn so they can be nudged by hand; more are
## appended to the right as they're bought.

const BOOKCASE_SCENE := preload("res://scenes/Bookcase.tscn")
const BOOKCASE_WIDTH := 244.0
const BOOKCASE_SPACING := 262.0
const BOOKCASE_TOP := 140.0
const HALL_LEFT := -560.0
const EDGE_MARGIN := 120.0

@onready var _bookcases: Node2D = $Bookcases
@onready var _door_pivot: Node2D = $DoorPivot
@onready var _chime: GPUParticles2D = $Chime


func get_bookcases() -> Array[Node]:
	return _bookcases.get_children()


func get_decor_anchors() -> Array[Node]:
	return $DecorAnchors.get_children()


func get_door_position() -> Vector2:
	return $DoorMarker.position


func get_counter_position() -> Vector2:
	return $CounterMarker.position


## How far the camera may travel: the hall ends just past the last bookcase.
func get_content_bounds() -> Vector2:
	var cases := get_bookcases()
	var right := HALL_LEFT + EDGE_MARGIN
	if not cases.is_empty():
		var last: Node2D = cases[-1]
		right = last.position.x + BOOKCASE_WIDTH + EDGE_MARGIN
	return Vector2(HALL_LEFT, right)


## Door swings open and the chime sparkles, as a customer comes or goes.
func swing_door() -> void:
	_chime.restart()
	var tween := create_tween()
	tween.tween_property(_door_pivot, "scale:x", 0.18, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.5)
	tween.tween_property(_door_pivot, "scale:x", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
