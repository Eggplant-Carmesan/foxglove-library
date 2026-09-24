extends GutTest
## Covers the Orders catalog: what counts as already owned, how taste weights
## the offer, and trending titles always being available to stock up on.

var books := {
	"cozy-a": { "id": "cozy-a", "title": "Cozy A", "tags": ["cozy"], "price": 15, "popularity": 3 },
	"cozy-b": { "id": "cozy-b", "title": "Cozy B", "tags": ["cozy"], "price": 15, "popularity": 3 },
	"war-a": { "id": "war-a", "title": "War A", "tags": ["war"], "price": 15, "popularity": 3 },
	"war-b": { "id": "war-b", "title": "War B", "tags": ["war"], "price": 15, "popularity": 3 },
	"war-c": { "id": "war-c", "title": "War C", "tags": ["war"], "price": 15, "popularity": 3 },
	"war-d": { "id": "war-d", "title": "War D", "tags": ["war"], "price": 15, "popularity": 3 },
	"war-e": { "id": "war-e", "title": "War E", "tags": ["war"], "price": 15, "popularity": 3 },
	"war-f": { "id": "war-f", "title": "War F", "tags": ["war"], "price": 15, "popularity": 3 },
}

var customers := {
	"wren": { "id": "wren", "likes": ["cozy"], "dislikes": [], "unlockAtRep": 0 },
	"bramble": { "id": "bramble", "likes": ["dark"], "dislikes": [], "unlockAtRep": 10 },
}

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 3


func _state() -> Dictionary:
	return {
		"reputation": 0, "shelf": [], "loans": [], "queue": [],
		"pendingOrder": [], "trending": [],
	}


func test_owned_counts_sees_every_copy() -> void:
	var state := _state()
	state["shelf"] = [{ "bookId": "cozy-a" }, { "bookId": "cozy-a" }]
	state["loans"] = [{ "bookId": "war-a" }]
	state["queue"] = [{ "kind": "return", "loan": { "bookId": "war-b" } }]
	state["pendingOrder"] = ["cozy-b"]

	var counts := CatalogLogic.owned_counts(state)
	assert_eq(counts["cozy-a"], 2, "two copies on the shelf")
	assert_eq(counts["war-a"], 1, "one out on loan")
	assert_eq(counts["war-b"], 1, "one due back today")
	assert_eq(counts["cozy-b"], 1, "one already ordered")


func test_catalog_offers_six_books() -> void:
	var picks := CatalogLogic.roll(_state(), books, customers, _rng)
	assert_eq(picks.size(), Tuning.CATALOG_SIZE)


func test_catalog_never_offers_a_book_already_owned() -> void:
	var state := _state()
	state["shelf"] = [{ "bookId": "cozy-a" }]
	state["loans"] = [{ "bookId": "war-a" }]
	state["pendingOrder"] = ["war-b"]

	var picks := CatalogLogic.roll(state, books, customers, _rng)
	assert_false(picks.has("cozy-a"), "on the shelf")
	assert_false(picks.has("war-a"), "out on loan")
	assert_false(picks.has("war-b"), "already ordered")


func test_catalog_has_no_duplicates() -> void:
	var picks := CatalogLogic.roll(_state(), books, customers, _rng)
	var seen := {}
	for id in picks:
		assert_false(seen.has(id), "%s offered twice" % id)
		seen[id] = true


## Only regulars who have actually been unlocked should shape the offer.
func test_locked_customers_do_not_shape_the_catalog() -> void:
	var liked := CatalogLogic.liked_tag_counts(_state(), customers)
	assert_true(liked.has("cozy"), "Wren is unlocked")
	assert_false(liked.has("dark"), "Bramble is not unlocked yet")

	var later := _state()
	later["reputation"] = 10
	assert_true(CatalogLogic.liked_tag_counts(later, customers).has("dark"))


func test_liked_tags_raise_a_books_weight() -> void:
	var liked := { "cozy": 1 }
	var cozy_weight := CatalogLogic.weight_for(books["cozy-a"], liked)
	var war_weight := CatalogLogic.weight_for(books["war-a"], liked)
	assert_gt(cozy_weight, war_weight, "a liked tag should be favoured")


func test_trending_book_is_offered_even_when_owned() -> void:
	var state := _state()
	state["shelf"] = [{ "bookId": "cozy-a" }]
	state["trending"] = ["cozy-a"]
	var picks := CatalogLogic.roll(state, books, customers, _rng)
	assert_true(picks.has("cozy-a"), "one copy is below the stock-up threshold")


func test_trending_book_is_dropped_once_well_stocked() -> void:
	var state := _state()
	state["shelf"] = [{ "bookId": "cozy-a" }, { "bookId": "cozy-a" }, { "bookId": "cozy-a" }]
	state["trending"] = ["cozy-a"]
	var picks := CatalogLogic.roll(state, books, customers, _rng)
	assert_false(picks.has("cozy-a"), "three copies is enough")


func test_catalog_copes_with_a_nearly_exhausted_library() -> void:
	var state := _state()
	for id in books:
		state["shelf"].append({ "bookId": id })
	var picks := CatalogLogic.roll(state, books, customers, _rng)
	assert_eq(picks, [], "nothing left to offer, and no crash")
