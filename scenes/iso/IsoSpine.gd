class_name IsoSpine
extends Node2D
## One book on an isometric shelf. Origin is the spine's front-bottom corner,
## so a bookcase can line spines up along the shelf axis.
##
## Art is painted white: the colour comes from the book id at runtime, the
## same way the side-on spines work. The colour goes on the art itself so
## the node's own modulate stays free for dimming and selection.

const WIDTH_MIN := 26.0
const WIDTH_STEP := 4.0
const WIDTH_VARIANTS := 5
const HEIGHT_MIN := 78.0
const HEIGHT_STEP := 8.0
const HEIGHT_VARIANTS := 5

const DIM_COLOR := Color(0.4, 0.42, 0.4, 1.0)
const DUSTY_COLOR := Color(0.78, 0.76, 0.7, 1.0)
## How far a selected book slides out of the shelf, toward the viewer.
const SELECTED_SLIDE := 14.0

## Where the spine meets the plank, in image pixels. Zero works it out from
## the art, which is right for anything drawn on the spine template.
@export var art_anchor := Vector2.ZERO
## One texture per width variant, narrowest first.
@export var art_variants: Array[Texture2D] = []

var copy_id := ""
var book_id := ""
var spine_width := WIDTH_MIN
var spine_height := HEIGHT_MIN

## Set by the bookcase before setup. On the back-left wall the shelf falls
## the other way, so the book is drawn from its other side and lines up
## leftward from its anchor instead of rightward.
var mirrored := false

var _base_color := Color.WHITE
var _rest_position := Vector2.ZERO

@onready var _placeholder: Polygon2D = $Placeholder
@onready var _art_slot: Sprite2D = $ArtSlot
@onready var _badge: Polygon2D = $Badge


func setup(copy: Dictionary) -> void:
	copy_id = copy.get("copyId", "")
	book_id = copy.get("bookId", "")

	var seed_value := Palette.hash_id(book_id)
	var variant := seed_value % WIDTH_VARIANTS
	spine_width = WIDTH_MIN + float(variant) * WIDTH_STEP
	spine_height = HEIGHT_MIN + float((seed_value / WIDTH_VARIANTS) % HEIGHT_VARIANTS) * HEIGHT_STEP

	# Falls back to whatever variants exist, so a single drawn spine covers
	# the whole library instead of leaving four fifths as placeholders.
	if not art_variants.is_empty():
		_art_slot.texture = art_variants[variant % art_variants.size()]
	# Books pack by how wide they were actually drawn — the inked part, not
	# the canvas — so art narrower or wider than expected still lines up and
	# an export with a transparent margin does not leave gaps on the shelf.
	if _art_slot.texture != null:
		var content := IsoGrid.content_rect(_art_slot.texture)
		spine_width = content.size.x * IsoGrid.ART_SCALE
		spine_height = content.size.y * IsoGrid.ART_SCALE

	IsoGrid.apply_anchor(_art_slot, _anchor_for_art())
	if mirrored:
		_art_slot.scale.x = -_art_slot.scale.x

	_base_color = Palette.spine_color_for_id(book_id)
	_art_slot.self_modulate = _base_color
	_placeholder.color = _base_color
	_placeholder.visible = _art_slot.texture == null
	var along := shelf_step(spine_width)
	_placeholder.polygon = PackedVector2Array([
		Vector2.ZERO,
		along,
		along + Vector2(0.0, -spine_height),
		Vector2(0.0, -spine_height),
	])
	_badge.position = shelf_step(spine_width * 0.5) + Vector2(0.0, -spine_height)
	_badge.visible = false

	set_trending(GameState.is_trending(book_id))
	set_dusty(OrdersLogic.is_dusty(copy, GameState.state.get("day", 1)))


## A step along this book's own shelf.
func shelf_step(distance: float) -> Vector2:
	return IsoGrid.along_shelf(distance, mirrored)


func _anchor_for_art() -> Vector2:
	if art_anchor != Vector2.ZERO:
		return art_anchor
	return IsoGrid.shelf_anchor(_art_slot.texture)


## Dust reads as a washed-out spine rather than a particle cloud, because at
## this size a cloud would cover the whole book.
func set_dusty(dusty: bool) -> void:
	var tint := _base_color * DUSTY_COLOR if dusty else _base_color
	_art_slot.self_modulate = tint
	_placeholder.color = tint


## Trending books get a small gold mark at the top of the spine.
func set_trending(trending: bool) -> void:
	_badge.visible = trending


## Filtering dims non-matching spines rather than hiding them.
func set_dimmed(dimmed: bool) -> void:
	var target := DIM_COLOR if dimmed else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.15)


## A selected book slides out of the shelf toward the viewer, along the
## ground axis that faces the camera.
func set_selected(selected: bool) -> void:
	if _rest_position == Vector2.ZERO:
		_rest_position = position
	# Out of the shelf means toward the open face, which is the ground axis
	# the bookcase does not run along.
	var axis := IsoGrid.AXIS_X if mirrored else IsoGrid.AXIS_Y
	var out := axis.normalized() * SELECTED_SLIDE
	var target := _rest_position + out if selected else _rest_position
	create_tween().tween_property(self, "position", target, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## World-space rectangle of the spine, used for tap hit-testing. The art is
## a slim quad, so its bounding box is close enough to tap accurately.
func get_world_rect() -> Rect2:
	# The shelf falls away from the anchor, so the box runs from the near
	# end's top down to the far end's base.
	var along := shelf_step(spine_width)
	var corner := global_position + Vector2(minf(0.0, along.x), -spine_height)
	return Rect2(corner, Vector2(absf(along.x), spine_height + along.y))
