class_name LibraryScreen
extends Control
## Chrome over the library world: day/acorn/reputation header, tag filter
## chips, and the door chime that says how many visitors are waiting.

signal filter_changed(tag: String)
signal greet_pressed
signal end_day_pressed
signal pick_back_pressed
signal zone_selected(zone: String)

const CHIP_TAG_COUNT := 8

@onready var _day_label: Label = %DayLabel
@onready var _acorn_label: Label = %AcornLabel
@onready var _rep_label: Label = %RepLabel
@onready var _chips: HBoxContainer = %FilterChips
@onready var _bell: VisitorBell = %VisitorBell
@onready var _end_day_button: Button = %EndDayButton
@onready var _arrival_hint: Label = %ArrivalHint
@onready var _pick_banner: PanelContainer = %PickBanner
@onready var _pick_request: Label = %PickRequest
@onready var _pick_back_button: Button = %PickBackButton
@onready var _zone_buttons: HBoxContainer = %ZoneButtons
@onready var _nook_button: Button = %NookButton
@onready var _alcove_button: Button = %AlcoveButton

var _pick_mode := false
var _busy := false


func _ready() -> void:
	GameState.day_changed.connect(_on_value_changed)
	GameState.acorns_changed.connect(_on_value_changed)
	GameState.reputation_changed.connect(_on_value_changed)
	GameState.queue_changed.connect(_refresh_visitors)
	_bell.pressed.connect(_on_bell_pressed)
	_end_day_button.pressed.connect(end_day_pressed.emit)
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
	_pick_mode = enabled
	_pick_banner.visible = enabled
	if enabled:
		_zone_buttons.visible = false
	else:
		refresh_zone_buttons()
	_pick_request.text = request_text
	_refresh_visitors()


func refresh() -> void:
	_refresh_header()
	_refresh_visitors()


## The zone strip only earns its space once there's somewhere else to go.
func refresh_zone_buttons() -> void:
	var has_nook := FurnishLogic.owns_room(GameState.state, FurnishLogic.NOOK)
	var has_alcove := FurnishLogic.owns_room(GameState.state, FurnishLogic.ALCOVE)
	_zone_buttons.visible = has_nook or has_alcove
	_nook_button.visible = has_nook
	_alcove_button.visible = has_alcove


func set_busy(busy: bool) -> void:
	_busy = busy
	_refresh_visitors()


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


# --- Visitors ---

## The chime only counts; nobody comes in until the player asks them to.
func _refresh_visitors() -> void:
	var waiting: int = GameState.state.get("queue", []).size()
	var expected := GameState.pending_arrivals()
	var rang := _bell.set_count(waiting)
	var quiet := waiting == 0 and not _pick_mode and not _busy

	_bell.visible = waiting > 0 and not _pick_mode
	_bell.disabled = _busy
	_end_day_button.visible = quiet
	_end_day_button.text = "End day early" if expected > 0 else "End day"

	# During a lull, say whether anyone else is expected before closing up.
	_arrival_hint.visible = quiet and expected > 0
	_arrival_hint.text = "%d more expected today" % expected

	if rang and _bell.visible:
		_bell.ring()


func _on_bell_pressed() -> void:
	if not _busy:
		greet_pressed.emit()
