class_name OrdersScreen
extends Control
## The Orders tab: what today's catalog offers, what it would cost, and
## whether there's room and money for it.

signal weed_link_pressed

const ROW_SCENE := preload("res://ui/CatalogRow.tscn")

## Popularity 1-5 as something the librarian would actually say.
const DEMAND_HINTS := {
	5: "Everyone is asking for it",
	4: "Often asked for",
	3: "Steady interest",
	2: "The occasional request",
	1: "Rarely asked for",
}

@onready var _acorn_value: Label = %AcornValue
@onready var _shelf_value: Label = %ShelfValue
@onready var _warning: PanelContainer = %Warning
@onready var _warning_label: Label = %WarningLabel
@onready var _weed_button: Button = %WeedLinkButton
@onready var _rows: VBoxContainer = %CatalogRows
@onready var _place_button: Button = %PlaceOrderButton

var _selected: Array[String] = []


func _ready() -> void:
	_place_button.pressed.connect(_on_place_pressed)
	_weed_button.pressed.connect(weed_link_pressed.emit)
	GameState.day_changed.connect(_on_day_changed)
	GameState.state_loaded.connect(refresh)
	GameState.state_reset.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func _on_day_changed(_day: int) -> void:
	_selected.clear()
	refresh()


func refresh() -> void:
	_build_rows()
	_refresh_totals()


# --- Catalog ---

func _build_rows() -> void:
	for row in _rows.get_children():
		row.queue_free()

	var pending: Array = GameState.state.get("pendingOrder", [])
	for book_id in GameState.state.get("catalogToday", []):
		var book: Dictionary = GameState.books.get(book_id, {})
		if book.is_empty():
			continue
		var row: CatalogRow = ROW_SCENE.instantiate()
		_rows.add_child(row)
		row.setup(book, _demand_hint(book_id, book), GameState.is_trending(book_id))
		if pending.has(book_id):
			row.set_ordered()
		else:
			row.set_added(_selected.has(book_id))
		row.add_toggled.connect(_on_row_toggled)


## A customer asking for a title by name outranks the general demand.
func _demand_hint(book_id: String, book: Dictionary) -> String:
	var asked_by: String = GameState.state.get("demandHints", {}).get(book_id, "")
	if asked_by != "":
		return "%s asked for this" % asked_by
	return DEMAND_HINTS.get(int(book.get("popularity", 1)), "")


func _on_row_toggled(book_id: String, added: bool) -> void:
	if added and not _selected.has(book_id):
		_selected.append(book_id)
	elif not added:
		_selected.erase(book_id)
	_refresh_totals()


# --- Totals, warnings and placing the order ---

func _refresh_totals() -> void:
	var state: Dictionary = GameState.state
	var acorns: int = state.get("acorns", 0)
	var cost := OrdersLogic.order_cost(_selected, GameState.books)
	var on_shelf: int = state.get("shelf", []).size()
	var incoming: int = state.get("pendingOrder", []).size() + _selected.size()
	var capacity := GameState.shelf_capacity()

	_acorn_value.text = "%d" % acorns if cost == 0 else "%d → %d" % [acorns, acorns - cost]
	_shelf_value.text = "%d / %d" % [on_shelf, capacity] if incoming == 0 \
		else "%d + %d / %d" % [on_shelf, incoming, capacity]

	var over_budget := cost > acorns
	var over_space := on_shelf + incoming > capacity
	_warning.visible = over_budget or over_space
	if over_space:
		_warning_label.text = "Not enough shelf space. Weed something to make room."
	elif over_budget:
		_warning_label.text = "That's more acorns than you have."
	_weed_button.visible = over_space

	_place_button.disabled = _selected.is_empty() or over_budget or over_space
	_place_button.text = "Place order" if _selected.is_empty() \
		else "Place order · %d %s · %d acorns" % [
			_selected.size(), "book" if _selected.size() == 1 else "books", cost,
		]


func _on_place_pressed() -> void:
	if not GameState.place_order(_selected):
		return
	_selected.clear()
	refresh()
