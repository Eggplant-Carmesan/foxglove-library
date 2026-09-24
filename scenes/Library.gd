class_name Library
extends Node2D
## The 2D library world: bookcases full of spines, a camera the player drags
## left and right, and customers who walk in through the door. UI sheets live
## on CanvasLayers above this scene.

signal spine_selected(copy_id: String)

const CUSTOMER_SCENE := preload("res://scenes/Customer.tscn")
const DECOR_SCENE := preload("res://scenes/DecorItem.tscn")
const DRAG_FRICTION := 5.0
const TAP_THRESHOLD := 14.0
const MORNING_TINT := Color(1.0, 0.98, 0.92)
const DUSK_TINT := Color(0.74, 0.69, 0.86)

@onready var _camera: Camera2D = $Camera2D
@onready var _hall: MainHall = $MainHall
@onready var _customers: Node2D = $Customers
@onready var _tint: CanvasModulate = $CanvasModulate
@onready var _nook: ReadingNook = $ReadingNook
@onready var _alcove: RareAlcove = $RareAlcove
@onready var _decor_layer: Node2D = $DecorItems

var _dragging := false
var _drag_distance := 0.0
var _frame_drag := 0.0
var _velocity := 0.0
var _min_x := 0.0
var _max_x := 0.0
var _filter_tag := ""
var _selected_spine: Spine = null
var _current_customer: Customer = null


func _ready() -> void:
	GameState.shelf_changed.connect(refresh_shelf)
	GameState.queue_changed.connect(_update_time_of_day)
	refresh_zones()
	refresh_shelf()
	refresh_decor(false)
	_update_time_of_day()


# --- Zones ---

## Lays the zones either side of the hall and shows whether they're open.
## Pass a room id to play its unlock animation and pan across to it.
func refresh_zones(unlocking: String = "") -> void:
	var hall := _hall.get_content_bounds()
	_nook.position.x = hall.x - 900.0
	_alcove.position.x = hall.y

	var has_nook := FurnishLogic.owns_room(GameState.state, FurnishLogic.NOOK)
	var has_alcove := FurnishLogic.owns_room(GameState.state, FurnishLogic.ALCOVE)
	_nook.set_unlocked(has_nook, unlocking == FurnishLogic.NOOK)
	_alcove.set_unlocked(has_alcove, unlocking == FurnishLogic.ALCOVE)

	_update_camera_bounds()
	if unlocking != "":
		pan_to_zone(unlocking, 1.1)


func pan_to_zone(zone: String, duration: float = 0.6) -> void:
	var bounds := _hall.get_content_bounds()
	match zone:
		FurnishLogic.NOOK:
			bounds = _nook.get_content_bounds()
		FurnishLogic.ALCOVE:
			bounds = _alcove.get_content_bounds()
	pan_to((bounds.x + bounds.y) * 0.5, duration)


# --- Decor ---

## Puts every owned piece at the next free anchor in the zone it suits.
func refresh_decor(animate_new: bool = true) -> void:
	var previous := {}
	for item in _decor_layer.get_children():
		previous[item.name] = true
		item.queue_free()

	var next_anchor := { "hall": 0, "nook": 0, "alcove": 0 }
	for decor_id in GameState.state.get("decor", []):
		var item: Dictionary = GameState.decor_catalog.get(decor_id, {})
		if item.is_empty():
			continue
		var zone: String = item.get("needsRoom", "hall")
		var anchors := _anchors_for(zone)
		var index: int = next_anchor[zone]
		if index >= anchors.size():
			continue
		next_anchor[zone] = index + 1

		var node: DecorItem = DECOR_SCENE.instantiate()
		node.name = decor_id
		_decor_layer.add_child(node)
		node.setup(item)
		node.global_position = anchors[index].global_position
		node.appear(animate_new and not previous.has(decor_id))


func _anchors_for(zone: String) -> Array[Node]:
	match zone:
		FurnishLogic.NOOK:
			return _nook.get_decor_anchors()
		FurnishLogic.ALCOVE:
			return _alcove.get_decor_anchors()
		_:
			return _hall.get_decor_anchors()


# --- Shelf ---

