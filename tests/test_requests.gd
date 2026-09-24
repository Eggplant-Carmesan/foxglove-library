extends GutTest
## Covers RequestLogic (is the asked-for title available, what does turning
## them away cost) and the heart floor/cap that specific requests put on a
## loan's eventual review.


func _state_with(shelf_ids: Array, loan_ids: Array = [], queue_return_ids: Array = []) -> Dictionary:
	var shelf: Array = []
	for i in shelf_ids.size():
		shelf.append({ "copyId": "copy-%d" % i, "bookId": shelf_ids[i], "lastLoanDay": null })
	var loans: Array = []
	for id in loan_ids:
		loans.append({ "copyId": "out-%s" % id, "bookId": id })
	var queue: Array = []
	for id in queue_return_ids:
		queue.append({ "kind": "return", "loan": { "bookId": id } })
	return { "shelf": shelf, "loans": loans, "queue": queue }


func test_is_specific_only_when_a_title_is_named() -> void:
	assert_true(RequestLogic.is_specific({ "bookId": "dune" }))
	assert_false(RequestLogic.is_specific({ "wants": ["cozy"] }))
	assert_false(RequestLogic.is_specific({ "bookId": "" }))


func test_status_on_shelf() -> void:
	var state := _state_with(["dune"])
	assert_eq(RequestLogic.shelf_status(state, "dune"), RequestLogic.ON_SHELF)


func test_status_out_when_all_copies_loaned() -> void:
	var state := _state_with([], ["dune"])
	assert_eq(RequestLogic.shelf_status(state, "dune"), RequestLogic.OUT)


## A loan due back today has already moved out of loans and into the queue,
## but the book still isn't on the shelf to hand over.
func test_status_out_when_due_back_today() -> void:
	var state := _state_with([], [], ["dune"])
	assert_eq(RequestLogic.shelf_status(state, "dune"), RequestLogic.OUT)


func test_status_missing_when_not_owned() -> void:
	var state := _state_with(["circe"])
	assert_eq(RequestLogic.shelf_status(state, "dune"), RequestLogic.MISSING)


func test_first_copy_on_shelf() -> void:
	var state := _state_with(["circe", "dune"])
	assert_eq(RequestLogic.first_copy_on_shelf(state, "dune"), "copy-1")
	assert_eq(RequestLogic.first_copy_on_shelf(state, "piranesi"), "")


func test_decline_penalties() -> void:
	assert_eq(RequestLogic.decline_penalty(RequestLogic.OUT), -2)
	assert_eq(RequestLogic.decline_penalty(RequestLogic.MISSING), -4)
	assert_eq(RequestLogic.decline_penalty(RequestLogic.ON_SHELF), 0)


func test_hearts_floor_lifts_a_weak_review() -> void:
	var rewards := ReturnsLogic.rewards_for_score(-5)
	assert_eq(rewards["hearts"], 1)
	var limited := ReturnsLogic.apply_heart_limits(rewards, { "heartsFloor": 4 })
	assert_eq(limited, { "hearts": 4, "reputation": 7, "tip": 12 })


func test_hearts_cap_holds_back_a_strong_review() -> void:
	var rewards := ReturnsLogic.rewards_for_score(9)
	assert_eq(rewards["hearts"], 5)
	var limited := ReturnsLogic.apply_heart_limits(rewards, { "heartsCap": 3 })
	assert_eq(limited, { "hearts": 3, "reputation": 3, "tip": 5 })


func test_hearts_within_limits_are_untouched() -> void:
	var rewards := ReturnsLogic.rewards_for_score(2)
	var limited := ReturnsLogic.apply_heart_limits(rewards, { "heartsCap": 3, "heartsFloor": 1 })
	assert_eq(limited, rewards)


func test_loan_carries_extra_fields() -> void:
	var state := { "shelf": [{ "copyId": "c1", "bookId": "dune", "lastLoanDay": null }], "loans": [], "day": 3 }
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var loan := DayLogic.create_loan(state, "c1", "wren", {}, rng, { "heartsCap": 3 })
	assert_eq(loan["heartsCap"], 3)
	assert_eq(loan["bookId"], "dune")
	assert_eq(state["shelf"].size(), 0)
	assert_eq(state["loans"].size(), 1)
