class_name JournalEntry
extends PanelContainer
## One regular's page: what you know about their taste, how fond of you they
## are, and what they thought of the last few books you picked.

signal gift_pressed(customer_id: String)

const LEAF_SCENE := preload("res://ui/Leaf.tscn")

@onready var _portrait: Portrait = %EntryPortrait
@onready var _name_label: Label = %EntryName
@onready var _leaves: HBoxContainer = %AffinityLeaves
@onready var _likes: HBoxContainer = %LikeChips
@onready var _dislikes: HBoxContainer = %DislikeChips
@onready var _unknown_label: Label = %UnknownLabel
@onready var _backstory: Label = %Backstory
@onready var _reviews: VBoxContainer = %ReviewList
@onready var _no_reviews: Label = %NoReviews
@onready var _gift_button: Button = %GiftButton

var customer_id := ""


func _ready() -> void:
	_gift_button.pressed.connect(func() -> void: gift_pressed.emit(customer_id))


func setup(customer: Dictionary) -> void:
	customer_id = customer.get("id", "")
	_portrait.setup(customer)
	_name_label.text = customer.get("name", "")

	_build_leaves()
	_build_taste(customer)
	_build_backstory(customer)
	_build_reviews()
	_gift_button.disabled = GameState.state.get("giftedToday", []).has(customer_id)
	_gift_button.text = "Gifted today" if _gift_button.disabled else "Give a gift"


func _build_leaves() -> void:
	for leaf in _leaves.get_children():
		leaf.queue_free()
	var affinity := GameState.affinity_for(customer_id)
	for i in Tuning.AFFINITY_MAX:
		var leaf: Leaf = LEAF_SCENE.instantiate()
		_leaves.add_child(leaf)
		leaf.set_filled(i < affinity)


func _build_taste(customer: Dictionary) -> void:
	for chip in _likes.get_children():
		chip.queue_free()
	for chip in _dislikes.get_children():
		chip.queue_free()

	var likes := GameState.journal_likes(customer_id)
	var dislikes := GameState.journal_dislikes(customer_id)
	for tag in likes:
		_likes.add_child(_make_chip(MatchLogic.tag_label(tag)))
	for tag in dislikes:
		_dislikes.add_child(_make_chip("no %s" % MatchLogic.tag_label(tag)))

	_likes.visible = not likes.is_empty()
	_dislikes.visible = not dislikes.is_empty()
	var known := likes.size() + dislikes.size()
	var total: int = customer.get("likes", []).size() + customer.get("dislikes", []).size()
	_unknown_label.visible = known < total
	_unknown_label.text = "%d tastes still a mystery" % (total - known)


func _build_backstory(customer: Dictionary) -> void:
	var unlocked := GameState.affinity_for(customer_id) >= Tuning.AFFINITY_BACKSTORY
	_backstory.visible = unlocked
	if unlocked:
		_backstory.text = customer.get("backstory", "")


func _build_reviews() -> void:
	for row in _reviews.get_children():
		row.queue_free()
	var reviews := GameState.recent_reviews(customer_id, Tuning.JOURNAL_REVIEW_COUNT)
	_no_reviews.visible = reviews.is_empty()
	for record in reviews:
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var title: String = GameState.books.get(record.get("bookId", ""), {}).get("title", "")
		label.text = "%s  %s — “%s”" % [
			_hearts_text(int(record.get("hearts", 0))), title, record.get("line", ""),
		]
		_reviews.add_child(label)


func _hearts_text(hearts: int) -> String:
	return "●".repeat(hearts) + "○".repeat(Tuning.AFFINITY_MAX - hearts)


func _make_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"TagChip"
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TagLabel"
	chip.add_child(label)
	return chip
