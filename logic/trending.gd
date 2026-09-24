class_name TrendingLogic
extends RefCounted
## Picks and rerolls the 3 trending book ids, weighted by popularity.

## Weighted-random pick of `count` distinct book ids, never returning
## anything in `exclude`.
static func pick_weighted(books_catalog: Dictionary, count: int, exclude: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var weights: Array = []
	for id in books_catalog.keys():
		if exclude.has(id):
			continue
		pool.append(id)
		weights.append(max(1, int(books_catalog[id].get("popularity", 1))))

	var picked: Array = []
	var remaining_pool := pool.duplicate()
	var remaining_weights := weights.duplicate()
	while picked.size() < count and not remaining_pool.is_empty():
		var total := 0
		for w in remaining_weights:
			total += w
		var roll := rng.randi_range(1, max(1, total))
		var running := 0
		var chosen_index := 0
		for i in remaining_weights.size():
			running += remaining_weights[i]
			if roll <= running:
				chosen_index = i
				break
		picked.append(remaining_pool[chosen_index])
		remaining_pool.remove_at(chosen_index)
		remaining_weights.remove_at(chosen_index)
	return picked


## If today reached the reroll day: promote nextTrending to trending and
## roll a fresh nextTrending. One day before that, just note which title
## to leak as the "Market whispers" rumor. Returns a summary for the day
## summary / start-of-day notice.
static func advance(state: Dictionary, books_catalog: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var day: int = state.get("day", 1)
	var reroll_day: int = state.get("trendingRerollDay", day + Tuning.TRENDING_REROLL_DAYS)
	var result := { "rerolled": false, "whisper_title": "" }

	if day >= reroll_day:
		var previous: Array = state.get("trending", [])
		var next: Array = state.get("nextTrending", [])
		if next.is_empty():
			next = pick_weighted(books_catalog, Tuning.TRENDING_COUNT, previous, rng)
		state["trending"] = next
		state["nextTrending"] = pick_weighted(books_catalog, Tuning.TRENDING_COUNT, next, rng)
		state["trendingRerollDay"] = day + Tuning.TRENDING_REROLL_DAYS
		result["rerolled"] = true
	elif day == reroll_day - 1:
		var upcoming: Array = state.get("nextTrending", [])
		if not upcoming.is_empty():
			var pick_id: String = upcoming[rng.randi_range(0, upcoming.size() - 1)]
			var book: Dictionary = books_catalog.get(pick_id, {})
			result["whisper_title"] = book.get("title", "")

	return result
