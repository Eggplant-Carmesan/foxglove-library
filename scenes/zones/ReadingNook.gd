class_name ReadingNook
extends Node2D
## The left-hand zone. Boarded up behind a "For sale" archway until bought;
## once it's yours the boards fall away and the hearth is lit.

const ZONE_WIDTH := 900.0

@onready var _boards: Node2D = $Boards
@onready var _contents: Node2D = $Contents
@onready var _for_sale: Label = $Boards/ForSaleSign


func _ready() -> void:
	set_unlocked(false, false)


func get_content_bounds() -> Vector2:
	return Vector2(position.x - 40.0, position.x + ZONE_WIDTH)


func get_decor_anchors() -> Array[Node]:
	return $Contents/DecorAnchors.get_children()


func set_unlocked(unlocked: bool, animate: bool) -> void:
	_contents.visible = true
	_contents.modulate.a = 1.0 if unlocked else 0.25
	_for_sale.visible = not unlocked
	if not animate:
		_boards.visible = not unlocked
		return
	if unlocked:
		_drop_boards()


## The boards come off one at a time and clatter to the floor.
func _drop_boards() -> void:
	var tween := create_tween()
	for board in _boards.get_children():
		if board is Label:
			continue
		tween.tween_property(board, "position:y", board.position.y + 700.0, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(board, "rotation", randf_range(-0.6, 0.6), 0.5)
	tween.tween_callback(func() -> void: _boards.visible = false)
	create_tween().tween_property(_contents, "modulate:a", 1.0, 0.8)
