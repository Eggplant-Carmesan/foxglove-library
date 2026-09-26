extends Node
## Holds all game state and the static data catalogs it's built from.
## UI code should read state through this autoload and call its methods
## rather than poking res://logic/ directly, so saves stay consistent.

signal acorns_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal day_changed(new_day: int)
signal shelf_changed
signal queue_changed
signal visit_started(visit: Dictionary)
signal visit_completed(visit: Dictionary, result: Dictionary)
signal customer_unlocked(customer_id: String)
signal affinity_changed(customer_id: String, new_affinity: int)
signal state_loaded
signal state_reset

const SAVE_PATH := "user://save.json"

const DATA_PATHS := {
	"books": "res://data/books.json",
	"customers": "res://data/customers.json",
	"decor": "res://data/decor.json",
	"gifts": "res://data/gifts.json",
	"reviews": "res://data/reviews.json",
	"dialog": "res://data/dialog.json",
}

## Catalogs: static reference data, loaded once and never saved.
var books: Dictionary = {}
var customers: Dictionary = {}
var decor_catalog: Dictionary = {}
var gifts_catalog: Dictionary = {}
var review_templates: Dictionary = {}
var dialog: Dictionary = {}

## The mutable GameState dictionary (see SPEC.md's GameState type). Saved
## to and loaded from SAVE_PATH.
var state: Dictionary = {}

var rng := RandomNumberGenerator.new()

## Paces visitors through the door instead of having them all wait at once.
var _arrival_timer: Timer


func _ready() -> void:
	rng.randomize()
	_arrival_timer = Timer.new()
	_arrival_timer.one_shot = true
	_arrival_timer.timeout.connect(_on_arrival_due)
	add_child(_arrival_timer)

	_load_catalogs()
	if not load_game():
		new_game()
	_schedule_next_arrival(Tuning.FIRST_ARRIVAL_DELAY)


func _load_catalogs() -> void:
	books = _load_json_dict_by_id(DATA_PATHS["books"])
	customers = _load_json_dict_by_id(DATA_PATHS["customers"])
	decor_catalog = _load_json_dict_by_id(DATA_PATHS["decor"])
	gifts_catalog = _load_json_dict_by_id(DATA_PATHS["gifts"])
	review_templates = _load_json_value(DATA_PATHS["reviews"], {})
	dialog = _load_json_value(DATA_PATHS["dialog"], {})


static func _load_json_value(path: String, default_value):
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return default_value
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Failed to parse JSON: %s" % path)
		return default_value
	return parsed


## Loads a JSON array of records and re-keys it by each record's "id".
static func _load_json_dict_by_id(path: String) -> Dictionary:
	var records = _load_json_value(path, [])
	var by_id := {}
	for record in records:
		by_id[record.get("id")] = record
	return by_id


# --- New game / reset ---

func new_game() -> void:
	state = {
		"day": 1,
		"acorns": Tuning.STARTING_ACORNS,
		"reputation": Tuning.STARTING_REPUTATION,
		"shelf": _starting_shelf(),
		"loans": [],
		"queue": [],
		"discovered": {},
		"history": [],
		"pendingOrder": [],
		"catalogToday": [],
		"trending": TrendingLogic.pick_weighted(books, Tuning.TRENDING_COUNT, [], rng),
		"nextTrending": [],
		"trendingRerollDay": 1 + Tuning.TRENDING_REROLL_DAYS,
		"bookcases": 0,
		"rooms": { "nook": false, "alcove": false },
		"decor": [],
		"affinity": {},
		"giftedToday": [],
		"visits": {},
		"demandHints": {},
		"pendingArrivals": [],
		"visitsToday": 0,
		"specialUsed": {},
		"giftsKnown": {},
		"dayLog": DayLogic.new_day_log(),
	}
	state["nextTrending"] = TrendingLogic.pick_weighted(books, Tuning.TRENDING_COUNT, state["trending"], rng)
	state["catalogToday"] = CatalogLogic.roll(state, books, customers, rng)
	var visits := DayLogic.generate_day_visits(state, data(), rng)
	state["pendingArrivals"] = visits
	state["visitsToday"] = visits.size()
	_schedule_next_arrival(Tuning.FIRST_ARRIVAL_DELAY)

	save_game()
	state_reset.emit()
	day_changed.emit(state["day"])
	acorns_changed.emit(state["acorns"])
	reputation_changed.emit(state["reputation"])
	shelf_changed.emit()
	queue_changed.emit()


