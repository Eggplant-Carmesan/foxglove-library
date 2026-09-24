class_name JournalScreen
extends Control
## The Journal tab: a page per regular you've met, and the way out of a
## run you've had enough of.

signal gift_requested(customer_id: String)

const ENTRY_SCENE := preload("res://ui/JournalEntry.tscn")

@onready var _entries: VBoxContainer = %JournalEntries
@onready var _reset_button: Button = %ResetButton
@onready var _confirm: ConfirmationDialog = $ResetConfirm


func _ready() -> void:
	_reset_button.pressed.connect(func() -> void: _confirm.popup_centered())
	_confirm.confirmed.connect(_on_reset_confirmed)
	GameState.state_reset.connect(refresh)
	GameState.state_loaded.connect(refresh)
	GameState.customer_unlocked.connect(func(_id: String) -> void: refresh())
	GameState.affinity_changed.connect(func(_id: String, _level: int) -> void: refresh())
	visibility_changed.connect(_on_visibility_changed)
	refresh()


func _on_visibility_changed() -> void:
	if visible:
		refresh()


func refresh() -> void:
	for entry in _entries.get_children():
		entry.queue_free()
	for customer_id in GameState.unlocked_customer_ids():
		var entry: JournalEntry = ENTRY_SCENE.instantiate()
		_entries.add_child(entry)
		entry.setup(GameState.customers[customer_id])
		entry.gift_pressed.connect(gift_requested.emit)


func _on_reset_confirmed() -> void:
	GameState.reset_game()
	refresh()
