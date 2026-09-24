class_name CustomerSheet
extends Control
## The customer modal: who's at the counter, what they want, what you know
## about their taste, and the ways you can answer them.

signal find_book_pressed
signal hand_over_pressed(copy_id: String)
signal declined
signal suggest_pressed
signal gift_pressed(customer_id: String)

const SHEET_TOP := -448.0
const SHEET_BOTTOM := -88.0
const SHEET_TRAVEL := 448.0
const SLIDE_TIME := 0.28

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet: PanelContainer = $Sheet
@onready var _portrait: Portrait = %BigPortrait
@onready var _name_label: Label = %CustomerName
@onready var _visits_label: Label = %VisitCount
@onready var _request_label: Label = %RequestText
@onready var _tags: HBoxContainer = %TasteTags
@onready var _dialog_label: Label = %DialogLine
@onready var _gift_button: Button = %GiftButton
@onready var _ask_button: Button = %AskButton
@onready var _primary_button: Button = %PrimaryButton
@onready var _secondary_button: Button = %SecondaryButton

var _visit: Dictionary = {}
var _customer_id := ""
var _specific_copy_id := ""


func _ready() -> void:
	hide()
	_portrait.set_frame_size(Vector2(240, 280))
	_portrait.use_light_description()
	_ask_button.pressed.connect(_on_ask_pressed)
	_gift_button.pressed.connect(func() -> void: gift_pressed.emit(_customer_id))
	_primary_button.pressed.connect(_on_primary_pressed)
	_secondary_button.pressed.connect(_on_secondary_pressed)


func open(visit: Dictionary) -> void:
	_visit = visit
	_customer_id = visit.get("customerId", "")
	_dialog_label.text = ""
	_dialog_label.hide()
	_refresh()

	show()
	_sheet.offset_top = SHEET_TOP + SHEET_TRAVEL
	_sheet.offset_bottom = SHEET_BOTTOM + SHEET_TRAVEL
	_backdrop.modulate.a = 0.0
	_portrait.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sheet, "offset_top", SHEET_TOP, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sheet, "offset_bottom", SHEET_BOTTOM, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_backdrop, "modulate:a", 1.0, SLIDE_TIME)
	tween.tween_property(_portrait, "modulate:a", 1.0, SLIDE_TIME)


func close() -> void:
	if not visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sheet, "offset_top", SHEET_TOP + SHEET_TRAVEL, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sheet, "offset_bottom", SHEET_BOTTOM + SHEET_TRAVEL, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_backdrop, "modulate:a", 0.0, SLIDE_TIME)
	tween.tween_property(_portrait, "modulate:a", 0.0, SLIDE_TIME)
	await tween.finished
	hide()


## Re-reads the sheet after a gift changes what the player knows.
func refresh_after_gift() -> void:
	_refresh()


func _refresh() -> void:
	var customer: Dictionary = GameState.customers.get(_customer_id, {})
	var request: Dictionary = _visit.get("request", {})

	_portrait.setup(customer)
	_name_label.text = customer.get("name", "")
	var visits := GameState.visit_count(_customer_id)
	_visits_label.text = "First visit" if visits <= 1 else "Visit %d" % visits
	_request_label.text = request.get("text", "")

	_build_tags(request)
	_refresh_gift_button()

	if RequestLogic.is_specific(request):
		_setup_specific_buttons(request)
	else:
		_setup_open_buttons()


## Discovered likes and dislikes, plus one "? ? ?" chip while any remain
## hidden. A specific request leads with the title they asked for.
func _build_tags(request: Dictionary) -> void:
	for chip in _tags.get_children():
		chip.queue_free()

	if RequestLogic.is_specific(request):
		var title: String = GameState.books.get(request["bookId"], {}).get("title", "")
		_tags.add_child(_make_chip(title, &"HighlightChip"))

	var customer: Dictionary = GameState.customers.get(_customer_id, {})
	for tag in GameState.discovered_tags(_customer_id):
		var disliked: bool = customer.get("dislikes", []).has(tag)
		_tags.add_child(_make_chip(_tag_text(tag, disliked), &"TagChip"))

	if GameState.hidden_tag_count(_customer_id) > 0:
		_tags.add_child(_make_chip("? ? ?", &"HiddenChip"))


func _tag_text(tag: String, disliked: bool) -> String:
	var label := MatchLogic.tag_label(tag)
	return ("no %s" % label) if disliked else label


func _make_chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TagLabel"
	chip.add_child(label)
	return chip


func _refresh_gift_button() -> void:
	var is_regular := _customer_id != "" and not _visit.has("wanderer")
	_gift_button.visible = is_regular
	if not is_regular:
		return
	var gifted := GameState.gifted_today(_customer_id)
	_gift_button.disabled = gifted
	_gift_button.text = "Gifted today" if gifted else "Give a gift"


func _setup_open_buttons() -> void:
	var questions := int(_visit.get("questionsLeft", 0))
	_ask_button.show()
	_ask_button.disabled = questions <= 0
	_ask_button.text = "Ask (%d left)" % questions
	_primary_button.text = "Find a book"
	_secondary_button.hide()


## A named title hides the Ask button; what you can offer depends on whether
## the book is on the shelf, out on loan, or not owned at all.
func _setup_specific_buttons(request: Dictionary) -> void:
	_ask_button.hide()
	_secondary_button.show()
	_secondary_button.text = "Suggest something else"

	var book_id: String = request.get("bookId", "")
	var status := RequestLogic.shelf_status(GameState.state, book_id)
	_specific_copy_id = RequestLogic.first_copy_on_shelf(GameState.state, book_id)

	match status:
		RequestLogic.ON_SHELF:
			_primary_button.text = "Hand it over"
		RequestLogic.OUT:
			_primary_button.text = "Sorry, it's out"
		_:
			_primary_button.text = "We don't have it"


func _on_ask_pressed() -> void:
	var result := GameState.reveal_tag()
	if result.is_empty():
		return
	_dialog_label.text = result.get("line", "")
	_dialog_label.show()
	_build_tags(_visit.get("request", {}))
	_setup_open_buttons()


func _on_primary_pressed() -> void:
	var request: Dictionary = _visit.get("request", {})
	if not RequestLogic.is_specific(request):
		find_book_pressed.emit()
		return
	if _specific_copy_id != "":
		hand_over_pressed.emit(_specific_copy_id)
	else:
		declined.emit()


func _on_secondary_pressed() -> void:
	suggest_pressed.emit()