func _starting_shelf() -> Array:
	var ids := books.keys()
	ids.shuffle()
	var count: int = min(Tuning.STARTING_SHELF_BOOK_COUNT, ids.size())
	var shelf: Array = []
	for i in count:
		shelf.append({
			"copyId": "%s-start%d" % [ids[i], i],
			"bookId": ids[i],
			"lastLoanDay": null,
		})
	return shelf


# --- Persistence ---

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(state))
	file.close()


## Returns true if a save was found and loaded.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	state = parsed
	state_loaded.emit()
	day_changed.emit(state.get("day", 1))
	acorns_changed.emit(state.get("acorns", 0))
	reputation_changed.emit(state.get("reputation", 0))
	shelf_changed.emit()
	queue_changed.emit()
	return true


func reset_game() -> void:
	new_game()


# --- Day loop ---

func start_day() -> Dictionary:
	var summary := DayLogic.start_day(state, data(), rng)
	_schedule_next_arrival(Tuning.FIRST_ARRIVAL_DELAY)
	save_game()
	day_changed.emit(state["day"])
	acorns_changed.emit(state["acorns"])
	shelf_changed.emit()
	queue_changed.emit()
	return summary


# --- Arrivals ---
# The day's visitors wait outside and come in one at a time, so the player
# gets quiet stretches to browse, order and furnish between them.

func pending_arrivals() -> int:
	return state.get("pendingArrivals", []).size()


## How far through the day's visitors the player has worked, 0 to 1.
func day_progress() -> float:
	var total: int = maxi(1, int(state.get("visitsToday", 0)))
	var left: int = state.get("queue", []).size() + pending_arrivals()
	return clampf(1.0 - float(left) / float(total), 0.0, 1.0)


func _schedule_next_arrival(delay: float) -> void:
	if _arrival_timer == null:
		return
	if pending_arrivals() == 0:
		_arrival_timer.stop()
		return
	_arrival_timer.start(delay)


func _on_arrival_due() -> void:
	var pending: Array = state.get("pendingArrivals", [])
	if pending.is_empty():
		return
	var visit: Dictionary = pending.pop_front()
	var queue: Array = state.get("queue", [])
	queue.append(visit)
	state["queue"] = queue
	state["pendingArrivals"] = pending

	save_game()
	queue_changed.emit()
	_schedule_next_arrival(Tuning.ARRIVAL_INTERVAL)


# --- Queue ---

func current_visit() -> Dictionary:
	var queue: Array = state.get("queue", [])
	return queue[0] if not queue.is_empty() else {}


## Removes the visit at the head of the queue once it has been dealt with.
func dequeue_visit() -> Dictionary:
	var queue: Array = state.get("queue", [])
	if queue.is_empty():
		return {}
	var visit: Dictionary = queue.pop_front()
	state["queue"] = queue
	save_game()
	queue_changed.emit()
	return visit


## The customer behind a visit, whether it's a new request or a return.
func customer_for_visit(visit: Dictionary) -> Dictionary:
	if visit.is_empty():
		return {}
	if visit.get("kind") == "return":
		var loan: Dictionary = visit.get("loan", {})
		if loan.has("wanderer"):
			return loan["wanderer"]
		return customers.get(loan.get("customerId", ""), {})
	if visit.has("wanderer"):
		return visit["wanderer"]
	return customers.get(visit.get("customerId", ""), {})


# --- Shelf / orders ---

