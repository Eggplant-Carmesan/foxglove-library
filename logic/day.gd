class_name DayLogic
extends RefCounted
## The day loop: starting a new day (income, delivery, trending, catalog) and
## generating the day's queue of visits.
##
## `data` bundles the static catalogs: { books, customers, decor, dialog }.

static func unlocked_customer_ids(state: Dictionary, customers_catalog: Dictionary) -> Array:
	var reputation: int = state.get("reputation", 0)
	var rooms: Dictionary = state.get("rooms", {})
	var result: Array = []
	for id in customers_catalog.keys():
		var customer: Dictionary = customers_catalog[id]
		var needs_room: String = customer.get("needsRoom", "")
		if needs_room != "":
			if bool(rooms.get(needs_room, false)):
				result.append(id)
			continue
		if int(customer.get("unlockAtRep", 0)) <= reputation:
			result.append(id)
	return result


## A blank tally for the day's comings and goings, read by the day summary.
static func new_day_log() -> Dictionary:
	return {
		"loansOut": 0,
		"returns": 0,
		"acorns": 0,
		"reputation": 0,
		"missed": [],
		"unlocked": [],
	}


## Splits state.loans into { due: [loans due today], remaining: [loans still out] }.
static func split_due_loans(state: Dictionary) -> Dictionary:
	var loans: Array = state.get("loans", [])
	var day: int = state.get("day", 1)
	var due: Array = []
	var remaining: Array = []
	for loan in loans:
		if int(loan.get("dayBack", 0)) <= day:
			due.append(loan)
		else:
			remaining.append(loan)
	return { "due": due, "remaining": remaining }


