class_name BookcaseView
extends Control
## One bookcase seen face on, so the player can read its shelves properly.
##
## The hall shows books as narrow isometric slivers packed against each
## other — enough to tell a full shelf from an empty one, not enough to pick
## from. Tapping a case brings it to the front, at a size worth tapping.
##
## The order is not re-derived here: the case is asked what it is holding,
## and ShelfLayout says which shelf each book stands on, so a book is in the
## same place in both views.

signal book_selected(copy_id: String)
signal closed

const SPINE_SCENE := preload("res://ui/FrontSpine.tscn")
const SPINE_ART := preload("res://art/front/book_spine_front.png")
const CASE_SIZE := Vector2(376.0, 401.0)
## Measured off the case art. The case is drawn in perspective, so each
## plank shows its top surface as a band — four pixels deep at the top
## shelf, sixteen at the bottom one, where you are looking down on it most.
## That gives every plank a back edge and a front edge, and they are not
## the same line.
##
## Books are faced to the FRONT edge, the way a shelf is actually kept. Sat
## on the back edge instead they leave a sliver of the shelf showing under
## them, which reads as floating however carefully the rest is measured.
## Their height is still reckoned from the back, because that is where the
## shelf above is closest.
##
## All three are listed floor shelf first, because that is the order the
## hall's cases list their own planks in. Get that backwards and the two
## views agree on every book except which shelf it is on.
const PLANK_FRONTS: Array[float] = [388.0, 276.0, 180.0, 86.0]
const PLANK_BACKS: Array[float] = [373.0, 264.0, 171.0, 83.0]
const PLANK_CEILINGS: Array[float] = [284.0, 188.0, 94.0, 24.0]
## The back panel's edges, inset so a book never touches the side of the case.
const INNER_LEFT := 23.0
const INNER_RIGHT := 356.0
const BOOK_GAP := 1.0
const FADE_TIME := 0.18

var _bookcase: IsoBookcase = null
## Screen pixels per pixel of the case art.
var _factor := 1.0
var _spines: Array[FrontSpine] = []
var _selected: FrontSpine = null
## The fade currently running, so open and close cannot leave each other
## half done. A close that lost its race would hide a view the player had
## just reopened; an open that lost one would leave a fully transparent
## sheet over the hall, still swallowing every drag meant for the camera.
var _fade: Tween = null

@onready var _backdrop: ColorRect = $Backdrop
@onready var _stage: Control = $Stage
@onready var _case: Control = %Case
@onready var _books: Control = %Books
@onready var _title: Label = %CaseTitle
@onready var _pick_banner: PanelContainer = %PickBanner
@onready var _pick_request: Label = %PickRequest
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)
	_backdrop.gui_input.connect(_on_backdrop_input)
	_stage.resized.connect(_layout_case)


func open(bookcase: IsoBookcase, index: int, filter_tag: String = "") -> void:
	_bookcase = bookcase
	_title.text = "Bookcase %d" % (index + 1)
	# Sized before it is filled, because a book's size — and so its title's
	# type size — is worked out from the room the case has been given.
	_layout_case()
	_build(filter_tag)

	show()
	modulate.a = 0.0
	_fade = _restart_fade()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)


func close() -> void:
	if not visible:
		return
	var tween := _restart_fade()
	_fade = tween
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	# Another open may have come along behind this fade, in which case the
	# view is wanted after all and must not be torn down.
	if _fade != tween:
		return
	hide()
	modulate.a = 1.0
	_bookcase = null
	closed.emit()


## Pick mode keeps the request in front of the player while they browse,
## because the hall's own banner is behind this view.
func set_pick_mode(enabled: bool, request_text: String = "") -> void:
	_pick_banner.visible = enabled
	_pick_request.text = request_text


## The shelf can change while the view is open — weeding a book from its
## card drops the player back onto these shelves. Runs after the hall has
## refreshed the case, so the case's copies are already current.
func refresh(filter_tag: String = "") -> void:
	if visible:
		_build(filter_tag)


