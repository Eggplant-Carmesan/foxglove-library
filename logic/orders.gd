class_name OrdersLogic
extends RefCounted
## Shelf capacity, order limits and order delivery. Operates on a GameState
## dictionary (see SPEC.md's GameState type) and a books catalog keyed by id.

static func shelf_capacity(state: Dictionary) -> int:
	var bookcases: int = state.get("bookcases", 0)
	return min(Tuning.BASE_SHELF_CAPACITY + Tuning.SHELF_SLOTS_PER_BOOKCASE * bookcases, Tuning.MAX_SHELF_CAPACITY)


## Slots not already taken by shelved copies or a pending order, so a
## second order the same day can't overbook space the first one reserved.
static func free_shelf_slots(state: Dictionary) -> int:
	var shelf: Array = state.get("shelf", [])
	var pending: Array = state.get("pendingOrder", [])
	return shelf_capacity(state) - shelf.size() - pending.size()


static func order_cost(book_ids: Array, books_catalog: Dictionary) -> int:
	var total := 0
	for id in book_ids:
		var book: Dictionary = books_catalog.get(id, {})
		total += int(book.get("price", 0))
	return total


static func can_place_order(state: Dictionary, book_ids: Array, books_catalog: Dictionary) -> bool:
	if book_ids.is_empty():
		return false
	if book_ids.size() > free_shelf_slots(state):
		return false
	if order_cost(book_ids, books_catalog) > int(state.get("acorns", 0)):
		return false
	return true


## Deducts acorns immediately and reserves shelf space; the books themselves
## arrive at the next start_day() via deliver_pending_order(). Returns false
## (no state change) if the order is over budget or over shelf space.
static func place_order(state: Dictionary, book_ids: Array, books_catalog: Dictionary) -> bool:
	if not can_place_order(state, book_ids, books_catalog):
		return false
	state["acorns"] = int(state.get("acorns", 0)) - order_cost(book_ids, books_catalog)
	var pending: Array = state.get("pendingOrder", [])
	pending.append_array(book_ids)
	state["pendingOrder"] = pending
	return true


## Turns pendingOrder book ids into shelf copies at the start of a new day.
## Returns the list of newly created ShelfCopy dictionaries.
static func deliver_pending_order(state: Dictionary) -> Array:
	var pending: Array = state.get("pendingOrder", [])
	var shelf: Array = state.get("shelf", [])
	var delivered: Array = []
	for i in pending.size():
		var book_id = pending[i]
		var copy := {
			"copyId": "%s-%d-%d" % [book_id, Time.get_ticks_usec(), i],
			"bookId": book_id,
			"lastLoanDay": null,
		}
		shelf.append(copy)
		delivered.append(copy)
	state["shelf"] = shelf
	state["pendingOrder"] = []
	return delivered


static func weed_book(state: Dictionary, copy_id: String) -> bool:
	var shelf: Array = state.get("shelf", [])
	for i in shelf.size():
		if shelf[i].get("copyId") == copy_id:
			shelf.remove_at(i)
			state["shelf"] = shelf
			state["acorns"] = int(state.get("acorns", 0)) + Tuning.WEED_REFUND
			return true
	return false


static func is_dusty(copy: Dictionary, current_day: int) -> bool:
	var last_loan = copy.get("lastLoanDay")
	if last_loan == null:
		return false
	return current_day - int(last_loan) >= Tuning.DUSTY_DAYS_THRESHOLD
