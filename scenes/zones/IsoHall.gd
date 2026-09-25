@tool
class_name IsoHall
extends Node2D
## The starting zone, isometric: a tiled floor, two back walls, a counter,
## a door, and bookcases standing on the floor.
##
## The floor and the two wall runs are TileMapLayers — select one and paint
## with the TileMap panel. Bookcases are ordinary nodes, because a tile
## cannot have children and a bookcase is full of books that change every
## day. Drag them and they snap to the grid.

## How far past the floor's edge the camera may travel.
const EDGE_MARGIN := 160.0

## Everything the editor keeps on the grid. Containers are in the list
## harmlessly — they sit at the origin — so that their children are reached.
const SNAPPED_PARENTS := [
	"World/Props",
	"World/Props/Bookcases",
	"World/Markers",
	"World/DecorAnchors",
]

## Turn off to nudge a prop somewhere the grid won't allow.
@export var snap_props := true
## How finely props snap.
##
## Whole tiles land on tile centres only. Halves add every tile edge, so a
## piece can sit against the wall behind a tile, in its middle, or at its
## front. Quarters are there for fine work and mostly get in the way.
@export_enum("Whole tiles:1", "Half tiles:2", "Quarter tiles:4")
var snap_divisions := 2

@onready var _floor: TileMapLayer = $Floor
@onready var _bookcases: Node2D = $World/Props/Bookcases
@onready var _door_pivot: Node2D = $World/Props/DoorPivot
@onready var _chime: GPUParticles2D = $World/Props/Chime


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not snap_props:
		return
	var step := 1.0 / float(maxi(1, snap_divisions))
	for path in SNAPPED_PARENTS:
		# get_node_or_null, because this runs every frame while the scene is
		# open and the tree can be half-built or mid-edit.
		var parent := get_node_or_null(path)
		if parent == null:
			continue
		for child in parent.get_children():
			if child is Node2D:
				child.position = IsoGrid.snap(child.position, step)


func get_bookcases() -> Array[Node]:
	return _bookcases.get_children()


## Visitors are parented in here rather than beside the hall, so they sort
## against the bookcases instead of always drawing on top of them.
func get_visitor_parent() -> Node2D:
	return $World/Props/Visitors


func get_decor_anchors() -> Array[Node]:
	return $World/DecorAnchors.get_children()


func get_door_position() -> Vector2:
	return $World/Markers/DoorMarker.position


func get_counter_position() -> Vector2:
	return $World/Markers/CounterMarker.position


## How far the camera may travel, as a left and right world x. Taken from
## the floor that has actually been painted, so extending the room in the
## TileMap panel extends where the player can look.
func get_content_bounds() -> Vector2:
	var used: Rect2i = _floor.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Vector2(-EDGE_MARGIN, EDGE_MARGIN)
	# A diamond grid is widest at its left and right corners: the leftmost
	# tile is the far end of the y axis, the rightmost the far end of x.
	var left_tile := Vector2(used.position.x, used.end.y - 1)
	var right_tile := Vector2(used.end.x - 1, used.position.y)
	var left := IsoGrid.tile_to_world(left_tile).x - IsoGrid.TILE.x * 0.5
	var right := IsoGrid.tile_to_world(right_tile).x + IsoGrid.TILE.x * 0.5
	return Vector2(left - EDGE_MARGIN, right + EDGE_MARGIN)


## Door swings open and the chime sparkles, as a customer comes or goes.
func swing_door() -> void:
	_chime.restart()
	var tween := create_tween()
	tween.tween_property(_door_pivot, "scale:x", 0.18, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.5)
	tween.tween_property(_door_pivot, "scale:x", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
