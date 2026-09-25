class_name Customer
extends Node2D
## Placeholder customer: an arch-shaped silhouette with a name label and
## three moods. Origin sits at the feet so walking is just a position.x
## tween along the floor. Real art drops into the ArtSlot sprite.

const WALK_SPEED := 420.0
## How tall the silhouette is drawn, before any fitting.
const ART_HEIGHT := 420.0
## Gap between the top of the head and the speech bubble, in screen pixels.
const BUBBLE_GAP := 30.0

@onready var _body: Node2D = $Body
@onready var _silhouette: Polygon2D = $Body/Silhouette
@onready var _name_label: Label = $NameLabel
@onready var _carried_book: ColorRect = $Body/CarriedBook
@onready var _bubble: PanelContainer = $Bubble
@onready var _bubble_label: Label = $Bubble/BubbleLabel
@onready var _mouths := {
	"delighted": $Body/Face/MouthHappy,
	"neutral": $Body/Face/MouthNeutral,
	"sad": $Body/Face/MouthSad,
}

var _bob_tween: Tween


func setup(customer: Dictionary) -> void:
	_name_label.text = customer.get("name", "")
	_silhouette.color = Palette.spine_color_for_id(customer.get("id", "")).lightened(0.12)
	set_mood("neutral")
	set_motion("idle")


func set_mood(mood: String) -> void:
	for key in _mouths:
		_mouths[key].visible = (key == mood)


func set_motion(motion: String) -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	var walking := motion == "walk"
	var height := 12.0 if walking else 5.0
	var duration := 0.22 if walking else 0.9
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_body, "position:y", -height, duration).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_body, "position:y", 0.0, duration).set_trans(Tween.TRANS_SINE)


## Shrinks the drawn body so a customer stands the right height in the
## room, without shrinking their name or their speech bubble with it —
## those are text, and text has to stay readable whatever the room's scale.
func fit_height(target_height: float) -> void:
	var factor := target_height / ART_HEIGHT
	_body.scale = Vector2(factor, factor)
	_name_label.position.y = 14.0 * factor
	var bubble_height := _bubble.size.y if _bubble.size.y > 0.0 else 100.0
	_bubble.position.y = -target_height - BUBBLE_GAP - bubble_height


## Walks to a point on the floor. The whole position moves, not just x,
## because on an isometric floor crossing the room changes both.
##
## Speed follows the node's own scale, so a customer sized to the room
## covers it in the same time however big the room's art is.
func walk_to(target: Vector2) -> void:
	set_motion("walk")
	var speed := WALK_SPEED * maxf(0.05, _body.scale.x)
	var duration := maxf(0.25, position.distance_to(target) / speed)
	var tween := create_tween()
	tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	set_motion("idle")


## A one-line reaction in a speech bubble above their head.
func say(line: String, hold: float = 1.6) -> void:
	if line == "":
		return
	_bubble_label.text = line
	_bubble.modulate.a = 0.0
	_bubble.show()
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	tween.tween_interval(hold)
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_bubble.hide)


## Shows a borrowed book in the customer's hands as they leave.
func carry_book(book_id: String) -> void:
	_carried_book.visible = book_id != ""
	if book_id != "":
		_carried_book.color = Palette.spine_color_for_id(book_id)
