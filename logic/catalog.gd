class_name CatalogLogic
extends RefCounted
## Picks the books on offer in Orders each day: titles the library doesn't
## own yet, weighted towards what the current regulars like, plus any
## trending title the library is short of copies on.


## How many copies of each book the library has, wherever they currently are.
static func owned_counts(state: Dictionary) -> Dictionary:
	var counts := {}
	for copy in state.get("shelf", []):
		var shelf_id: String = copy.get("bookId", "")
		counts[shelf_id] = int(counts.get(shelf_id, 0)) + 1
	for loan in state.get("loans", []):
		var loan_id: String = loan.get("bookId", "")
		counts[loan_id] = int(counts.get(loan_id, 0)) + 1
	for visit in state.get("queue", []):
		if visit.get("kind") == "return":
			var due_id: String = visit.get("loan", {}).get("bookId", "")
			counts[due_id] = int(counts.get(due_id, 0)) + 1
	for pending_id in state.get("pendingOrder", []):
		counts[pending_id] = int(counts.get(pending_id, 0)) + 1
	return counts


## Tags liked by regulars who have actually been unlocked, so the catalog
## drifts towards the taste of the customers who are showing up.
static func liked_tag_counts(state: Dictionary, customers_catalog: Dictionary) -> Dictionary:
	var reputation: int = state.get("reputation", 0)
	var counts := {}
	for customer_id in customers_catalog:
		var customer: Dictionary = customers_catalog[customer_id]
		if int(customer.get("unlockAtRep", 0)) > reputation:
			continue
		for tag in customer.get("likes", []):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


static func weight_for(book: Dictionary, liked_tags: Dictionary) -> int:
	var matches := 0
	for tag in book.get("tags", []):
		if liked_tags.has(tag):
			matches += 1
	var popularity := maxi(1, int(book.get("popularity", 1)))
	return popularity * (1 + matches * Tuning.CATALOG_LIKED_TAG_BONUS)


static func roll(state: Dictionary, books_catalog: Dictionary, customers_catalog: Dictionary, rng: RandomNumberGenerator) -> Array:
	var owned := owned_counts(state)
	var liked := liked_tag_counts(state, customers_catalog)

	var has_alcove := FurnishLogic.owns_room(state, FurnishLogic.ALCOVE)
	var pool: Array = []
	var weights: Array = []
	for book_id in books_catalog:
		if owned.has(book_id):
			continue
		# Rare titles are only offered once there's an alcove to keep them in.
		if books_catalog[book_id].get("rare", false) and not has_alcove:
			continue
		pool.append(book_id)
		weights.append(weight_for(books_catalog[book_id], liked))

	var picks: Array = []
	while picks.size() < Tuning.CATALOG_SIZE and not pool.is_empty():
		var index := _pick_index(weights, rng)
		picks.append(pool[index])
		pool.remove_at(index)
		weights.remove_at(index)

	# The alcove was expensive; it should always have something rare to show.
	if has_alcove:
		var rare_pool: Array = []
		for book_id in books_catalog:
			if books_catalog[book_id].get("rare", false) and not owned.has(book_id) and not picks.has(book_id):
				rare_pool.append(book_id)
		if not rare_pool.is_empty():
			picks.append(rare_pool[rng.randi_range(0, rare_pool.size() - 1)])

	# A trending title the library is short on is always worth offering.
	for trending_id in state.get("trending", []):
		if not books_catalog.has(trending_id) or picks.has(trending_id):
			continue
		if int(owned.get(trending_id, 0)) < Tuning.CATALOG_TRENDING_COPY_THRESHOLD:
			picks.append(trending_id)

	return picks


static func _pick_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll_value := rng.randi_range(1, maxi(1, total))
	var running := 0
	for i in weights.size():
		running += int(weights[i])
		if roll_value <= running:
			return i
	return weights.size() - 1
