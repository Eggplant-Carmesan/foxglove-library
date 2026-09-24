extends Node2D
## Shell that owns the library world, the tab screens and the sheet layer,
## and wires them to each other. Orders, Journal and Furnish are still
## placeholders; they arrive in later build steps.

const REACTION_HOLD := 1.5

@onready var _library: Library = $Library
@onready var _library_screen: LibraryScreen = %LibraryScreen
@onready var _placeholder: Control = %PlaceholderScreen
@onready var _placeholder_label: Label = %PlaceholderLabel
@onready var _tab_bar := %TabBar
@onready var _book_card: BookCard = %BookCard
@onready var _customer_sheet: CustomerSheet = %CustomerSheet
@onready var _return_sheet: ReturnSheet = %ReturnSheet
@onready var _orders_screen: OrdersScreen = %OrdersScreen
@onready var _journal_screen: JournalScreen = %JournalScreen
@onready var _day_summary: DaySummary = %DaySummary
@onready var _furnish_screen: FurnishScreen = %FurnishScreen
@onready var _gift_picker: GiftPicker = %GiftPicker


func _ready() -> void:
	_tab_bar.tab_selected.connect(_on_tab_selected)
	_library.spine_selected.connect(_book_card.open)
	_book_card.closed.connect(_library.clear_selection)
	_book_card.recommend_pressed.connect(_on_recommend)
	_library_screen.filter_changed.connect(_library.apply_filter)
	_library_screen.greet_pressed.connect(_on_greet_pressed)
	_library_screen.dismiss_pressed.connect(_on_dismiss_pressed)
	_library_screen.end_day_pressed.connect(_on_end_day_pressed)
	_library_screen.pick_back_pressed.connect(_on_pick_back_pressed)
	_library_screen.zone_selected.connect(_on_zone_selected)
	_customer_sheet.find_book_pressed.connect(_on_find_book_pressed)
	_customer_sheet.hand_over_pressed.connect(_on_hand_over)
	_customer_sheet.declined.connect(_on_declined)
	_customer_sheet.suggest_pressed.connect(_on_suggest)
	_return_sheet.done_pressed.connect(_on_return_done)
	_orders_screen.weed_link_pressed.connect(_on_weed_link_pressed)
	_day_summary.open_up_pressed.connect(_on_open_up_pressed)
	_furnish_screen.room_bought.connect(_on_room_bought)
	_furnish_screen.decor_changed.connect(_library.refresh_decor)
	_customer_sheet.gift_pressed.connect(_gift_picker.open)
	_journal_screen.gift_requested.connect(_gift_picker.open)
	_gift_picker.gift_given.connect(_on_gift_given)
	_on_tab_selected("Library")


func _on_tab_selected(tab_name: String) -> void:
	var is_library := tab_name == "Library"
	var is_orders := tab_name == "Orders"
	var is_journal := tab_name == "Journal"
	var is_furnish := tab_name == "Furnish"
	_library.visible = is_library
	_library_screen.visible = is_library
	_orders_screen.visible = is_orders
	_journal_screen.visible = is_journal
	_furnish_screen.visible = is_furnish
	_placeholder.visible = false


func _on_zone_selected(zone: String) -> void:
	_library.pan_to_zone(zone)


## A new room opens with its own animation, so the player is taken to the
## shelves to watch the boards come down.
func _on_room_bought(room: String) -> void:
	_tab_bar.select_tab("Library")
	await get_tree().process_frame
	_library.refresh_zones(room)
	_library_screen.refresh_zone_buttons()


## The visitor reacts to their present if they're standing at the counter.
func _on_gift_given(_customer_id: String, result: Dictionary) -> void:
	_journal_screen.refresh()
	if _customer_sheet.visible:
		_customer_sheet.refresh_after_gift()
	_library.visitor_say(result.get("line", ""))


## The warning banner's way out: go to the shelves, where weeding happens.
func _on_weed_link_pressed() -> void:
	_tab_bar.select_tab("Library")


# --- Greeting ---

func _on_greet_pressed() -> void:
	var visit := GameState.current_visit()
	if visit.is_empty():
		return
	_library_screen.set_busy(true)
	await _library.greet_visitor(GameState.customer_for_visit(visit))
	_library_screen.set_busy(false)

	if visit.get("kind") == "request":
		GameState.note_visit(visit.get("customerId", ""))
		_customer_sheet.open(visit)
	else:
		var result := GameState.resolve_return(visit)
		_library.set_visitor_mood(GameState.mood_for_hearts(result.get("hearts", 3)))
		_return_sheet.open(result)


func _on_return_done() -> void:
	await _send_off("")


func _on_dismiss_pressed() -> void:
	_library_screen.set_busy(true)
	await _library.dismiss_visitor()
	GameState.dequeue_visit()
	_library_screen.set_at_counter(false)
	_library_screen.set_busy(false)


# --- Pick mode ---

func _on_find_book_pressed() -> void:
	await _customer_sheet.close()
	_enter_pick_mode()


func _on_suggest() -> void:
	await _customer_sheet.close()
	GameState.suggest_fallback()
	_enter_pick_mode()


func _enter_pick_mode() -> void:
	var request: Dictionary = GameState.current_visit().get("request", {})
	_library_screen.set_pick_mode(true, request.get("text", ""))
	_book_card.set_pick_mode(true)


func _exit_pick_mode() -> void:
	_library_screen.set_pick_mode(false)
	_book_card.set_pick_mode(false)


func _on_pick_back_pressed() -> void:
	_exit_pick_mode()
	_customer_sheet.open(GameState.current_visit())


# --- Resolving the visit ---

func _on_recommend(copy_id: String) -> void:
	var result := GameState.recommend(copy_id)
	await _send_off(result.get("line", ""), result.get("bookId", ""))


func _on_hand_over(copy_id: String) -> void:
	await _customer_sheet.close()
	var result := GameState.hand_over(copy_id)
	await _send_off(result.get("line", ""), result.get("bookId", ""))


func _on_declined() -> void:
	await _customer_sheet.close()
	var result := GameState.decline_specific()
	_library.set_visitor_mood("sad")
	await _send_off(result.get("line", ""))


## The visitor reacts, then walks out with whatever they were lent.
func _send_off(line: String, carried_book_id: String = "") -> void:
	_exit_pick_mode()
	_library_screen.set_at_counter(false)
	if line != "":
		_library.visitor_say(line)
		await get_tree().create_timer(REACTION_HOLD).timeout
	await _library.dismiss_visitor(carried_book_id)


## Closing up shows the day's tally; the next day starts when the player
## opens up again.
func _on_end_day_pressed() -> void:
	_day_summary.open()


func _on_open_up_pressed() -> void:
	GameState.start_day()