# --- Laying out the shelves ---

func _build(filter_tag: String) -> void:
	for spine in _spines:
		_books.remove_child(spine)
		spine.queue_free()
	_spines.clear()
	_selected = null
	if _bookcase == null:
		return

	var per_plank: int = _bookcase.slots_per_plank
	var planks := mini(_bookcase.plank_starts.size(), PLANK_FRONTS.size())
	var copies: Array = _bookcase.copies
	var counts := ShelfLayout.plank_counts(copies.size(), planks, per_plank)
	var day: int = GameState.state.get("day", 1)

	for plank in planks:
		var first := ShelfLayout.first_on_plank(plank, per_plank)
		for slot in counts[plank]:
			var copy: Dictionary = copies[first + slot]
			var spine: FrontSpine = SPINE_SCENE.instantiate()
			_books.add_child(spine)
			spine.plank = plank
			spine.setup(copy, SPINE_ART)
			spine.set_dusty(OrdersLogic.is_dusty(copy, day))
			spine.set_trending(GameState.is_trending(spine.book_id))
			spine.set_dimmed(_filtered_out(spine.book_id, filter_tag))
			spine.pressed.connect(_on_spine_pressed.bind(spine))
			_spines.append(spine)
	_place_books()


## Books are measured and stood up in screen pixels rather than laid out in
## the art's pixels and magnified afterwards, so their titles are drawn at
## the size they are read at instead of being blown up and going soft.
func _place_books() -> void:
	var row: Array[FrontSpine] = []
	for spine in _spines:
		if not row.is_empty() and spine.plank != row[0].plank:
			_stand_row(row)
			row = []
		spine.fit(_clear_height(spine.plank))
		row.append(spine)
	if not row.is_empty():
		_stand_row(row)


## How much room a plank has above it, measured at the back of the shelf,
## where whatever is above comes closest.
func _clear_height(plank: int) -> float:
	return (PLANK_BACKS[plank] - PLANK_CEILINGS[plank]) * _factor


## Books lean together from the end of the shelf their case fills from, and
## a shelf with room to spare keeps the room. That is what a library still
## being filled looks like, and it is honest about how full the case is.
func _stand_row(row: Array[FrontSpine]) -> void:
	var mirrored: bool = _bookcase.mirrored
	var baseline := PLANK_FRONTS[row[0].plank] * _factor
	var left := INNER_LEFT * _factor
	var right := INNER_RIGHT * _factor
	var gap := BOOK_GAP * _factor
	var needed := 0.0
	for spine in row:
		needed += spine.size.x + gap
	# A shelf packed past its width closes up rather than spilling out of the
	# case: crowded books overlap, which is how crowded books really sit.
	var squeeze := minf(1.0, (right - left) / maxf(needed, 1.0))
	var cursor := right if mirrored else left
	for spine in row:
		spine.stand_at(cursor, baseline, mirrored)
		var advance := (spine.size.x + gap) * squeeze
		cursor += -advance if mirrored else advance


## The case is drawn at whatever size the space between the title and the
## button allows, so one set of measured shelf positions serves every screen.
func _layout_case() -> void:
	var room := _stage.size
	if room.x <= 0.0 or room.y <= 0.0:
		return
	_factor = minf(room.x / CASE_SIZE.x, room.y / CASE_SIZE.y)
	_case.size = CASE_SIZE * _factor
	_case.position = (room - _case.size) * 0.5
	_place_books()


func _filtered_out(book_id: String, tag: String) -> bool:
	if tag == "":
		return false
	var book: Dictionary = GameState.books.get(book_id, {})
	return not book.get("tags", []).has(tag)


# --- Selection ---

func _on_spine_pressed(spine: FrontSpine) -> void:
	clear_selection()
	_selected = spine
	spine.set_selected(true)
	book_selected.emit(spine.copy_id)


func clear_selection() -> void:
	if _selected != null:
		_selected.set_selected(false)
		_selected = null


func _restart_fade() -> Tween:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	return create_tween()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
