class_name RareAlcove
extends Node2D
## The right-hand zone. Locked behind a wrought-iron gate until bought;
## the gate swings open and the glass case is yours.

const ZONE_WIDTH := 900.0

@onready var _gate: Node2D = $Gate
@onready var _contents: Node2D = $Contents
@onready var _locked_sign: Label = $Gate/LockedSign


func _ready() -> void:
	set_unlocked(false, false)


func get_content_bounds() -> Vector2:
	return Vector2(position.x, position.x + ZONE_WIDTH)


func get_decor_anchors() -> Array[Node]:
	return $Contents/DecorAnchors.get_children()


func set_unlocked(unlocked: bool, animate: bool) -> void:
	_contents.modulate.a = 1.0 if unlocked else 0.25
	_locked_sign.visible = not unlocked
	if not animate:
		_gate.visible = not unlocked
		_gate.scale.x = 1.0
		return
	if unlocked:
		_swing_gate()


## The gate swings away on its hinge and the alcove opens up.
func _swing_gate() -> void:
	var tween := create_tween()
	tween.tween_property(_gate, "scale:x", 0.06, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _gate.visible = false)
	create_tween().tween_property(_contents, "modulate:a", 1.0, 0.8)