func shelf_copy(copy_id: String) -> Dictionary:
	for copy in state.get("shelf", []):
		if copy.get("copyId") == copy_id:
			return copy
	return {}


func copies_on_shelf(book_id: String) -> int:
	var count := 0
	for copy in state.get("shelf", []):
		if copy.get("bookId") == book_id:
			count += 1
	return count


## Loans that have come back (and left a review) plus the ones still out.
func times_loaned(book_id: String) -> int:
	var count := 0
	for record in state.get("history", []):
		if record.get("bookId") == book_id:
			count += 1
	for loan in state.get("loans", []):
		if loan.get("bookId") == book_id:
			count += 1
	return count


func is_trending(book_id: String) -> bool:
	return state.get("trending", []).has(book_id)


# --- Day log ---
# Running tally of the day's comings and goings, shown in the day summary.

func day_log() -> Dictionary:
	return state.get("dayLog", DayLogic.new_day_log())


func _log_add(key: String, amount: int) -> void:
	var tally := day_log()
	tally[key] = int(tally.get(key, 0)) + amount
	state["dayLog"] = tally


func _log_append(key: String, value: Variant) -> void:
	var tally := day_log()
	var list: Array = tally.get(key, [])
	list.append(value)
	tally[key] = list
	state["dayLog"] = tally


# --- Dialog ---

## The static catalogs the day logic reads from.
func data() -> Dictionary:
	return { "books": books, "customers": customers, "decor": decor_catalog, "dialog": dialog }


## One random line from a dialog pool, with {placeholders} filled in.
func dialog_line(key: String, replacements: Dictionary = {}) -> String:
	var pool: Array = dialog.get(key, [])
	if pool.is_empty():
		return ""
	var line: String = pool[rng.randi_range(0, pool.size() - 1)]
	for placeholder in replacements:
		line = line.replace("{%s}" % placeholder, str(replacements[placeholder]))
	return line


# --- Customer knowledge ---

func discovered_tags(customer_id: String) -> Array:
	return state.get("discovered", {}).get(customer_id, [])


## Likes and dislikes the player hasn't uncovered yet.
func hidden_tag_count(customer_id: String) -> int:
	var customer: Dictionary = customers.get(customer_id, {})
	var known := discovered_tags(customer_id)
	var total: int = customer.get("likes", []).size() + customer.get("dislikes", []).size()
	return maxi(0, total - known.size())


func visit_count(customer_id: String) -> int:
	return int(state.get("visits", {}).get(customer_id, 0))


func affinity_for(customer_id: String) -> int:
	return int(state.get("affinity", {}).get(customer_id, 0))


func unlocked_customer_ids() -> Array:
	return DayLogic.unlocked_customer_ids(state, customers)


## Likes the player has uncovered so far.
func journal_likes(customer_id: String) -> Array:
	var customer: Dictionary = customers.get(customer_id, {})
	var known := discovered_tags(customer_id)
	var result: Array = []
	for tag in customer.get("likes", []):
		if known.has(tag):
			result.append(tag)
	return result


## Dislikes uncovered so far — or all of them once a regular trusts you.
func journal_dislikes(customer_id: String) -> Array:
	var customer: Dictionary = customers.get(customer_id, {})
	var all_dislikes: Array = customer.get("dislikes", [])
	if affinity_for(customer_id) >= Tuning.AFFINITY_REVEAL_DISLIKES:
		return all_dislikes
	var known := discovered_tags(customer_id)
	var result: Array = []
	for tag in all_dislikes:
		if known.has(tag):
			result.append(tag)
	return result


## Their most recent reviews, newest first.
func recent_reviews(customer_id: String, limit: int) -> Array:
	var found: Array = []
	var history: Array = state.get("history", [])
	for i in range(history.size() - 1, -1, -1):
		if history[i].get("customerId") == customer_id:
			found.append(history[i])
			if found.size() >= limit:
				break
	return found


func note_visit(customer_id: String) -> void:
	if customer_id == "":
		return
	var visits: Dictionary = state.get("visits", {})
	visits[customer_id] = int(visits.get(customer_id, 0)) + 1
	state["visits"] = visits
	save_game()


