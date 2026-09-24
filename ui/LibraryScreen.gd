class_name LibraryScreen
extends Control
## Chrome over the library world: day/acorn/reputation header, tag filter
## chips, and the bottom card that announces the next visitor.

signal filter_changed(tag: String)
signal greet_pressed
signal dismiss_pressed
signal end_day_pressed
signal pick_back_pressed
signal zone_selected(zone: String)

const CHIP_TAG_COUNT := 8

@onready var _day_label: Label = %DayLabel
@onready var _acorn_label: Label = %AcornLabel
@onready var _rep_label: Label = %RepLabel
@onready var _chips: HBoxContainer = %FilterChips
@onready var _portrait: Portrait = %Portrait
@onready var _title_label: Label = %CardTitle
@onready var _name_label: Label = %CardName
@onready var _sub_label: Label = %CardSubtitle
@onready var _action_button: Button = %ActionButton
@onready var _bottom_card: PanelContainer = $BottomCard
@onready var _pick_banner: PanelContainer = %PickBanner
@onready var _pick_request: Label = %PickRequest
@onready var _pick_back_button: Button = %PickBackButton
@onready var _zone_buttons: HBoxContainer = %ZoneButtons
@onready var _nook_button: Button = %NookButton
@onready var _alcove_button: Button = %AlcoveButton

var _at_counter := false


func _ready() -> void:
	GameState.day_changed.connect(_on_value_changed)
	GameState.acorns_changed.connect(_on_value_changed)
	GameState.reputation_changed.connect(_on_value_changed)
	GameState.queue_changed.connect(_refresh_card)
	_action_button.pressed.connect(_on_action_pressed)
	_pick_back_button.pressed.connect(pick_back_pressed.emit)
	_nook_button.pressed.connect(zone_selected.emit.bind(FurnishLogic.NOOK))
	%HallButton.pressed.connect(zone_selected.emit.bind("hall"))
	_alcove_button.pressed.connect(zone_selected.emit.bind(FurnishLogic.ALCOVE))
	GameState.state_loaded.connect(refresh_zone_buttons)
	GameState.state_reset.connect(refresh_zone_buttons)
	_build_filter_chips()
	refresh()
	refresh_zone_buttons()


## Pick mode pins the request at the top and puts the visitor card away,
## so the shelves are what the player is looking at.
func set_pick_mode(enabled: bool, request_text: String = "") -> void:
	_pick_banner.visible = enabled
	_bottom_card.visible = not enabled
	if enabled:
		_zone_buttons.visible = false
	else:
		refresh_zone_buttons()
	_pick_request.text = request_text


func refresh() -> void:
	_refresh_header()
	_refresh_card()


## The zone strip only earns its space once there's somewhere else to go.
func refresh_zone_buttons() -> void:
	var has_nook := FurnishLogic.owns_room(GameState.state, FurnishLogic.NOOK)
	var has_alcove := FurnishLogic.owns_room(GameState.state, FurnishLogic.ALCOVE)
	_zone_buttons.visible = has_nook or has_alcove
	_nook_button.visible = has_nook
	_alcove_button.visible = has_alcove


func set_at_counter(at_counter: bool) -> void:
	_at_counter = at_counter
	_refresh_card()


func set_busy(busy: bool) -> void:
	_action_button.disabled = busy


func _on_value_changed(_value: int) -> void:
	_refresh_header()


func _refresh_header() -> void:
	var state: Dictionary = GameState.state
	_day_label.text = "Day %d" % state.get("day", 1)
	_acorn_label.text = "%d acorns" % state.get("acorns", 0)
	_rep_label.text = "%d rep" % state.get("reputation", 0)


# --- Filter chips ---

func _build_filter_chips() -> void:
	_add_chip("All", "")
	for tag in _common_tags():
		_add_chip(tag, tag)
	_select_chip("")


func _add_chip(label: String, tag: String) -> void:
	var chip := Button.new()
	chip.text = label
	chip.toggle_mode = true
	chip.focus_mode = Control.FOCUS_NONE
	chip.theme_type_variation = &"Chip"
	chip.set_meta("tag", tag)
	chip.pressed.connect(_select_chip.bind(tag))
	_chips.add_child(chip)


func _select_chip(tag: String) -> void:
	for chip in _chips.get_children():
		chip.button_pressed = chip.get_meta("tag") == tag
	filter_changed.emit(tag)


## The tags worth offering as filters: the ones the catalog uses most.
func _common_tags() -> Array:
	var counts := {}
	for id in GameState.books:
		for tag in GameState.books[id].get("tags", []):
			counts[tag] = counts.get(tag, 0) + 1
	var tags: Array = counts.keys()
	tags.sort_custom(func(a, b): return counts[a] > counts[b])
	return tags.slice(0, CHIP_TAG_COUNT)


# --- Bottom card ---

func _refresh_card() -> void:
	var visit: Dictionary = GameState.current_visit()

	if visit.is_empty() and not _at_counter:
		_portrait.visible = false
		_title_label.text = "The library is quiet"
		_name_label.text = ""
		_sub_label.text = "Everyone has gone home for the evening."
		_action_button.text = "End day"
		return

	var customer: Dictionary = GameState.customer_for_visit(visit)
	_portrait.visible = true
	_portrait.setup(customer)
	_name_label.text = customer.get("name", "")
	_sub_label.text = _visit_summary(visit)

	if _at_counter:
		_title_label.text = "At the counter"
		_action_button.text = "Send them off"
	else:
		_title_label.text = "The door chime rings"
		_action_button.text = "Greet"


func _visit_summary(visit: Dictionary) -> String:
	if visit.get("kind") == "return":
		var loan: Dictionary = visit.get("loan", {})
		var book: Dictionary = GameState.books.get(loan.get("bookId", ""), {})
		return "Returning %s" % book.get("title", "a book")
	return visit.get("request", {}).get("text", "")


func _on_action_pressed() -> void:
	if _at_counter:
		dismiss_pressed.emit()
	elif GameState.current_visit().is_empty():
		end_day_pressed.emit()
	else:
		greet_pressed.emit()
