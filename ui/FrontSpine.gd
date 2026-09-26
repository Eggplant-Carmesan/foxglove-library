class_name FrontSpine
extends TextureButton
## One book in the front-on bookcase view: a spine seen face on, tall enough
## to read and wide enough to tap, with its title printed down it.
##
## Art is painted white and tinted from the book id, the same way the hall's
## isometric spines are, so a book is the same colour whichever view it is
## seen in.

## How much of a shelf's clear height the shortest book fills, and how much
## each size variant adds. Books are scaled whole rather than stretched, so
## a taller book is a thicker one too — which is how a shelf really looks.
const HEIGHT_FILL := 0.74
const HEIGHT_STEP := 0.05

const DIM_COLOR := Color(0.4, 0.42, 0.4, 1.0)
const DUSTY_COLOR := Color(0.78, 0.76, 0.7, 1.0)
## How far a selected book lifts out of the shelf, as a share of its height.
const SELECTED_LIFT := 0.05

## The printed area of the spine: how far in from each long edge the type
## sits, and where down the spine it starts and stops.
const TITLE_SIDE := 0.09
const TITLE_TOP := 0.06
const TITLE_END := 0.84
## Type size as a share of the spine's width. Set so two wrapped lines fit
## between the edges, which covers all but the longest titles in the
## catalogue; anything longer is trimmed and the card has it in full.
const TITLE_SIZE := 0.23
const TITLE_SIZE_MIN := 11

## A trending book wears a gilt band at the foot of its spine, clear of the
## type rather than across it.
const BADGE_HEIGHT := 0.05
const BADGE_FOOT := 0.90

## Which plank of its case this book stands on. Set by the view before setup.
var plank := 0

var copy_id := ""
var book_id := ""

var _base_color := Color.WHITE
var _aspect := 0.5
var _variant := 0
var _rest_y := 0.0

@onready var _badge: ColorRect = $Badge
@onready var _title: Label = $Title


func setup(copy: Dictionary, art: Texture2D) -> void:
	copy_id = copy.get("copyId", "")
	book_id = copy.get("bookId", "")

	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_SCALE

	# The drawn part, not the canvas. A button stretches whatever texture it
	# is given across its whole rect, so handing it the raw art would draw
	# the export's transparent margin as a gap beside and underneath every
	# book — the books would stand apart, and hover above their shelf.
	var content := IsoGrid.content_rect(art)
	var trimmed := AtlasTexture.new()
	trimmed.atlas = art
	trimmed.region = content
	texture_normal = trimmed
	_aspect = content.size.x / maxf(content.size.y, 1.0)
	_variant = (Palette.hash_id(book_id) / IsoSpine.WIDTH_VARIANTS) % IsoSpine.HEIGHT_VARIANTS

	_base_color = Palette.spine_color_for_id(book_id)
	self_modulate = _base_color
	_title.text = GameState.books.get(book_id, {}).get("title", "")
	_badge.visible = false


## Sizes the book to the shelf it stands on, in screen pixels. `shelf_height`
## is that shelf's clear height in the same units.
func fit(shelf_height: float) -> void:
	var height := shelf_height * (HEIGHT_FILL + HEIGHT_STEP * float(_variant))
	size = Vector2(height * _aspect, height)
	_badge.size = Vector2(size.x, maxf(size.y * BADGE_HEIGHT, 1.0))
	_badge.position = Vector2(0.0, size.y * BADGE_FOOT)
	_lay_out_title()


## Stands the book on a plank with its left edge at `along`. Mirrored cases
## fill from the other end, so there `along` is the book's right edge.
func stand_at(along: float, baseline: float, mirrored: bool) -> void:
	position = Vector2(along - size.x if mirrored else along, baseline - size.y)
	_rest_y = position.y


## The title is set across the spine and then turned a quarter turn, so it
## reads from the head of the book down — the way a shelf of English spines
## reads.
##
## A Control turns about its own top-left corner, which swings its box round
## to the left of that corner. So the label is anchored a band's width in
## from where the type should start, and lands back over the spine.
func _lay_out_title() -> void:
	var band := size.x * (1.0 - TITLE_SIDE * 2.0)
	var run := size.y * (TITLE_END - TITLE_TOP)
	_title.rotation = PI * 0.5
	_title.size = Vector2(run, band)
	_title.position = Vector2(size.x * TITLE_SIDE + band, size.y * TITLE_TOP)
	_title.add_theme_font_size_override(
		&"font_size", maxi(int(size.x * TITLE_SIZE), TITLE_SIZE_MIN))


## Dust reads as a washed-out spine, matching the hall.
func set_dusty(dusty: bool) -> void:
	self_modulate = _base_color * DUSTY_COLOR if dusty else _base_color


## Trending books wear a gilt band across the spine.
func set_trending(trending: bool) -> void:
	_badge.visible = trending


func set_dimmed(dimmed: bool) -> void:
	var target := DIM_COLOR if dimmed else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.15)


## The book the card is open on lifts clear of its neighbours, so it is
## obvious which one is being read about.
func set_selected(selected: bool) -> void:
	var target := _rest_y - size.y * SELECTED_LIFT if selected else _rest_y
	create_tween().tween_property(self, "position:y", target, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