## Spends the visit's question to reveal one hidden like or dislike.
func reveal_tag() -> Dictionary:
	var visit := current_visit()
	if int(visit.get("questionsLeft", 0)) <= 0:
		return {}

	visit["questionsLeft"] = int(visit.get("questionsLeft", 1)) - 1
	if visit.has("wanderer"):
		save_game()
		return { "tag": "", "line": dialog_line("ask_exhausted") }

	var customer_id: String = visit.get("customerId", "")
	var customer: Dictionary = customers.get(customer_id, {})
	var tag := ReturnsLogic.pick_new_discovery(customer, discovered_tags(customer_id), rng)

	if tag == "":
		save_game()
		return { "tag": "", "line": dialog_line("ask_exhausted") }

	var discovered: Dictionary = state.get("discovered", {})
	var known: Array = discovered_tags(customer_id).duplicate()
	known.append(tag)
	discovered[customer_id] = known
	state["discovered"] = discovered
	save_game()

	var liked: bool = customer.get("likes", []).has(tag)
	return {
		"tag": tag,
		"liked": liked,
		"line": dialog_line("ask_like" if liked else "ask_dislike", { "tag": tag }),
	}


# --- Gifts ---

## Whether the player has found out how this regular feels about a gift.
func gift_taste_known(customer_id: String, gift_id: String) -> bool:
	return state.get("giftsKnown", {}).get(customer_id, []).has(gift_id)


func _note_gift_taste(customer_id: String, gift_id: String) -> void:
	var known: Dictionary = state.get("giftsKnown", {})
	var list: Array = known.get(customer_id, []).duplicate()
	if not list.has(gift_id):
		list.append(gift_id)
	known[customer_id] = list
	state["giftsKnown"] = known


func gifted_today(customer_id: String) -> bool:
	return state.get("giftedToday", []).has(customer_id)


func can_afford_gift(gift: Dictionary) -> bool:
	return int(state.get("acorns", 0)) >= int(gift.get("price", 0))


## Buys the gift at the moment of giving and hands it over. A disliked gift
## still teaches the player something: the dislike comes out.
func give_gift(customer_id: String, gift_id: String) -> Dictionary:
	var gift: Dictionary = gifts_catalog.get(gift_id, {})
	if gift.is_empty() or gifted_today(customer_id) or not can_afford_gift(gift):
		return {}

	var customer: Dictionary = customers.get(customer_id, {})
	var reaction := AffinityLogic.reaction_to(customer, gift_id)

	state["acorns"] = int(state.get("acorns", 0)) - int(gift.get("price", 0))
	var gifted: Array = state.get("giftedToday", [])
	gifted.append(customer_id)
	state["giftedToday"] = gifted

	var affinity := AffinityLogic.award(state, customer_id, AffinityLogic.gain_for(reaction))
	_note_gift_taste(customer_id, gift_id)
	if reaction == AffinityLogic.DISLIKED:
		_reveal_gift_dislike(customer_id, gift_id)

	var rare_gift := ""
	if AffinityLogic.is_patron(state, customer_id):
		rare_gift = _receive_patron_book()

	save_game()
	acorns_changed.emit(state["acorns"])
	affinity_changed.emit(customer_id, affinity)
	if rare_gift != "":
		shelf_changed.emit()

	return {
		"reaction": reaction,
		"affinity": affinity,
		"line": dialog_line("gift_" + reaction),
		"rareGift": rare_gift,
	}


## Learning a gift is unwelcome also tells you which tag they can't stand.
func _reveal_gift_dislike(customer_id: String, _gift_id: String) -> void:
	var customer: Dictionary = customers.get(customer_id, {})
	var known := discovered_tags(customer_id)
	for tag in customer.get("dislikes", []):
		if not known.has(tag):
			var discovered: Dictionary = state.get("discovered", {})
			var updated: Array = known.duplicate()
			updated.append(tag)
			discovered[customer_id] = updated
			state["discovered"] = discovered
			return


