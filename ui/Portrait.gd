class_name Portrait
extends VBoxContainer
## Placeholder portrait: an arch-shaped box with the customer's initial and
## description, plus a mood. Swap the ArtSlot texture in for real portraits.

const MOOD_TINTS := {
	"delighted": Color(1.0, 0.96, 0.84),
	"neutral": Color(1, 1, 1),
	"sad": Color(0.82, 0.85, 0.92),
}

@onready var _frame: Panel = $Frame
@onready var _initial: Label = $Frame/InitialLabel
@onready var _description: Label = $DescriptionLabel


func setup(customer: Dictionary) -> void:
	var customer_name: String = customer.get("name", "")
	_initial.text = customer_name.substr(0, 1) if customer_name != "" else "?"
	_description.text = customer.get("description", "")
	_frame.self_modulate = Palette.spine_color_for_id(customer.get("id", "")).lightened(0.1)
	set_mood("neutral")


func set_mood(mood: String) -> void:
	modulate = MOOD_TINTS.get(mood, Color.WHITE)


## The description sits on parchment by default; over a dark modal backdrop
## it needs the light text color instead.
func use_light_description() -> void:
	_description.add_theme_color_override("font_color", Palette.MIST_TEXT)


## Grows the portrait for the customer modal, where it's the focal point.
func set_frame_size(frame_size: Vector2) -> void:
	_frame.custom_minimum_size = frame_size
	custom_minimum_size.x = frame_size.x
	_description.custom_minimum_size.x = frame_size.x
	_initial.add_theme_font_size_override("font_size", int(frame_size.y * 0.42))
