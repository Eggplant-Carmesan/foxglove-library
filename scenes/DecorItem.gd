class_name DecorItem
extends Node2D
## Placeholder decor: a simple shape with its name under it. Swap the
## ArtSlot sprite for real art without touching the placement code.

@onready var _body: ColorRect = $Body
@onready var _label: Label = $NameLabel
@onready var _sparkle: GPUParticles2D = $Sparkle


func setup(item: Dictionary) -> void:
	_label.text = item.get("name", "")
	_body.color = Palette.spine_color_for_id(item.get("id", "")).lightened(0.1)


## Bought decor fades and scales into its anchor with a small sparkle.
func appear(animate: bool) -> void:
	if not animate:
		return
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	_sparkle.restart()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
