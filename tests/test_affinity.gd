extends GutTest
## Covers affinity: what gifts do to it, and the rewards it unlocks.

var customer := {
	"id": "wren", "name": "Wren",
	"likes": ["cozy"], "dislikes": ["sad"],
	"giftLikes": ["honey-cake", "acorn-cap-hat"],
	"giftDislikes": ["squid-ink"],
}


func _state() -> Dictionary:
	return { "affinity": {}, "specialUsed": {}, "acorns": 100 }


func test_gift_reactions_follow_the_customers_taste() -> void:
	assert_eq(AffinityLogic.reaction_to(customer, "honey-cake"), AffinityLogic.LIKED)
	assert_eq(AffinityLogic.reaction_to(customer, "squid-ink"), AffinityLogic.DISLIKED)
	assert_eq(AffinityLogic.reaction_to(customer, "moonlit-tea"), AffinityLogic.NEUTRAL)


func test_a_liked_gift_is_worth_more_than_a_neutral_one() -> void:
	assert_eq(AffinityLogic.gain_for(AffinityLogic.LIKED), 2)
	assert_eq(AffinityLogic.gain_for(AffinityLogic.NEUTRAL), 1)
	assert_eq(AffinityLogic.gain_for(AffinityLogic.DISLIKED), 0)


func test_affinity_climbs_and_stops_at_the_top() -> void:
	var state := _state()
	assert_eq(AffinityLogic.award(state, "wren", 2), 2)
	assert_eq(AffinityLogic.award(state, "wren", 2), 4)
	assert_eq(AffinityLogic.award(state, "wren", 2), Tuning.AFFINITY_MAX)
	assert_eq(AffinityLogic.award(state, "wren", 2), Tuning.AFFINITY_MAX, "cannot go past the cap")


func test_a_disliked_gift_does_not_move_the_meter() -> void:
	var state := _state()
	AffinityLogic.award(state, "wren", AffinityLogic.gain_for(AffinityLogic.DISLIKED))
	assert_eq(AffinityLogic.level(state, "wren"), 0)


func test_special_request_waits_for_affinity_four() -> void:
	var state := _state()
	AffinityLogic.award(state, "wren", 3)
	assert_false(AffinityLogic.special_request_ready(state, "wren"))
	AffinityLogic.award(state, "wren", 1)
	assert_true(AffinityLogic.special_request_ready(state, "wren"))


func test_special_request_is_only_offered_once() -> void:
	var state := _state()
	AffinityLogic.award(state, "wren", 4)
	assert_true(AffinityLogic.special_request_ready(state, "wren"))
	AffinityLogic.mark_special_used(state, "wren")
	assert_false(AffinityLogic.special_request_ready(state, "wren"))


func test_patron_status_arrives_at_five() -> void:
	var state := _state()
	AffinityLogic.award(state, "wren", 4)
	assert_false(AffinityLogic.is_patron(state, "wren"))
	AffinityLogic.award(state, "wren", 1)
	assert_true(AffinityLogic.is_patron(state, "wren"))


## A special request pays triple, and a patron tips on top of that.
func test_special_request_and_patron_tip_stack_on_a_return() -> void:
	var books := { "b": { "id": "b", "title": "A Book", "tags": ["cozy"] } }
	var customers := { "wren": customer }
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	var plain := { "day": 2, "acorns": 0, "reputation": 0, "shelf": [], "discovered": {}, "history": [], "affinity": {} }
	var plain_loan := { "copyId": "c", "bookId": "b", "customerId": "wren", "request": { "wants": ["cozy"], "avoid": [] } }
	var plain_result := ReturnsLogic.process_return(plain, plain_loan, books, customers, rng, {})

	rng.seed = 5
	var special := { "day": 2, "acorns": 0, "reputation": 0, "shelf": [], "discovered": {}, "history": [], "affinity": { "wren": 5 } }
	var special_loan := plain_loan.duplicate(true)
	special_loan["special"] = true
	var special_result := ReturnsLogic.process_return(special, special_loan, books, customers, rng, {})

	assert_eq(int(special_result["reputation"]), int(plain_result["reputation"]) * 3, "triple reputation")
	assert_eq(
		int(special_result["tip"]),
		int(plain_result["tip"]) * 3 + Tuning.AFFINITY_PATRON_TIP,
		"triple tip plus the patron's standing tip")