func refresh_shelf() -> void:
	_selected_spine = null
	var shelf: Array = GameState.state.get("shelf", [])
	var bookcases := _hall.get_bookcases()
	for i in bookcases.size():
		var start := i * Bookcase.SLOTS
		bookcases[i].set_copies(shelf.slice(start, start + Bookcase.SLOTS))
	apply_filter(_filter_tag)


## Filtering dims non-matching spines rather than hiding them.
func apply_filter(tag: String) -> void:
	_filter_tag = tag
	for bookcase in _hall.get_bookcases():
		for spine in bookcase.spines:
			var book: Dictionary = GameState.books.get(spine.book_id, {})
			var tags: Array = book.get("tags", [])
			spine.set_dimmed(tag != "" and not tags.has(tag))


func clear_selection() -> void:
	if _selected_spine != null:
		_selected_spine.set_selected(false)
		_selected_spine = null


# --- Camera ---

func _update_camera_bounds() -> void:
	var bounds := _hall.get_content_bounds()
	if FurnishLogic.owns_room(GameState.state, FurnishLogic.NOOK):
		bounds.x = _nook.get_content_bounds().x
	if FurnishLogic.owns_room(GameState.state, FurnishLogic.ALCOVE):
		bounds.y = _alcove.get_content_bounds().y
	var half_width := get_viewport_rect().size.x * 0.5 / _camera.zoom.x
	_min_x = bounds.x + half_width
	_max_x = maxf(_min_x, bounds.y - half_width)
	_camera.position.x = clampf(_camera.position.x, _min_x, _max_x)


func pan_to(world_x: float, duration: float = 0.5) -> void:
	_velocity = 0.0
	var target := clampf(world_x, _min_x, _max_x)
	create_tween().tween_property(_camera, "position:x", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_distance = 0.0
			_velocity = 0.0
		else:
			_dragging = false
			if _drag_distance < TAP_THRESHOLD:
				_handle_tap(_to_world(event.position))
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(-event.relative.x / _camera.zoom.x)
		_drag_distance += absf(event.relative.x)
		_frame_drag += event.relative.x


func _process(delta: float) -> void:
	if _dragging:
		if not is_zero_approx(_frame_drag) and delta > 0.0:
			_velocity = -_frame_drag / delta
		_frame_drag = 0.0
	elif absf(_velocity) > 2.0:
		_move_camera(_velocity * delta)
		_velocity = lerpf(_velocity, 0.0, minf(1.0, DRAG_FRICTION * delta))
	else:
		_velocity = 0.0


func _move_camera(amount: float) -> void:
	_camera.position.x = clampf(_camera.position.x + amount, _min_x, _max_x)


## Viewport coordinates from an input event to world coordinates, via the
## camera. Taken from the event rather than the pointer so touch releases
## resolve to the point that was actually touched.
func _to_world(viewport_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_point


func _handle_tap(world_point: Vector2) -> void:
	for bookcase in _hall.get_bookcases():
		var spine: Spine = bookcase.spine_at(world_point)
		if spine != null:
			clear_selection()
			_selected_spine = spine
			spine.set_selected(true)
			spine_selected.emit(spine.copy_id)
			return


# --- Visitors ---

func greet_visitor(customer: Dictionary) -> void:
	var counter_x := _hall.get_counter_position().x
	pan_to(counter_x)
	_hall.swing_door()

	var visitor: Customer = CUSTOMER_SCENE.instantiate()
	_customers.add_child(visitor)
	visitor.setup(customer)
	visitor.position = _hall.get_door_position()
	_current_customer = visitor
	await visitor.walk_to(counter_x)


func dismiss_visitor(carried_book_id: String = "") -> void:
	if _current_customer == null:
		return
	var visitor := _current_customer
	_current_customer = null
	visitor.carry_book(carried_book_id)
	await visitor.walk_to(_hall.get_door_position().x)
	_hall.swing_door()
	await get_tree().create_timer(0.25).timeout
	visitor.queue_free()


func set_visitor_mood(mood: String) -> void:
	if _current_customer != null:
		_current_customer.set_mood(mood)


func visitor_say(line: String) -> void:
	if _current_customer != null:
		_current_customer.say(line)


# --- Time of day ---

## The hall warms from morning to dusk as the day's visits are worked through.
func _update_time_of_day() -> void:
	var progress := GameState.day_progress()
	create_tween().tween_property(_tint, "color", MORNING_TINT.lerp(DUSK_TINT, progress), 0.6)
