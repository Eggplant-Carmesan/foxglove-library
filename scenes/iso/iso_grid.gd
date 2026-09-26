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
## Alpha at or below which a pixel is not worth tapping.
const ALPHA_HIT := 0.1

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
## side, and a rim of near-nothing inside that. Both are invisible and both
## are real width, so lining pieces up by the canvas spaces them by a margin
## that is not there. Cached, because reading the pixels back costs more
## than the answer is worth to recompute.
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
			rect = _trim_fringe(image, Rect2(used))
	_content_rects[key] = rect
	return rect


## Pulls the edges in past any fringe too faint to see.
##
## An export from a paint app can leave a rim of pixels at an alpha of one
## or two — invisible, but real width as far as get_used_rect is concerned.
## Packing books by that width spaces them apart by a margin of nothing.
static func _trim_fringe(image: Image, rect: Rect2) -> Rect2:
	var left := int(rect.position.x)
	var right := int(rect.end.x) - 1
	var top := int(rect.position.y)
	var bottom := int(rect.end.y) - 1
	while left < right and _column_is_clear(image, left, top, bottom):
		left += 1
	while right > left and _column_is_clear(image, right, top, bottom):
		right -= 1
	while top < bottom and _row_is_clear(image, top, left, right):
		top += 1
	while bottom > top and _row_is_clear(image, bottom, left, right):
		bottom -= 1
	return Rect2(left, top, right - left + 1, bottom - top + 1)


static func _column_is_clear(image: Image, x: int, top: int, bottom: int) -> bool:
	for y in range(top, bottom + 1):
		if image.get_pixel(x, y).a > ALPHA_HIT:
			return false
	return true


static func _row_is_clear(image: Image, y: int, left: int, right: int) -> bool:
	for x in range(left, right + 1):
		if image.get_pixel(x, y).a > ALPHA_HIT:
			return false
	return true


## Whether a texture is actually drawn at a point in its own image.
##
## Pieces stand close enough together that their canvases overlap, so a tap
## has to fall through the transparent corner of the case in front to reach
## the one beside it. Cached like the rects, for the same reason.
static var _images := {}

static func opaque_at(texture: Texture2D, pixel: Vector2) -> bool:
	if texture == null:
		return false
	var size := texture.get_size()
	if pixel.x < 0.0 or pixel.y < 0.0 or pixel.x >= size.x or pixel.y >= size.y:
		return false
	var key := texture.get_rid()
	if not _images.has(key):
		_images[key] = texture.get_image()
	var image: Image = _images[key]
	if image == null:
		return true
	return image.get_pixel(int(pixel.x), int(pixel.y)).a > ALPHA_HIT


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
