extends GutTest
## Covers OrdersLogic: shelf capacity, and the acorn/shelf-space limits on
## placing an order (SPEC.md: "The order can't exceed free shelf slots or
## current acorns").

var books_catalog := {
	"cheap-book": { "id": "cheap-book", "price": 10 },
	"pricey-book": { "id": "pricey-book", "price": 100 },
}


func _fresh_state(acorns: int, shelf_count: int, bookcases: int = 0) -> Dictionary:
	var shelf: Array = []
	for i in shelf_count:
		shelf.append({ "copyId": "copy-%d" % i, "bookId": "cheap-book", "lastLoanDay": null })
	return {
		"acorns": acorns,
		"shelf": shelf,
		"pendingOrder": [],
		"bookcases": bookcases,
	}


func test_shelf_capacity_is_base_plus_bookcases() -> void:
	assert_eq(OrdersLogic.shelf_capacity({ "bookcases": 0 }), 40)
	assert_eq(OrdersLogic.shelf_capacity({ "bookcases": 2 }), 60)


func test_shelf_capacity_is_capped_at_max() -> void:
	assert_eq(OrdersLogic.shelf_capacity({ "bookcases": 20 }), 100)


func test_can_place_order_within_budget_and_space() -> void:
	var state := _fresh_state(50, 10)
	assert_true(OrdersLogic.can_place_order(state, ["cheap-book"], books_catalog))


func test_cannot_place_order_over_budget() -> void:
	var state := _fresh_state(50, 10)
	assert_false(OrdersLogic.can_place_order(state, ["pricey-book"], books_catalog))


func test_cannot_place_order_over_shelf_space() -> void:
	var state := _fresh_state(200, 39)  # only 1 free slot
	assert_false(OrdersLogic.can_place_order(state, ["cheap-book", "cheap-book"], books_catalog))


func test_pending_order_reserves_shelf_space() -> void:
	var state := _fresh_state(200, 39)
	state["pendingOrder"] = ["cheap-book"]  # already reserves the 1 free slot
	assert_false(OrdersLogic.can_place_order(state, ["cheap-book"], books_catalog))


func test_place_order_deducts_acorns_and_queues_books() -> void:
	var state := _fresh_state(50, 10)
	var ok := OrdersLogic.place_order(state, ["cheap-book"], books_catalog)
	assert_true(ok)
	assert_eq(state["acorns"], 40)
	assert_eq(state["pendingOrder"], ["cheap-book"])


func test_place_order_rejected_leaves_state_unchanged() -> void:
	var state := _fresh_state(5, 10)
	var ok := OrdersLogic.place_order(state, ["pricey-book"], books_catalog)
	assert_false(ok)
	assert_eq(state["acorns"], 5)
	assert_eq(state["pendingOrder"], [])


func test_deliver_pending_order_moves_books_to_shelf() -> void:
	var state := _fresh_state(50, 0)
	state["pendingOrder"] = ["cheap-book", "cheap-book"]
	var delivered := OrdersLogic.deliver_pending_order(state)
	assert_eq(delivered.size(), 2)
	assert_eq(state["shelf"].size(), 2)
	assert_eq(state["pendingOrder"], [])


func test_weed_book_refunds_acorns_and_frees_slot() -> void:
	var state := _fresh_state(50, 1)
	var ok := OrdersLogic.weed_book(state, "copy-0")
	assert_true(ok)
	assert_eq(state["shelf"].size(), 0)
	assert_eq(state["acorns"], 55)


func test_weed_book_unknown_copy_returns_false() -> void:
	var state := _fresh_state(50, 1)
	var ok := OrdersLogic.weed_book(state, "does-not-exist")
	assert_false(ok)
	assert_eq(state["acorns"], 50)
