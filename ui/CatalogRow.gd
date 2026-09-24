class_name CatalogRow
extends PanelContainer
## One book on offer in today's catalog.

signal add_toggled(book_id: String, added: bool)

var book_id := ""

@onready var _swatch: ColorRect = %Swatch
@onready var _title: Label = %RowTitle
@onready var _author: Label = %RowAuthor
@onready var _hint: Label = %RowHint
@onready var _trending: PanelContainer = %TrendingTag
@onready var _price: Label = %RowPrice
@onready var _add_button: Button = %AddButton


func _ready() -> void:
	_add_button.toggled.connect(_on_add_toggled)


func setup(book: Dictionary, hint: String, trending: bool) -> void:
	book_id = book.get("id", "")
	_swatch.color = Palette.spine_color_for_id(book_id)
	_title.text = book.get("title", "")
	_author.text = book.get("author", "")
	_hint.text = hint
	_trending.visible = trending
	_price.text = "%d" % int(book.get("price", 0))


func set_added(added: bool) -> void:
	_add_button.set_pressed_no_signal(added)
	_add_button.text = "Added" if added else "Add"


## Books already on their way can't be ordered again today.
func set_ordered() -> void:
	_add_button.set_pressed_no_signal(true)
	_add_button.disabled = true
	_add_button.text = "Ordered"


func _on_add_toggled(pressed: bool) -> void:
	_add_button.text = "Added" if pressed else "Add"
	add_toggled.emit(book_id, pressed)