## A regular at the top of the meter brings a rare book for the shelf.
func _receive_patron_book() -> String:
	if state.get("shelf", []).size() >= shelf_capacity():
		return ""
	var owned := CatalogLogic.owned_counts(state)
	var candidates: Array = []
	for book_id in books:
		if books[book_id].get("rare", false) and not owned.has(book_id):
			candidates.append(book_id)
	if candidates.is_empty():
		return ""
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var shelf: Array = state.get("shelf", [])
	shelf.append({
		"copyId": "%s-gift%d" % [chosen, state.get("day", 1)],
		"bookId": chosen,
		"lastLoanDay": null,
	})
	state["shelf"] = shelf
	return chosen


# --- Resolving a visit ---

## Lends a shelf copy to the customer at the counter and closes out the visit.
func recommend(copy_id: String) -> Dictionary:
	var visit := current_visit()
	if visit.is_empty():
		return {}

	var customer_id: String = visit.get("customerId", "")
	var request: Dictionary = visit.get("request", {})
	var book_id: String = shelf_copy(copy_id).get("bookId", "")

	var extra := {}
	if visit.has("heartsCap"):
		extra["heartsCap"] = visit["heartsCap"]
	if visit.has("wanderer"):
		extra["wanderer"] = visit["wanderer"]
	if request.get("special", false):
		extra["special"] = true
		AffinityLogic.mark_special_used(state, customer_id)
	if DayLogic.reads_in_nook(state, books.get(book_id, {})):
		extra["dayBack"] = state.get("day", 1)
	var loan := DayLogic.create_loan(state, copy_id, customer_id, request, rng, extra)

	var score := MatchLogic.score_match(books.get(book_id, {}), request, customers.get(customer_id, {}))
	var hearts: int = ReturnsLogic.apply_heart_limits(ReturnsLogic.rewards_for_score(score), loan)["hearts"]
	var tier := "good" if hearts >= 4 else ("neutral" if hearts == 3 else "poor")

	_log_add("loansOut", 1)
	dequeue_visit()
	shelf_changed.emit()
	save_game()
	return { "bookId": book_id, "line": dialog_line("reaction_" + tier), "loan": loan }


## Hands over the exact title the customer asked for.
func hand_over(copy_id: String) -> Dictionary:
	var visit := current_visit()
	if visit.is_empty():
		return {}

	var customer_id: String = visit.get("customerId", "")
	var request: Dictionary = visit.get("request", {})
	var book_id: String = shelf_copy(copy_id).get("bookId", "")

	add_reputation(Tuning.SPECIFIC_HAND_OVER_REPUTATION)
	state["acorns"] = int(state.get("acorns", 0)) + Tuning.SPECIFIC_HAND_OVER_TIP
	acorns_changed.emit(state["acorns"])

	DayLogic.create_loan(state, copy_id, customer_id, request, rng, { "heartsFloor": 4 })

	_log_add("loansOut", 1)
	_log_add("reputation", Tuning.SPECIFIC_HAND_OVER_REPUTATION)
	_log_add("acorns", Tuning.SPECIFIC_HAND_OVER_TIP)
	dequeue_visit()
	shelf_changed.emit()
	save_game()
	return {
		"bookId": book_id,
		"line": dialog_line("specific_hand_over"),
		"reputation": Tuning.SPECIFIC_HAND_OVER_REPUTATION,
		"tip": Tuning.SPECIFIC_HAND_OVER_TIP,
	}


## Turns away a specific request the library can't fill.
func decline_specific() -> Dictionary:
	var visit := current_visit()
	if visit.is_empty():
		return {}

	var book_id: String = visit.get("request", {}).get("bookId", "")
	var status := RequestLogic.shelf_status(state, book_id)
	var penalty := _apply_decline_penalty(visit, book_id, status)

	dequeue_visit()
	save_game()
	return {
		"line": dialog_line("specific_out" if status == RequestLogic.OUT else "specific_missing"),
		"reputation": penalty,
	}


