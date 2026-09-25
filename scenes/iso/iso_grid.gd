class_name IsoGrid
extends RefCounted
## True 30-degree isometric maths, and the anchor convention every piece
## shares.
##
## Art is drawn at 2x and scaled down in game, and each sprite's origin is
## the centre of its footprint diamond — the point where it meets the floor.
##
## 74 / 128 puts the ground axes at 30.03 degrees, which matches Procreate's
## Isometric drawing guide closely enough to trace against.

## In-game tile size. Art for one tile is drawn at twice this.
const TILE := Vector2(128.0, 74.0)
## Rise over run along a ground axis — tan(30 degrees).
const AXIS_SLOPE := TILE.y / TILE.x
const ART_SCALE := 0.5

## Walking one tile along the shelf axis, in screen pixels.
const AXIS_X := Vector2(TILE.x * 0.5, TILE.y * 0.5)
const AXIS_Y := Vector2(-TILE.x * 0.5, TILE.y * 0.5)


## Tile coordinates to the screen position of that tile's centre.
static func tile_to_world(tile: Vector2) -> Vector2:
	return AXIS_X * tile.x + AXIS_Y * tile.y


static func world_to_tile(point: Vector2) -> Vector2:
	return Vector2(
		point.x / TILE.x + point.y / TILE.y,
		point.y / TILE.y - point.x / TILE.x,
	)


## A step of `distance` horizontal pixels along a shelf.
##
## A shelf lies along one of the two ground axes, so it always falls as it
## goes: on the back-right wall it falls to the right, on the back-left wall
## it falls to the left. Either way a book further along a shelf sits lower
## on screen, which is what puts it in front for sorting.
static func along_shelf(distance: float, to_the_left: bool = false) -> Vector2:
	var run := -distance if to_the_left else distance
	return Vector2(run, distance * AXIS_SLOPE)


## Nearest grid position to an arbitrary point.
##
## Half a tile is the default because it is the finest step that still
## reads as deliberate: it gives the middle of a tile, its back edge and
## its front, which covers furniture against a wall, furniture in the open,
## and anything meant to straddle two tiles. Pass 1.0 for tile centres
## only, or a smaller step for fine work.
static func snap(point: Vector2, step: float = 0.5) -> Vector2:
	var tile := world_to_tile(point)
	return tile_to_world(Vector2(
		roundf(tile.x / step) * step,
		roundf(tile.y / step) * step,
	))


## Where a piece's ground point sits inside its own image.
##
## Every template in art/templates puts the footprint's front corner at the
## bottom centre of the canvas, so the ground point is half a tile up from
## there. Art drawn on a template needs no measuring — its own size gives
## the anchor away. Art drawn without one can still override by hand.
##
## The art diamond is twice TILE, so half its height is TILE.y exactly — and
## a footprint that is deeper than one tile dips proportionally further.
static func anchor_for(texture: Texture2D, depth_tiles: float = 1.0) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var size := texture.get_size()
	return Vector2(size.x * 0.5, size.y - TILE.y * depth_tiles)


## The drawn part of a texture, ignoring any transparent margin around it.
##
## Exporting from a paint app usually leaves a few pixels of nothing on each
## side. That margin is invisible but it is real width, and lining pieces up
## by the canvas would space them by it. Cached, because reading the pixels
## back costs more than the answer is worth to recompute.
static var _content_rects := {}

static func content_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var key := texture.get_rid()
	if _content_rects.has(key):
		return _content_rects[key]
	var rect := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	_content_rects[key] = rect
	return rect


## Where a piece standing on a shelf meets the plank: its front-bottom
## corner, which is the lowest drawn pixel in its leftmost drawn column.
##
## Not simply the bottom of the image. A book drawn in isometric has a
## bottom edge that falls away to the right, so the lowest pixel overall is
## the far corner — anchoring there would sink the book into the shelf.
static var _shelf_anchors := {}

static func shelf_anchor(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var key := texture.get_rid()
	if _shelf_anchors.has(key):
		return _shelf_anchors[key]

	var content := content_rect(texture)
	var anchor := Vector2(content.position.x, content.end.y)
	var image := texture.get_image()
	if image != null:
		var x := int(content.position.x)
		var y := int(content.end.y) - 1
		while y >= int(content.position.y):
			if image.get_pixel(x, y).a > 0.02:
				anchor = Vector2(float(x), float(y + 1))
				break
			y -= 1
	_shelf_anchors[key] = anchor
	return anchor


## Hangs a sprite off its footprint centre, so setting the node's position
## places the art exactly where the object stands.
static func apply_anchor(sprite: Sprite2D, anchor: Vector2, scale_factor: float = ART_SCALE) -> void:
	sprite.centered = false
	sprite.offset = -anchor
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.visible = sprite.texture != null
