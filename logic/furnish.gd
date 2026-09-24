class_name FurnishLogic
extends RefCounted
## Spending acorns on the library itself: bookcases, the two rooms, and the
## decor that decides which patrons come through the door.

const NOOK := "nook"
const ALCOVE := "alcove"

const ROOMS := {
	NOOK: { "name": "Reading Nook", "cost": Tuning.ROOM_NOOK_COST, "unlockAtRep": Tuning.ROOM_NOOK_UNLOCK_REP },
	ALCOVE: { "name": "Rare Books Alcove", "cost": Tuning.ROOM_ALCOVE_COST, "unlockAtRep": Tuning.ROOM_ALCOVE_UNLOCK_REP },
}


# --- Bookcases ---

## Each bookcase costs half again as much as the last: 60, 90, 135, 202...
static func bookcase_price(state: Dictionary) -> int:
	var bought: int = state.get("bookcases", 0)
	return int(round(Tuning.BOOKCASE_BASE_COST * pow(Tuning.BOOKCASE_COST_MULTIPLIER, bought)))


static func bookcases_maxed(state: Dictionary) -> bool:
	return OrdersLogic.shelf_capacity(state) >= Tuning.MAX_SHELF_CAPACITY


static func can_buy_bookcase(state: Dictionary) -> bool:
	return not bookcases_maxed(state) and int(state.get("acorns", 0)) >= bookcase_price(state)


static func buy_bookcase(state: Dictionary) -> bool:
	if not can_buy_bookcase(state):
		return false
	state["acorns"] = int(state.get("acorns", 0)) - bookcase_price(state)
	state["bookcases"] = int(state.get("bookcases", 0)) + 1
	return true


# --- Rooms ---

static func owns_room(state: Dictionary, room: String) -> bool:
	return bool(state.get("rooms", {}).get(room, false))


static func rooms_owned(state: Dictionary) -> int:
	var count := 0
	for room in ROOMS:
		if owns_room(state, room):
			count += 1
	return count


## A room has to be earned with reputation before it can be bought.
static func room_available(state: Dictionary, room: String) -> bool:
	return int(state.get("reputation", 0)) >= int(ROOMS[room]["unlockAtRep"])


static func can_buy_room(state: Dictionary, room: String) -> bool:
	if owns_room(state, room) or not room_available(state, room):
		return false
	return int(state.get("acorns", 0)) >= int(ROOMS[room]["cost"])


static func buy_room(state: Dictionary, room: String) -> bool:
	if not can_buy_room(state, room):
		return false
	state["acorns"] = int(state.get("acorns", 0)) - int(ROOMS[room]["cost"])
	var rooms: Dictionary = state.get("rooms", {})
	rooms[room] = true
	state["rooms"] = rooms
	return true


# --- Decor ---

static func decor_slots(state: Dictionary) -> int:
	return Tuning.DECOR_SLOTS_BASE + rooms_owned(state) * Tuning.DECOR_SLOTS_PER_ROOM


static func decor_used(state: Dictionary) -> int:
	return state.get("decor", []).size()


static func owns_decor(state: Dictionary, decor_id: String) -> bool:
	return state.get("decor", []).has(decor_id)


## Some pieces only make sense once the room they belong in exists.
static func decor_blocked_by_room(state: Dictionary, item: Dictionary) -> bool:
	var needs: String = item.get("needsRoom", "")
	return needs != "" and not owns_room(state, needs)


static func can_buy_decor(state: Dictionary, item: Dictionary) -> bool:
	if owns_decor(state, item.get("id", "")) or decor_blocked_by_room(state, item):
		return false
	if decor_used(state) >= decor_slots(state):
		return false
	return int(state.get("acorns", 0)) >= int(item.get("price", 0))


static func buy_decor(state: Dictionary, item: Dictionary) -> bool:
	if not can_buy_decor(state, item):
		return false
	state["acorns"] = int(state.get("acorns", 0)) - int(item.get("price", 0))
	var decor: Array = state.get("decor", [])
	decor.append(item.get("id", ""))
	state["decor"] = decor
	return true


## Anything can be taken down again for half of what it cost.
static func sell_decor(state: Dictionary, item: Dictionary) -> int:
	var decor_id: String = item.get("id", "")
	if not owns_decor(state, decor_id):
		return 0
	var decor: Array = state.get("decor", [])
	decor.erase(decor_id)
	state["decor"] = decor
	var refund := int(floor(int(item.get("price", 0)) * Tuning.DECOR_SELL_REFUND_RATIO))
	state["acorns"] = int(state.get("acorns", 0)) + refund
	return refund


## Every tag carried by the decor currently on display.
static func owned_decor_tags(state: Dictionary, decor_catalog: Dictionary) -> Dictionary:
	var tags := {}
	for decor_id in state.get("decor", []):
		for tag in decor_catalog.get(decor_id, {}).get("tags", []):
			tags[tag] = int(tags.get(tag, 0)) + 1
	return tags


## A regular is likelier to turn up when the library is full of what they like.
static func spawn_weight(customer: Dictionary, decor_tags: Dictionary) -> int:
	var weight := 1
	for tag in customer.get("likes", []):
		if decor_tags.has(tag):
			weight += 1
	return weight


## The unlocked regulars a piece of decor would draw in, for the Furnish card.
static func attracted_regulars(item: Dictionary, state: Dictionary, customers_catalog: Dictionary) -> Array:
	var reputation: int = state.get("reputation", 0)
	var item_tags: Array = item.get("tags", [])
	var names: Array = []
	for customer_id in customers_catalog:
		var customer: Dictionary = customers_catalog[customer_id]
		if int(customer.get("unlockAtRep", 0)) > reputation:
			continue
		for tag in customer.get("likes", []):
			if item_tags.has(tag):
				names.append(customer.get("name", ""))
				break
	return names