static func generate_new_request_visit(state: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var customers_catalog: Dictionary = data.get("customers", {})
	var books_catalog: Dictionary = data.get("books", {})
	var unlocked := unlocked_customer_ids(state, customers_catalog)
	if unlocked.is_empty():
		return {}

	var decor_tags := FurnishLogic.owned_decor_tags(state, data.get("decor", {}))

	# A library furnished to someone's taste sees more of them.
	var weights: Array = []
	for customer_id in unlocked:
		weights.append(FurnishLogic.spawn_weight(customers_catalog[customer_id], decor_tags))
	var customer_id: String = unlocked[weighted_index(weights, rng)]
	var customer: Dictionary = customers_catalog[customer_id]

	var special := AffinityLogic.special_request_ready(state, customer_id)
	var request: Dictionary = customer.get("specialRequest", {}).duplicate(true) if special \
		else _pick_request(customer, decor_tags, rng)
	if request.is_empty():
		return {}
	if special:
		request["special"] = true

	if not special and rng.randf() < Tuning.SPECIFIC_REQUEST_CHANCE:
		_make_specific(state, request, books_catalog, data.get("dialog", {}), rng)

	return {
		"kind": "request",
		"customerId": customer_id,
		"request": request,
		"questionsLeft": Tuning.QUESTIONS_PER_REQUEST,
	}


## Requests that chime with the decor on display come up more often.
static func _pick_request(customer: Dictionary, decor_tags: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var requests: Array = customer.get("requests", [])
	if requests.is_empty():
		return {}
	var weights: Array = []
	for request in requests:
		var weight := 1
		for tag in request.get("wants", []):
			if decor_tags.has(tag):
				weight += 1
		weights.append(weight)
	return requests[weighted_index(weights, rng)].duplicate(true)


static func _make_specific(state: Dictionary, request: Dictionary, books_catalog: Dictionary, dialog: Dictionary, rng: RandomNumberGenerator) -> void:
	var book_id := ""
	var trending: Array = state.get("trending", [])
	if not trending.is_empty() and rng.randf() < Tuning.SPECIFIC_FROM_TRENDING_CHANCE:
		book_id = trending[rng.randi_range(0, trending.size() - 1)]
	else:
		var picked := TrendingLogic.pick_weighted(books_catalog, 1, [], rng)
		if not picked.is_empty():
			book_id = picked[0]
	if book_id == "":
		return

	request["bookId"] = book_id
	var templates: Array = dialog.get("specific_request", [])
	if not templates.is_empty():
		var template: String = templates[rng.randi_range(0, templates.size() - 1)]
		request["text"] = template.replace("{title}", books_catalog.get(book_id, {}).get("title", ""))


## Once there's decor to catch the eye, passers-by start wandering in. They
## aren't regulars, so they carry their own details on the visit.
static func generate_wanderer_visit(state: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var decor_tags := FurnishLogic.owned_decor_tags(state, data.get("decor", {}))
	if decor_tags.is_empty():
		return {}

	var tags: Array = decor_tags.keys()
	var tag: String = tags[rng.randi_range(0, tags.size() - 1)]
	var dialog: Dictionary = data.get("dialog", {})
	var text: String = _pick_line(dialog.get("wanderer_requests", []), rng).replace("{tag}", MatchLogic.tag_label(tag))

	return {
		"kind": "request",
		"customerId": "",
		"wanderer": {
			"id": "wanderer-%d" % int(state.get("day", 1)),
			"name": _pick_line(dialog.get("wanderer_names", []), rng),
			"description": _pick_line(dialog.get("wanderer_descriptions", []), rng),
			"likes": [tag],
			"dislikes": [],
		},
		"request": { "text": text, "wants": [tag], "avoid": [] },
		"questionsLeft": Tuning.QUESTIONS_PER_REQUEST,
	}


## Builds today's queue: every loan due today becomes a return visit, topped
## off with new requests. The Reading Nook brings one extra visitor a day.
static func generate_queue(state: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> Array:
	var split := split_due_loans(state)
	state["loans"] = split["remaining"]

	var queue: Array = []
	for loan in split["due"]:
		queue.append({ "kind": "return", "loan": loan })

	var target_size := rng.randi_range(Tuning.QUEUE_SIZE_MIN, Tuning.QUEUE_SIZE_MAX)
	if FurnishLogic.owns_room(state, FurnishLogic.NOOK):
		target_size += 1

	if queue.size() < target_size:
		var wanderer := generate_wanderer_visit(state, data, rng)
		if not wanderer.is_empty():
			queue.append(wanderer)

	while queue.size() < target_size:
		var visit := generate_new_request_visit(state, data, rng)
		if visit.is_empty():
			break
		queue.append(visit)

	state["queue"] = queue
	return queue


## Creates a Loan from a recommended shelf copy and removes the copy from
## the shelf. Short books read in the Nook come back the same evening.
static func create_loan(state: Dictionary, copy_id: String, customer_id: String, request: Dictionary, rng: RandomNumberGenerator, extra: Dictionary = {}) -> Dictionary:
	var shelf: Array = state.get("shelf", [])
	var book_id := ""
	for i in shelf.size():
		if shelf[i].get("copyId") == copy_id:
			book_id = shelf[i].get("bookId", "")
			shelf.remove_at(i)
			break
	state["shelf"] = shelf

	var day: int = state.get("day", 1)
	var loan := {
		"copyId": copy_id,
		"bookId": book_id,
		"customerId": customer_id,
		"request": request,
		"dayOut": day,
		"dayBack": day + rng.randi_range(Tuning.LOAN_RETURN_DAYS_MIN, Tuning.LOAN_RETURN_DAYS_MAX),
	}
	loan.merge(extra)

	var loans: Array = state.get("loans", [])
	loans.append(loan)
	state["loans"] = loans
	return loan


## True when a book is short enough to be read in the Nook before closing.
static func reads_in_nook(state: Dictionary, book: Dictionary) -> bool:
	return FurnishLogic.owns_room(state, FurnishLogic.NOOK) and book.get("tags", []).has("short")


## Advances the day: delivers yesterday's order, pays daily income, advances
## trending, rolls a new catalog and generates the queue.
static func start_day(state: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var books_catalog: Dictionary = data.get("books", {})
	var customers_catalog: Dictionary = data.get("customers", {})

	state["day"] = int(state.get("day", 0)) + 1
	state["dayLog"] = new_day_log()
	state["giftedToday"] = []
	var delivered := OrdersLogic.deliver_pending_order(state)
	state["acorns"] = int(state.get("acorns", 0)) + Tuning.DAILY_INCOME
	var trending_result := TrendingLogic.advance(state, books_catalog, rng)
	state["catalogToday"] = CatalogLogic.roll(state, books_catalog, customers_catalog, rng)
	var queue := generate_queue(state, data, rng)

	return {
		"day": state["day"],
		"delivered": delivered,
		"dailyIncome": Tuning.DAILY_INCOME,
		"trending": trending_result,
		"queue": queue,
	}


static func weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll_value := rng.randi_range(1, maxi(1, total))
	var running := 0
	for i in weights.size():
		running += int(weights[i])
		if roll_value <= running:
			return i
	return maxi(0, weights.size() - 1)


static func _pick_line(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
