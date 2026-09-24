extends Control
## Bottom tab bar. The four buttons live in the .tscn; this just keeps one
## of them selected and reports which tab that is.

signal tab_selected(tab_name: String)

@onready var _buttons: Array[Button] = [
	%LibraryButton, %OrdersButton, %JournalButton, %FurnishButton,
]


func _ready() -> void:
	for button in _buttons:
		button.pressed.connect(select_tab.bind(button.text))
	select_tab(_buttons[0].text)


func select_tab(tab_name: String) -> void:
	for button in _buttons:
		button.button_pressed = button.text == tab_name
	tab_selected.emit(tab_name)