## "Suggest something else": the miss is paid for first, then the fallback
## recommendation can only ever be so good.
func suggest_fallback() -> void:
	var visit := current_visit()
	if visit.is_empty():
		return
	var book_id: String = visit.get("request", {}).get("bookId", "")
	_apply_decline_penalty(visit, book_id, RequestLogic.shelf_status(state, book_id))
	visit["heartsCap"] = Tuning.SPECIFIC_SUGGEST_HEARTS_CAP
	save_game()


func _apply_decline_penalty(visit: Dictionary, book_id: String, status: String) -> int:
	var penalty := RequestLogic.decline_penalty(status)
	if penalty != 0:
		add_reputation(penalty)
		_log_add("reputation", penalty)
		_log_append("missed", {
			"customer": customer_for_visit(visit).get("name", ""),
			"title": books.get(book_id, {}).get("title", ""),
			"status": status,
		})
	if status == RequestLogic.MISSING:
		var hints: Dictionary = state.get("demandHints", {})
		hints[book_id] = customer_for_visit(visit).get("name", "")
		state["demandHints"] = hints
	return penalty



func shelf_capacity() -> int:
	return OrdersLogic.shelf_capacity(state)


func free_shelf_slots() -> int:
	return OrdersLogic.free_shelf_slots(state)


func place_order(book_ids: Array) -> bool:
	var ok := OrdersLogic.place_order(state, book_ids, books)
	if ok:
		save_game()
		acorns_changed.emit(state["acorns"])
	return ok


func weed_book(copy_id: String) -> bool:
	var ok := OrdersLogic.weed_book(state, copy_id)
	if ok:
		save_game()
		acorns_changed.emit(state["acorns"])
		shelf_changed.emit()
	return ok


# --- Reputation (with unlock checks) ---

func add_reputation(delta: int) -> void:
	var before: int = state.get("reputation", 0)
	var after := before + delta
	state["reputation"] = after
	reputation_changed.emit(after)
	check_unlocks(before, after)


## Announces any regular whose unlock threshold was just crossed. Callers that
## change reputation outside add_reputation (a return being settled in the
## logic layer, say) still have to report it.
func check_unlocks(before: int, after: int) -> void:
	for id in customers.keys():
		var unlock_at := int(customers[id].get("unlockAtRep", 0))
		if before < unlock_at and after >= unlock_at:
			_log_append("unlocked", id)
			customer_unlocked.emit(id)


# --- Returns ---

## Settles a due loan: shelves the copy, pays the tip and reputation, reveals
## a tag and writes the review into the journal.
func resolve_return(visit: Dictionary) -> Dictionary:
	var loan: Dictionary = visit.get("loan", {})
	if loan.is_empty():
		return {}

	var reputation_before: int = state.get("reputation", 0)
	var result := ReturnsLogic.process_return(state, loan, books, customers, rng, review_templates)

	var customer_id: String = loan.get("customerId", "")
	if int(result.get("hearts", 0)) >= Tuning.GIFT_AFFINITY_GOOD_RETURN_HEARTS_MIN and customer_id != "":
		var warmed := AffinityLogic.award(state, customer_id, Tuning.GIFT_AFFINITY_GOOD_RETURN_BONUS)
		result["affinity"] = warmed
		affinity_changed.emit(customer_id, warmed)

	_log_add("returns", 1)
	_log_add("acorns", int(result.get("tip", 0)))
	_log_add("reputation", int(result.get("reputation", 0)))
	dequeue_visit()
	save_game()
	acorns_changed.emit(state["acorns"])
	reputation_changed.emit(state["reputation"])
	check_unlocks(reputation_before, state.get("reputation", 0))
	shelf_changed.emit()
	return result


## The face a customer makes about their own review.
static func mood_for_hearts(hearts: int) -> String:
	if hearts >= 4:
		return "delighted"
	if hearts <= 2:
		return "sad"
	return "neutral"
