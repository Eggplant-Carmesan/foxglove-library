class_name GiftPicker
extends Control
## Small sheet for choosing a gift. Gifts aren't stocked; they're bought at
## the moment of giving.

signal gift_given(customer_id: String, result: Dictionary)
signal closed

const SHEET_TOP := -640.0
const SHEET_BOTTOM := -88.0
const SHEET_TRAVEL := 640.0
const SLIDE_TIME := 0.28

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet: PanelContainer = $Sheet
@onready var _title: Label = %GiftTitle
@onready var _rows: VBoxContainer = %GiftRows
@onready var _close_button: Button = %GiftCloseButton

var _customer_id := ""


func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)
	_backdrop.gui_input.connect(_on_backdrop_input)


func open(customer_id: String) -> void:
	_customer_id = customer_id
	var customer: Dictionary = GameState.customers.get(customer_id, {})
	_title.text = "A gift for %s" % customer.get("name", "")
	_build_rows(customer)

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


## Each gift is marked liked, disliked or unknown, based on what the player
## has found out so far.
func _build_rows(customer: Dictionary) -> void:
	for row in _rows.get_children():
		row.queue_free()

	var already_gifted := GameState.gifted_today(_customer_id)
	for gift_id in GameState.gifts_catalog:
		var gift: Dictionary = GameState.gifts_catalog[gift_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.theme_type_variation = &"InkLabel"
		label.text = gift.get("name", "")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		row.add_child(_taste_chip(customer, gift_id))

		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 44)
		button.text = "%d acorns" % int(gift.get("price", 0))
		button.disabled = already_gifted or not GameState.can_afford_gift(gift)
		button.pressed.connect(_on_gift_pressed.bind(gift_id))
		row.add_child(button)

		_rows.add_child(row)

	if already_gifted:
		var note := Label.new()
		note.theme_type_variation = &"MutedLabel"
		note.text = "They've already had a gift today."
		_rows.add_child(note)


func _taste_chip(customer: Dictionary, gift_id: String) -> PanelContainer:
	var known := GameState.gift_taste_known(customer.get("id", ""), gift_id)
	var chip := PanelContainer.new()
	var label := Label.new()
	label.theme_type_variation = &"TagLabel"

	if not known:
		chip.theme_type_variation = &"HiddenChip"
		label.text = "?"
	else:
		var reaction := AffinityLogic.reaction_to(customer, gift_id)
		chip.theme_type_variation = &"HighlightChip" if reaction == AffinityLogic.LIKED else &"TagChip"
		label.text = "loves this" if reaction == AffinityLogic.LIKED else "dislikes this"

	chip.add_child(label)
	return chip


func _on_gift_pressed(gift_id: String) -> void:
	var result := GameState.give_gift(_customer_id, gift_id)
	if result.is_empty():
		return
	gift_given.emit(_customer_id, result)
	await close()


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


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
