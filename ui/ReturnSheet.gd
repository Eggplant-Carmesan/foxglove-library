class_name ReturnSheet
extends Control
## The return modal: how the customer felt about the book you picked, and
## what that earned you.

signal done_pressed

const HEART_SCENE := preload("res://ui/Heart.tscn")
const SHEET_TOP := -528.0
const SHEET_BOTTOM := -88.0
const SHEET_TRAVEL := 528.0
const SLIDE_TIME := 0.28
const HEART_STAGGER := 0.16
const COUNT_TIME := 0.5
const MAX_HEARTS := 5

@onready var _backdrop: ColorRect = $Backdrop
@onready var _sheet: PanelContainer = $Sheet
@onready var _portrait: Portrait = %BigPortrait
@onready var _title_label: Label = %ReturnTitle
@onready var _book_label: Label = %ReturnBook
@onready var _hearts_row: HBoxContainer = %HeartsRow
@onready var _review_label: Label = %ReviewLine
@onready var _reputation_label: Label = %RewardReputation
@onready var _tip_label: Label = %RewardTip
@onready var _tag_chip_row: HBoxContainer = %RewardTagRow
@onready var _done_button: Button = %DoneButton

var _hearts: Array[Heart] = []


func _ready() -> void:
	hide()
	_portrait.set_frame_size(Vector2(240, 280))
	_portrait.use_light_description()
	for i in MAX_HEARTS:
		var heart: Heart = HEART_SCENE.instantiate()
		_hearts_row.add_child(heart)
		_hearts.append(heart)
	_done_button.pressed.connect(_on_done_pressed)


func open(result: Dictionary) -> void:
	var customer: Dictionary = result.get("customer", {})
	var hearts: int = result.get("hearts", 1)

	_portrait.setup(customer)
	_portrait.set_mood(GameState.mood_for_hearts(hearts))
	_title_label.text = "%s returns" % customer.get("name", "")
	_book_label.text = result.get("book", {}).get("title", "")
	_review_label.text = "“%s”" % result.get("line", "")

	for i in _hearts.size():
		_hearts[i].set_filled(i < hearts)

	_show_rewards(result)

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

	for i in _hearts.size():
		_hearts[i].pop(SLIDE_TIME + i * HEART_STAGGER)


## Reputation and acorns tick up once the hearts have landed.
func _show_rewards(result: Dictionary) -> void:
	var reputation: int = result.get("reputation", 0)
	var tip: int = result.get("tip", 0)
	var start_delay := SLIDE_TIME + MAX_HEARTS * HEART_STAGGER

	_set_reputation_text(0)
	_set_tip_text(0)
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_reputation_text, 0, reputation, COUNT_TIME).set_delay(start_delay)
	tween.tween_method(_set_tip_text, 0, tip, COUNT_TIME).set_delay(start_delay)

	for chip in _tag_chip_row.get_children():
		chip.queue_free()
	var new_tag: String = result.get("newTag", "")
	_tag_chip_row.visible = new_tag != ""
	if new_tag != "":
		_tag_chip_row.add_child(_make_learned_chip(result.get("customer", {}), new_tag))


func _set_reputation_text(value: int) -> void:
	_reputation_label.text = "%+d reputation" % value


func _set_tip_text(value: int) -> void:
	_tip_label.text = "+%d acorns" % value


func _make_learned_chip(customer: Dictionary, tag: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"TagChip"
	var label := Label.new()
	var disliked: bool = customer.get("dislikes", []).has(tag)
	label.text = "Journal: %s%s" % ["no " if disliked else "", MatchLogic.tag_label(tag)]
	label.theme_type_variation = &"TagLabel"
	chip.add_child(label)
	return chip


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


func _on_done_pressed() -> void:
	await close()
	done_pressed.emit()
