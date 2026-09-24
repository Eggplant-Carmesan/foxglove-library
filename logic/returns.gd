class_name ReturnsLogic
extends RefCounted
## Turns a match score into hearts/reputation/tip, and applies a loan's
## return to a GameState dictionary: shelves the copy, pays out rewards,
## and reveals one new discovered tag for that customer.

## Maps a score to { hearts, reputation, tip } per SPEC.md's table.
static func rewards_for_score(score: int) -> Dictionary:
	for row in Tuning.SCORE_REWARD_TABLE:
		if score >= row["min_score"]:
			return { "hearts": row["hearts"], "reputation": row["reputation"], "tip": row["tip"] }
	return Tuning.SCORE_REWARD_FLOOR.duplicate()


## The same table read by heart count, so rewards stay consistent when a
## loan's hearts are floored or capped.
static func rewards_for_hearts(hearts: int) -> Dictionary:
	for row in Tuning.SCORE_REWARD_TABLE:
		if row["hearts"] == hearts:
			return { "hearts": row["hearts"], "reputation": row["reputation"], "tip": row["tip"] }
	return Tuning.SCORE_REWARD_FLOOR.duplicate()


## Handing over a requested title guarantees a warm review; falling back to a
## suggestion after a miss caps how good it can be.
static func apply_heart_limits(rewards: Dictionary, loan: Dictionary) -> Dictionary:
	var floor_hearts := int(loan.get("heartsFloor", 1))
	var cap_hearts := int(loan.get("heartsCap", 5))
	var hearts: int = clampi(rewards["hearts"], floor_hearts, cap_hearts)
	if hearts == rewards["hearts"]:
		return rewards
	return rewards_for_hearts(hearts)


## Picks one tag from the customer's likes/dislikes that hasn't been
## discovered yet, or "" if everything is already discovered.
static func pick_new_discovery(customer: Dictionary, already_discovered: Array, rng: RandomNumberGenerator) -> String:
	var likes: Array = customer.get("likes", [])
	var dislikes: Array = customer.get("dislikes", [])
	var candidates: Array = []
	for tag in likes + dislikes:
		if not already_discovered.has(tag):
			candidates.append(tag)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## The tag a review talks about: what worked for a warm review, what grated
## for a cold one, falling back to any tag the book actually has.
static func review_tag(hearts: int, book: Dictionary, matched: Array, clashing: Array, rng: RandomNumberGenerator) -> String:
	var preferred: Array = matched if hearts >= 3 else clashing
	var fallback: Array = clashing if hearts >= 3 else matched
	var pool: Array = preferred
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		pool = book.get("tags", [])
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


## Fills one of the templates for this heart level with the book's title and
## a tag that explains the verdict.
static func build_review_line(templates: Dictionary, hearts: int, book: Dictionary, matched: Array, clashing: Array, rng: RandomNumberGenerator) -> String:
	var pool: Array = templates.get(str(hearts), [])
	if pool.is_empty():
		return ""
	var line: String = pool[rng.randi_range(0, pool.size() - 1)]
	return line \
		.replace("{title}", book.get("title", "")) \
		.replace("{tag}", MatchLogic.tag_label(review_tag(hearts, book, matched, clashing, rng)))


## Resolves a loan's return against state: books.gd/day.gd own creating the
## loan and putting it in the queue; this just settles it once it's due.
## Returns a result dictionary the UI can show in the Return modal.
static func process_return(state: Dictionary, loan: Dictionary, books_catalog: Dictionary, customers_catalog: Dictionary, rng: RandomNumberGenerator, review_templates: Dictionary = {}) -> Dictionary:
	var customer_id: String = loan.get("customerId", "")
	var book_id: String = loan.get("bookId", "")
	var book: Dictionary = books_catalog.get(book_id, {})
	# A passer-by's taste travels with the loan; regulars live in the catalog.
	var customer: Dictionary = loan.get("wanderer", customers_catalog.get(customer_id, {}))
	var request: Dictionary = loan.get("request", {})

	var random_factor := rng.randi_range(Tuning.MATCH_RANDOM_MIN, Tuning.MATCH_RANDOM_MAX)
	var score := MatchLogic.score_match(book, request, customer, random_factor)
	var rewards := apply_heart_limits(rewards_for_score(score), loan)
	var hearts: int = rewards["hearts"]

	var reputation: int = rewards["reputation"]
	if book.get("rare", false):
		reputation *= Tuning.RARE_BOOK_REPUTATION_MULTIPLIER

	var tip: int = rewards["tip"]
	if loan.get("special", false):
		reputation *= Tuning.SPECIAL_REQUEST_REWARD_MULTIPLIER
		tip *= Tuning.SPECIAL_REQUEST_REWARD_MULTIPLIER
	if AffinityLogic.is_patron(state, customer_id):
		tip += Tuning.AFFINITY_PATRON_TIP
	rewards["tip"] = tip

	state["acorns"] = int(state.get("acorns", 0)) + int(rewards["tip"])
	state["reputation"] = int(state.get("reputation", 0)) + reputation

	var shelf: Array = state.get("shelf", [])
	shelf.append({
		"copyId": loan.get("copyId"),
		"bookId": book_id,
		"lastLoanDay": state.get("day", 0),
	})
	state["shelf"] = shelf

	var discovered: Dictionary = state.get("discovered", {})
	var already: Array = discovered.get(customer_id, [])
	var new_tag := pick_new_discovery(customer, already, rng)
	if new_tag != "":
		already = already.duplicate()
		already.append(new_tag)
		discovered[customer_id] = already
		state["discovered"] = discovered

	var matched := MatchLogic.matched_tags(book, request, customer)
	var clashing := MatchLogic.clashing_tags(book, request, customer)
	var line := build_review_line(review_templates, hearts, book, matched, clashing, rng)

	var history: Array = state.get("history", [])
	history.append({
		"customerId": customer_id,
		"bookId": book_id,
		"hearts": hearts,
		"line": line,
		"day": state.get("day", 1),
	})
	state["history"] = history

	return {
		"score": score,
		"hearts": hearts,
		"reputation": reputation,
		"tip": rewards["tip"],
		"newTag": new_tag,
		"line": line,
		"matchedTags": matched,
		"clashingTags": clashing,
		"book": book,
		"customer": customer,
	}
