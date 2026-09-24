class_name Spine
extends Node2D
## One book copy on a shelf. Origin sits at the spine's bottom-left corner,
## so a bookcase can line spines up along a plank without knowing their size.
## Width and height are seeded from the book id so a book always looks the
## same; real art drops into the ArtSlot sprite without touching this code.

const WIDTH_MIN := 30.0
const WIDTH_STEP := 4.0
const WIDTH_VARIANTS := 4
const HEIGHT_MIN := 240.0
const HEIGHT_STEP := 14.0
const HEIGHT_VARIANTS := 6

const DIM_COLOR := Color(0.4, 0.42, 0.4, 1.0)
const SELECTED_LIFT := 26.0
const SELECTED_TILT := -0.14

var copy_id := ""
var book_id := ""
var spine_width := WIDTH_MIN
var spine_height := HEIGHT_MIN

@onready var _body: ColorRect = $Body
@onready var _title: Label = $TitleLabel
@onready var _badge: ColorRect = $TrendingBadge
@onready var _dust: GPUParticles2D = $Dust
@onready var _sparkle: AnimationPlayer = $Sparkle


func setup(copy: Dictionary) -> void:
	copy_id = copy.get("copyId", "")
	book_id = copy.get("bookId", "")
	var book: Dictionary = GameState.books.get(book_id, {})

	var seed_value := Palette.hash_id(book_id)
	spine_width = WIDTH_MIN + float(seed_value % WIDTH_VARIANTS) * WIDTH_STEP
	spine_height = HEIGHT_MIN + float((seed_value / WIDTH_VARIANTS) % HEIGHT_VARIANTS) * HEIGHT_STEP

	_body.offset_top = -spine_height
	_body.offset_right = spine_width
	_body.color = Palette.spine_color_for_id(book_id)

	_title.position = Vector2.ZERO
	_title.size = Vector2(spine_height, spine_width)
	_title.text = book.get("title", "")

	_badge.position = Vector2(spine_width * 0.5 - 7.0, -spine_height + 12.0)
	_dust.position = Vector2(spine_width * 0.5, -spine_height * 0.5)

	set_trending(GameState.is_trending(book_id))
	set_dusty(OrdersLogic.is_dusty(copy, GameState.state.get("day", 1)))


## Books not loaned in a while drift dust off their spine.
func set_dusty(dusty: bool) -> void:
	_dust.emitting = dusty


## Trending books get a slow gold sparkle on the spine.
func set_trending(trending: bool) -> void:
	_badge.visible = trending
	if trending:
		_sparkle.play("sparkle")
	else:
		_sparkle.stop()


## Filtering dims non-matching spines rather than hiding them.
func set_dimmed(dimmed: bool) -> void:
	var target := DIM_COLOR if dimmed else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.15)


## Selected spines slide out of the shelf and tilt toward the camera.
func set_selected(selected: bool) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", -SELECTED_LIFT if selected else 0.0, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", SELECTED_TILT if selected else 0.0, 0.2)


## World-space rectangle of the spine, used for tap hit-testing.
func get_world_rect() -> Rect2:
	return Rect2(global_position - Vector2(0.0, spine_height), Vector2(spine_width, spine_height))
