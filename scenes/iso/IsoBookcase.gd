@tool
class_name IsoBookcase
extends Node2D
## An isometric bookcase. The frame is art; the books are instanced per copy,
## because the shelf contents change every day.
##
## Origin is the centre of its 2x1 footprint, so position is the tile it
## stands on.

const SPINE_SCENE := preload("res://scenes/iso/IsoSpine.tscn")
## Books stand against each other. Their drawn outlines are the only
## separation, so this stays at nothing unless a style calls for it.
const SPINE_GAP := 0.0

## Where the ground point sits inside the art, in image pixels. Zero works
## it out from the art, which is right for anything drawn on a template.
@export var art_anchor := Vector2.ZERO
## How deep the footprint is, in tiles. A deeper footprint reaches further
## below the anchor, so the art has to hang lower to match.
@export var footprint_depth := 1.0
@export var art: Texture2D
## Start of each plank, relative to the footprint centre. Tune to the art —
## one entry per shelf the bookcase art actually has.
@export var plank_starts: Array[Vector2] = [Vector2(-92.0, -46.0), Vector2(-92.0, -166.0)]
## How many books fit along one shelf.
@export var slots_per_plank := 3
## True for a bookcase against the back-left wall: the art is the mirrored
## drawing, its shelves fall to the left instead of the right, and its books
## are drawn from their other side to match.
@export var mirrored := false
## Spine art, narrowest variant first. Held here rather than set on each
## spine afterwards, because a spine lays itself out the moment it is given
## a book.
@export var spine_art: Array[Texture2D] = []
@export var spine_anchor := Vector2.ZERO
## How far along the shelf each book steps, in pixels. Zero measures it
## from the art, which is right when the art is a bare spine.
##
## Set it when the art is a whole book seen at an angle: then the silhouette
## is thickness plus depth, but only the thickness should decide the
## packing. Books overlap by the difference, which is what a packed shelf
## looks like anyway — each spine hiding the cover of the one behind.
@export var spine_advance := 0.0
## How far back this piece stands from the middle of its tile, toward the
## wall behind it, in pixels.
##
## A bookcase is anchored at the middle of its footprint, but what should
## meet the wall is its back edge, so a shallow case floats out into the
## room when it sits on a tile centre.
##
## Back is straight UP the screen, not along the wall's normal. Going
## back also means sliding along the wall to keep the end at the corner,
## and those two steps are one tile axis each — they cancel horizontally
## and leave a purely vertical move. That is what keeps a run on one wall
## joined to the run on the other.
##
## The art moves, not the node, so the node still snaps to the grid and
## still reports the tile it belongs to. Leave it at zero for anything
## standing in the open.
@export var wall_offset := 0.0:
	set(value):
		wall_offset = value
		_apply_wall_offset()

var spines: Array[IsoSpine] = []

## Total books this bookcase holds.
var slots: int:
	get: return plank_starts.size() * slots_per_plank

@onready var _placeholder: Node2D = $Placeholder
@onready var _art_slot: Sprite2D = $ArtSlot
@onready var _shelves: Node2D = $Shelves


func _ready() -> void:
	_art_slot.texture = art
	var anchor := art_anchor
	if anchor == Vector2.ZERO:
		anchor = IsoGrid.anchor_for(art, footprint_depth)
	IsoGrid.apply_anchor(_art_slot, anchor)
	_placeholder.visible = _art_slot.texture == null
	_apply_wall_offset()


func _apply_wall_offset() -> void:
	if not is_node_ready():
		return
	# The children move, not the node, so snapping and spine_at still work
	# off the tile the bookcase belongs to.
	var back := Vector2(0.0, -wall_offset)
	_placeholder.position = back
	_art_slot.position = back
	_shelves.position = back


func set_copies(copies: Array) -> void:
	for spine in spines:
		spine.queue_free()
	spines.clear()

	var next_offset: Array[float] = []
	next_offset.resize(plank_starts.size())
	next_offset.fill(0.0)

	for i in mini(copies.size(), slots):
		var plank := i / slots_per_plank
		var spine: IsoSpine = SPINE_SCENE.instantiate()
		_shelves.add_child(spine)
		spine.art_variants = spine_art
		spine.art_anchor = spine_anchor
		spine.mirrored = mirrored
		spine.setup(copies[i])
		spine.position = plank_starts[plank] + spine.shelf_step(next_offset[plank])
		var advance := spine_advance if spine_advance > 0.0 else spine.spine_width
		next_offset[plank] += advance + SPINE_GAP
		spines.append(spine)


## The spine whose rectangle contains a world point, or null. Searched from
## the front of the shelf back, so the book nearest the viewer wins where
## two overlap.
func spine_at(world_point: Vector2) -> IsoSpine:
	for i in range(spines.size() - 1, -1, -1):
		if spines[i].get_world_rect().has_point(world_point):
			return spines[i]
	return null
