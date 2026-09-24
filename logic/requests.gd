class_name RequestLogic
extends RefCounted
## Specific-title requests: whether the asked-for book is available, and what
## turning the customer away costs.

const ON_SHELF := "on_shelf"
const OUT := "out"
const MISSING := "missing"


static func is_specific(request: Dictionary) -> bool:
	return request.get("bookId", "") != ""


## Whether a requested book is on the shelf, owned but loaned out, or not
## owned at all. Loans due back today have already moved into the queue,
## so those count as out too.
static func shelf_status(state: Dictionary, book_id: String) -> String:
	for copy in state.get("shelf", []):
		if copy.get("bookId") == book_id:
			return ON_SHELF
	for loan in state.get("loans", []):
		if loan.get("bookId") == book_id:
			return OUT
	for visit in state.get("queue", []):
		if visit.get("kind") == "return" and visit.get("loan", {}).get("bookId") == book_id:
			return OUT
	return MISSING


static func first_copy_on_shelf(state: Dictionary, book_id: String) -> String:
	for copy in state.get("shelf", []):
		if copy.get("bookId") == book_id:
			return copy.get("copyId", "")
	return ""


## Reputation change for not handing over a requested title.
static func decline_penalty(status: String) -> int:
	match status:
		OUT:
			return Tuning.SPECIFIC_OUT_REPUTATION
		MISSING:
			return Tuning.SPECIFIC_MISSING_REPUTATION
		_:
			return 0
