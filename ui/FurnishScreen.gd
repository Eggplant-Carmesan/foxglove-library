class_name FurnishScreen
extends Control
## The Furnish tab: shelf space, the two rooms, and the decor that decides
## who comes through the door.

signal room_bought(room: String)
signal decor_changed

@onready var _capacity: Label = %CapacityValue
@onready var _bookcase_price: Label = %BookcasePrice
@onready var _bookcase_button: Button = %BuyBookcaseButton
@onready var _rooms_box: VBoxContainer = %RoomList
@onready var _slots_label: Label = %DecorSlots
@onready var _decor_box: VBoxContainer = %DecorList


func _ready() -> void:
	_bookcase_button.pressed.connect(_on_buy_bookcase)
	GameState.acorns_changed.connect(_on_value_changed)
	GameState.reputation_changed.connect(_on_value_changed)
	GameState.state_reset.connect(refresh)
	GameState.state_loaded.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func _on_value_changed(_value: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	_refresh_bookcases()
	_refresh_rooms()
	_refresh_decor()


# --- Bookcases ---

func _refresh_bookcases() -> void:
	var state: Dictionary = GameState.state
	_capacity.text = "%d of %d slots used" % [state.get("shelf", []).size(), GameState.shelf_capacity()]
	if FurnishLogic.bookcases_maxed(state):
		_bookcase_price.text = "The walls are full."
		_bookcase_button.disabled = true
		_bookcase_button.text = "No room left"
		return
	var price := FurnishLogic.bookcase_price(state)
	_bookcase_price.text = "Another bookcase adds %d slots." % Tuning.SHELF_SLOTS_PER_BOOKCASE
	_bookcase_button.disabled = not FurnishLogic.can_buy_bookcase(state)
	_bookcase_button.text = "Buy · %d acorns" % price


func _on_buy_bookcase() -> void:
	if not FurnishLogic.buy_bookcase(GameState.state):
		return
	GameState.save_game()
	GameState.acorns_changed.emit(GameState.state["acorns"])
	GameState.shelf_changed.emit()
	refresh()


# --- Rooms ---

func _refresh_rooms() -> void:
	for row in _rooms_box.get_children():
		row.queue_free()
	for room in FurnishLogic.ROOMS:
		_rooms_box.add_child(_build_room_row(room))


func _build_room_row(room: String) -> PanelContainer:
	var state: Dictionary = GameState.state
	var info: Dictionary = FurnishLogic.ROOMS[room]
	var card := PanelContainer.new()
	card.theme_type_variation = &"ParchmentPanel"

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var title := Label.new()
	title.theme_type_variation = &"InkHeading"
	title.text = info["name"]
	column.add_child(title)

	var blurb := Label.new()
	blurb.theme_type_variation = &"MutedLabel"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = _room_blurb(room)
	column.add_child(blurb)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if FurnishLogic.owns_room(state, room):
		button.text = "Open"
		button.disabled = true
	elif not FurnishLogic.room_available(state, room):
		button.text = "Needs %d reputation" % int(info["unlockAtRep"])
		button.disabled = true
	else:
		button.text = "Buy · %d acorns" % int(info["cost"])
		button.disabled = not FurnishLogic.can_buy_room(state, room)
		button.pressed.connect(_on_buy_room.bind(room))
	column.add_child(button)
	return card


func _room_blurb(room: String) -> String:
	if room == FurnishLogic.NOOK:
		return "Two more decor slots and one more visitor a day. Short books can be read here and come straight back."
	return "Two more decor slots, rare books in the catalogue, and a collector who only wants those."


func _on_buy_room(room: String) -> void:
	if not FurnishLogic.buy_room(GameState.state, room):
		return
	GameState.save_game()
	GameState.acorns_changed.emit(GameState.state["acorns"])
	room_bought.emit(room)
	refresh()


# --- Decor ---

func _refresh_decor() -> void:
	var state: Dictionary = GameState.state
	_slots_label.text = "%d of %d slots used" % [FurnishLogic.decor_used(state), FurnishLogic.decor_slots(state)]
	for row in _decor_box.get_children():
		row.queue_free()
	for decor_id in GameState.decor_catalog:
		_decor_box.add_child(_build_decor_card(GameState.decor_catalog[decor_id]))


func _build_decor_card(item: Dictionary) -> PanelContainer:
	var state: Dictionary = GameState.state
	var owned := FurnishLogic.owns_decor(state, item.get("id", ""))

	var card := PanelContainer.new()
	card.theme_type_variation = &"ParchmentPanel"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var title := Label.new()
	title.theme_type_variation = &"InkHeading"
	title.text = item.get("name", "")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for tag in item.get("tags", []):
		chips.add_child(_make_chip(MatchLogic.tag_label(tag)))
	column.add_child(chips)

	var attracts := FurnishLogic.attracted_regulars(item, state, GameState.customers)
	var draw := Label.new()
	draw.theme_type_variation = &"MutedLabel"
	draw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draw.text = "Draws in %s" % ", ".join(attracts) if not attracts.is_empty() else "No regular you know cares for this yet."
	column.add_child(draw)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if owned:
		button.theme_type_variation = &"DarkButton"
		button.text = "Remove · +%d acorns" % int(floor(int(item.get("price", 0)) * Tuning.DECOR_SELL_REFUND_RATIO))
		button.pressed.connect(_on_sell_decor.bind(item))
	elif FurnishLogic.decor_blocked_by_room(state, item):
		button.text = "Needs the %s" % FurnishLogic.ROOMS[item["needsRoom"]]["name"]
		button.disabled = true
	else:
		button.text = "Buy · %d acorns" % int(item.get("price", 0))
		button.disabled = not FurnishLogic.can_buy_decor(state, item)
		button.pressed.connect(_on_buy_decor.bind(item))
	column.add_child(button)
	return card


func _on_buy_decor(item: Dictionary) -> void:
	if not FurnishLogic.buy_decor(GameState.state, item):
		return
	_after_decor_change()


func _on_sell_decor(item: Dictionary) -> void:
	FurnishLogic.sell_decor(GameState.state, item)
	_after_decor_change()


func _after_decor_change() -> void:
	GameState.save_game()
	GameState.acorns_changed.emit(GameState.state["acorns"])
	decor_changed.emit()
	refresh()


func _make_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"TagChip"
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TagLabel"
	chip.add_child(label)
	return chip
