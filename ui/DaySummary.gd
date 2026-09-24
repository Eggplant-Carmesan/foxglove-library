class_name DaySummary
extends Control
## Shown when the player closes up: what the day amounted to, and why the
## reputation moved the way it did.

signal open_up_pressed

const SHEET_TOP := -660.0
const SHEET_BOTTOM := -88.0
const SHEET_TRAVEL := 660.0
const SLIDE_TIME := 0.28

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet: PanelContainer = $Sheet
@onready var _title: Label = %SummaryTitle
@onready var _lent: Label = %SummaryLent
@onready var _returned: Label = %SummaryReturned
@onready var _acorns: Label = %SummaryAcorns
@onready var _reputation: Label = %SummaryReputation
@onready var _missed_section: VBoxContainer = %MissedSection
@onready var _missed_list: VBoxContainer = %MissedList
@onready var _unlocked_section: VBoxContainer = %UnlockedSection
@onready var _unlocked_list: VBoxContainer = %UnlockedList
@onready var _open_button: Button = %OpenUpButton


func _ready() -> void:
	hide()
	_open_button.pressed.connect(_on_open_pressed)


func open() -> void:
	var tally := GameState.day_log()
	_title.text = "Day %d, closed up" % GameState.state.get("day", 1)
	_lent.text = _count_line(int(tally.get("loansOut", 0)), "book lent out", "books lent out")
	_returned.text = _count_line(int(tally.get("returns", 0)), "book came back", "books came back")
	_acorns.text = "%+d acorns earned" % int(tally.get("acorns", 0))
	_reputation.text = "%+d reputation" % int(tally.get("reputation", 0))

	_build_missed(tally.get("missed", []))
	_build_unlocked(tally.get("unlocked", []))

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


func _count_line(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]


## Requests the library couldn't fill, so a reputation drop makes sense.
func _build_missed(missed: Array) -> void:
	for row in _missed_list.get_children():
		row.queue_free()
	_missed_section.visible = not missed.is_empty()
	for entry in missed:
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var reason := "out on loan" if entry.get("status") == RequestLogic.OUT else "not in stock"
		label.text = "%s asked for %s — %s" % [
			entry.get("customer", ""), entry.get("title", ""), reason,
		]
		_missed_list.add_child(label)


func _build_unlocked(unlocked: Array) -> void:
	for row in _unlocked_list.get_children():
		row.queue_free()
	_unlocked_section.visible = not unlocked.is_empty()
	for customer_id in unlocked:
		var label := Label.new()
		label.theme_type_variation = &"InkLabel"
		var customer: Dictionary = GameState.customers.get(customer_id, {})
		label.text = "%s has started visiting — %s" % [
			customer.get("name", ""), customer.get("description", ""),
		]
		_unlocked_list.add_child(label)


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


func _on_open_pressed() -> void:
	await close()
	open_up_pressed.emit()
