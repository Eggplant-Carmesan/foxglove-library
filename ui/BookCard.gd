class_name BookCard
extends Control
## Bottom sheet for one book on the shelf. Slides up over the library scene.

signal closed
signal recommend_pressed(copy_id: String)

const SHEET_TOP := -610.0
const SHEET_BOTTOM := -88.0
const SHEET_TRAVEL := 610.0
const SLIDE_TIME := 0.28

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet: PanelContainer = $Sheet
@onready var _title: Label = %BookTitle
@onready var _author: Label = %BookAuthor
@onready var _tags: HBoxContainer = %BookTags
@onready var _blurb: Label = %BookBlurb
@onready var _stats: Label = %BookStats
@onready var _weed_button: Button = %WeedButton
@onready var _close_button: Button = %CloseButton
@onready var _recommend_button: Button = %RecommendButton

var _copy_id := ""
var _pick_mode := false


func _ready() -> void:
	hide()
	_weed_button.pressed.connect(_on_weed_pressed)
	_close_button.pressed.connect(close)
	_recommend_button.pressed.connect(_on_recommend_pressed)
	_backdrop.gui_input.connect(_on_backdrop_input)


## In pick mode the card offers the book to the waiting customer instead of
## offering to weed it off the shelf.
func set_pick_mode(enabled: bool) -> void:
	_pick_mode = enabled
	_weed_button.visible = not enabled
	_recommend_button.visible = enabled
	_close_button.text = "Keep looking" if enabled else "Close"


func open(copy_id: String) -> void:
	var copy: Dictionary = GameState.shelf_copy(copy_id)
	if copy.is_empty():
		return
	_copy_id = copy_id
	_populate(copy)

	show()
	_sheet.offset_top = SHEET_TOP + SHEET_TRAVEL
	_sheet.offset_bottom = SHEET_BOTTOM + SHEET_TRAVEL
	_backdrop.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sheet, "offset_top", SHEET_TOP, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sheet, "offset_bottom", SHEET_BOTTOM, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_backdrop, "modulate:a", 1.0, SLIDE_TIME)


func close() -> void:
	if not visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sheet, "offset_top", SHEET_TOP + SHEET_TRAVEL, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sheet, "offset_bottom", SHEET_BOTTOM + SHEET_TRAVEL, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_backdrop, "modulate:a", 0.0, SLIDE_TIME)
	await tween.finished
	hide()
	closed.emit()


func _populate(copy: Dictionary) -> void:
	var book_id: String = copy.get("bookId", "")
	var book: Dictionary = GameState.books.get(book_id, {})

	_title.text = book.get("title", "")
	_author.text = book.get("author", "")
	_blurb.text = book.get("blurb", "")

	for chip in _tags.get_children():
		chip.queue_free()
	for tag in book.get("tags", []):
		_tags.add_child(_make_tag_chip(tag))

	var parts: Array[String] = [
		"%d on the shelf" % GameState.copies_on_shelf(book_id),
		"loaned %d times" % GameState.times_loaned(book_id),
	]
	if GameState.is_trending(book_id):
		parts.append("trending")
	if OrdersLogic.is_dusty(copy, GameState.state.get("day", 1)):
		parts.append("dusty")
	_stats.text = " · ".join(parts)

	_weed_button.text = "Weed · +%d acorns" % Tuning.WEED_REFUND


func _make_tag_chip(tag: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"TagChip"
	var label := Label.new()
	label.text = MatchLogic.tag_label(tag)
	label.theme_type_variation = &"TagLabel"
	chip.add_child(label)
	return chip


func _on_weed_pressed() -> void:
	GameState.weed_book(_copy_id)
	close()


func _on_recommend_pressed() -> void:
	var copy_id := _copy_id
	await close()
	recommend_pressed.emit(copy_id)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
