class_name Library
extends Node2D
## The library world: an isometric hall of bookcases, a camera the player
## drags left and right, and customers who walk in through the door. UI
## sheets live on CanvasLayers above this scene.

## A case the player tapped, and its place in the hall's order. The front-on
## view takes it from here; books are not tapped in the hall itself, because
## at this size a spine is a few pixels wide.
signal bookcase_selected(bookcase: IsoBookcase, index: int)

const CUSTOMER_SCENE := preload("res://scenes/Customer.tscn")
const DECOR_SCENE := preload("res://scenes/DecorItem.tscn")
const DRAG_FRICTION := 5.0
const TAP_THRESHOLD := 14.0
## How close the player may lean in, and how far back they may stand.
const ZOOM_MIN := 0.7
const ZOOM_MAX := 3.0
## One notch of the wheel.
const ZOOM_NOTCH := 1.12
## A trackpad's two-finger scroll arrives in notches, not pixels.
const PAN_GESTURE_STEP := 18.0
## How tall a person stands in the hall, in world pixels. A bookcase is
## about 215, so this puts their head around the third shelf.
const CUSTOMER_HEIGHT := 150.0
## How far in front of the counter a visitor stands, in world pixels.
const COUNTER_STANDOFF := Vector2(0.0, 74.0)
const MORNING_TINT := Color(1.0, 0.98, 0.92)
const DUSK_TINT := Color(0.74, 0.69, 0.86)

@onready var _camera: Camera2D = $Camera2D
@onready var _hall: IsoHall = $IsoHall
@onready var _tint: CanvasModulate = $CanvasModulate
@onready var _nook: ReadingNook = $ReadingNook
@onready var _alcove: RareAlcove = $RareAlcove
@onready var _decor_layer: Node2D = $DecorItems

var _dragging := false
var _drag_distance := 0.0
var _frame_drag := Vector2.ZERO
var _velocity := Vector2.ZERO
## Where the camera may wander, in world space.
var _bounds := Rect2()
## Fingers currently down, by index. Only used to notice a pinch.
var _touches := {}
var _pinch_spread := 0.0
var _pinch_middle := Vector2.ZERO
## The tag the filter chips are on, read by the front-on view so a case
## opens showing the same books dimmed.
var filter_tag := ""
var _current_customer: Customer = null


func _ready() -> void:
	GameState.shelf_changed.connect(refresh_shelf)
	GameState.queue_changed.connect(_update_time_of_day)
	refresh_zones()
	refresh_shelf()
	refresh_decor(false)
	_update_time_of_day()
	get_viewport().size_changed.connect(_clamp_camera)


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
	# Both side rooms are still drawn side-on. Until they are isometric too,
	# an unowned one would just be a slab of the old art beside the hall.
	_nook.visible = has_nook
	_alcove.visible = has_alcove

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
	var shelf: Array = GameState.state.get("shelf", [])
	var bookcases := _hall.get_bookcases()
	# The room only shows the shelving the player has paid for, so buying a
	# bookcase puts a real one against the wall instead of just raising a
	# number. Spare cases stand ready in the scene, hidden until then.
	var earned := ceili(float(OrdersLogic.shelf_capacity(GameState.state))
		/ float(Tuning.SHELF_SLOTS_PER_BOOKCASE))
	for i in bookcases.size():
		bookcases[i].visible = i < earned
		var start := i * Tuning.SHELF_SLOTS_PER_BOOKCASE
		bookcases[i].set_copies(shelf.slice(start, start + Tuning.SHELF_SLOTS_PER_BOOKCASE))
	apply_filter(filter_tag)


## Filtering dims non-matching spines rather than hiding them.
func apply_filter(tag: String) -> void:
	filter_tag = tag
	for bookcase in _hall.get_bookcases():
		for spine in bookcase.spines:
			var book: Dictionary = GameState.books.get(spine.book_id, {})
			var tags: Array = book.get("tags", [])
			spine.set_dimmed(tag != "" and not tags.has(tag))


# --- Camera ---

func _update_camera_bounds() -> void:
	_bounds = _hall.get_content_rect()
	var left := _bounds.position.x
	var right := _bounds.end.x
	if FurnishLogic.owns_room(GameState.state, FurnishLogic.NOOK):
		left = _nook.get_content_bounds().x
	if FurnishLogic.owns_room(GameState.state, FurnishLogic.ALCOVE):
		right = _alcove.get_content_bounds().y
	_bounds.position.x = left
	_bounds.size.x = right - left
	_clamp_camera()


## Keeps the view over the room.
##
## An axis with less room than the view is centred rather than clamped, so a
## room shorter than the screen sits in the middle of it instead of being
## pinned to one edge — which is what zooming out lands in.
func _clamp_camera() -> void:
	var half := get_viewport_rect().size * 0.5 / _camera.zoom
	_camera.position = Vector2(
		_clamp_axis(_camera.position.x, _bounds.position.x, _bounds.end.x, half.x),
		_clamp_axis(_camera.position.y, _bounds.position.y, _bounds.end.y, half.y),
	)


static func _clamp_axis(value: float, low: float, high: float, half: float) -> float:
	if high - low <= half * 2.0:
		return (low + high) * 0.5
	return clampf(value, low + half, high - half)


func pan_to(world_x: float, duration: float = 0.5) -> void:
	_velocity = Vector2.ZERO
	var half := get_viewport_rect().size.x * 0.5 / _camera.zoom.x
	var target := _clamp_axis(world_x, _bounds.position.x, _bounds.end.x, half)
	create_tween().tween_property(_camera, "position:x", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Zooms about a point on screen, so whatever is under the pointer or the
## pinch stays under it.
##
## Worked out from the camera rather than the canvas transform, because the
## transform does not catch up with a zoom until the frame is drawn, and a
## pinch changes it several times before then.
func _zoom_at(target_zoom: float, screen_point: Vector2) -> void:
	var zoom := clampf(target_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(zoom, _camera.zoom.x):
		return
	var offset := screen_point - get_viewport_rect().size * 0.5
	var pivot := _camera.position + offset / _camera.zoom.x
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = pivot - offset / zoom
	_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	# Two fingers pinch. The first finger also arrives as an emulated mouse
	# event, which is what drives the one-finger drag, so touches are tracked
	# here only to notice when a second one lands — and to stand the mouse
	# path down while it has.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_dragging = false
			_velocity = Vector2.ZERO
			_pinch_spread = _touch_spread()
			_pinch_middle = _touch_middle()
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch()
		return
	if _touches.size() >= 2:
		return

	if event is InputEventMagnifyGesture:
		_zoom_at(_camera.zoom.x * event.factor, event.position)
	elif event is InputEventPanGesture:
		_move_camera(event.delta * PAN_GESTURE_STEP / _camera.zoom)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(-event.relative / _camera.zoom)
		_drag_distance += event.relative.length()
		_frame_drag += event.relative


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(_camera.zoom.x * ZOOM_NOTCH, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(_camera.zoom.x / ZOOM_NOTCH, event.position)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_distance = 0.0
				_velocity = Vector2.ZERO
			else:
				_dragging = false
				if _drag_distance < TAP_THRESHOLD:
					_handle_tap(_to_world(event.position))


func _touch_spread() -> float:
	var points: Array = _touches.values()
	return points[0].distance_to(points[1]) if points.size() >= 2 else 0.0


func _touch_middle() -> Vector2:
	var points: Array = _touches.values()
	return (points[0] + points[1]) * 0.5 if points.size() >= 2 else Vector2.ZERO


## A pinch both zooms, by how much the fingers spread, and pans, by where
## their middle went — the two happen together on a real pinch.
func _pinch() -> void:
	var spread := _touch_spread()
	var middle := _touch_middle()
	if _pinch_spread > 0.0 and spread > 0.0:
		_zoom_at(_camera.zoom.x * spread / _pinch_spread, middle)
		_move_camera((_pinch_middle - middle) / _camera.zoom)
	_pinch_spread = spread
	_pinch_middle = middle


func _process(delta: float) -> void:
	if _dragging:
		if _frame_drag != Vector2.ZERO and delta > 0.0:
			_velocity = -_frame_drag / delta / _camera.zoom
		_frame_drag = Vector2.ZERO
	elif _velocity.length() > 2.0:
		_move_camera(_velocity * delta)
		_velocity = _velocity.lerp(Vector2.ZERO, minf(1.0, DRAG_FRICTION * delta))
	else:
		_velocity = Vector2.ZERO


func _move_camera(amount: Vector2) -> void:
	_camera.position += amount
	_clamp_camera()


func _to_world(viewport_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_point


func _handle_tap(world_point: Vector2) -> void:
	var bookcases := _hall.get_bookcases()
	var index := _bookcase_at(world_point)
	if index >= 0:
		bookcase_selected.emit(bookcases[index], index)


## Which bookcase a world point lands on, or -1. Cases stand shoulder to
## shoulder, so where two of them overlap the nearer wins — and nearer, in
## this projection, means further down the screen.
func _bookcase_at(world_point: Vector2) -> int:
	var found := -1
	var nearest := -INF
	var bookcases := _hall.get_bookcases()
	for i in bookcases.size():
		var bookcase: IsoBookcase = bookcases[i]
		if not bookcase.visible or not bookcase.contains_point(world_point):
			continue
		if bookcase.global_position.y > nearest:
			nearest = bookcase.global_position.y
			found = i
	return found


# --- Visitors ---

func greet_visitor(customer: Dictionary) -> void:
	var stand := _hall.get_counter_position() + COUNTER_STANDOFF
	pan_to(stand.x)
	_hall.swing_door()

	var visitor: Customer = CUSTOMER_SCENE.instantiate()
	_hall.get_visitor_parent().add_child(visitor)
	visitor.setup(customer)
	visitor.fit_height(CUSTOMER_HEIGHT)
	visitor.position = _hall.get_door_position()
	_current_customer = visitor
	await visitor.walk_to(stand)


func dismiss_visitor(carried_book_id: String = "") -> void:
	if _current_customer == null:
		return
	var visitor := _current_customer
	_current_customer = null
	visitor.carry_book(carried_book_id)
	await visitor.walk_to(_hall.get_door_position())
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
