extends GutTest
## Covers furnishing: bookcase pricing and the capacity ceiling, room gating,
## decor slots and refunds, and the pull decor has on who visits.

var decor := {
	"lanterns": { "id": "lanterns", "name": "Lanterns", "tags": ["cozy", "fae"], "price": 35 },
	"drapes": { "id": "drapes", "name": "Drapes", "tags": ["gothic", "romance"], "price": 50 },
	"hearth": { "id": "hearth", "name": "Hearth", "tags": ["cozy"], "price": 60, "needsRoom": "nook" },
}

var customers := {
	"wren": { "id": "wren", "name": "Wren", "likes": ["cozy", "adventure"], "unlockAtRep": 0 },
	"veil": { "id": "veil", "name": "Lady Veil", "likes": ["gothic"], "unlockAtRep": 0 },
	"bramble": { "id": "bramble", "name": "Bramble", "likes": ["cozy"], "unlockAtRep": 10 },
}


func _state(acorns: int = 500, reputation: int = 0) -> Dictionary:
	return {
		"acorns": acorns, "reputation": reputation, "bookcases": 0,
		"shelf": [], "decor": [], "rooms": { "nook": false, "alcove": false },
	}


func test_bookcases_get_dearer_each_time() -> void:
	var state := _state()
	assert_eq(FurnishLogic.bookcase_price(state), 60)
	state["bookcases"] = 1
	assert_eq(FurnishLogic.bookcase_price(state), 90)
	state["bookcases"] = 2
	assert_eq(FurnishLogic.bookcase_price(state), 135)


func test_buying_a_bookcase_adds_slots_and_costs_acorns() -> void:
	var state := _state(100)
	assert_true(FurnishLogic.buy_bookcase(state))
	assert_eq(state["acorns"], 40)
	assert_eq(OrdersLogic.shelf_capacity(state), 50)


func test_cannot_buy_a_bookcase_you_cannot_afford() -> void:
	var state := _state(10)
	assert_false(FurnishLogic.buy_bookcase(state))
	assert_eq(state["acorns"], 10)


func test_shelf_capacity_stops_at_the_ceiling() -> void:
	var state := _state(100000)
	while FurnishLogic.can_buy_bookcase(state):
		FurnishLogic.buy_bookcase(state)
	assert_eq(OrdersLogic.shelf_capacity(state), Tuning.MAX_SHELF_CAPACITY)
	assert_true(FurnishLogic.bookcases_maxed(state))


## A room has to be earned with reputation before acorns matter.
func test_rooms_need_reputation_first() -> void:
	var poor_reputation := _state(1000, 0)
	assert_false(FurnishLogic.room_available(poor_reputation, FurnishLogic.NOOK))
	assert_false(FurnishLogic.can_buy_room(poor_reputation, FurnishLogic.NOOK))

	var earned := _state(1000, Tuning.ROOM_NOOK_UNLOCK_REP)
	assert_true(FurnishLogic.can_buy_room(earned, FurnishLogic.NOOK))
	assert_true(FurnishLogic.buy_room(earned, FurnishLogic.NOOK))
	assert_eq(earned["acorns"], 1000 - Tuning.ROOM_NOOK_COST)
	assert_true(FurnishLogic.owns_room(earned, FurnishLogic.NOOK))


func test_each_room_adds_decor_slots() -> void:
	var state := _state(1000, 50)
	assert_eq(FurnishLogic.decor_slots(state), Tuning.DECOR_SLOTS_BASE)
	FurnishLogic.buy_room(state, FurnishLogic.NOOK)
	assert_eq(FurnishLogic.decor_slots(state), Tuning.DECOR_SLOTS_BASE + 2)
	FurnishLogic.buy_room(state, FurnishLogic.ALCOVE)
	assert_eq(FurnishLogic.decor_slots(state), Tuning.DECOR_SLOTS_BASE + 4)


func test_decor_slots_are_limited() -> void:
	var state := _state()
	state["decor"] = ["a", "b", "c", "d"]
	assert_false(FurnishLogic.can_buy_decor(state, decor["lanterns"]), "all four slots are taken")


func test_decor_that_needs_a_room_waits_for_it() -> void:
	var state := _state()
	assert_true(FurnishLogic.decor_blocked_by_room(state, decor["hearth"]))
	assert_false(FurnishLogic.can_buy_decor(state, decor["hearth"]))
	state["rooms"]["nook"] = true
	assert_false(FurnishLogic.decor_blocked_by_room(state, decor["hearth"]))
	assert_true(FurnishLogic.can_buy_decor(state, decor["hearth"]))


func test_removing_decor_refunds_half() -> void:
	var state := _state(100)
	FurnishLogic.buy_decor(state, decor["drapes"])
	assert_eq(state["acorns"], 50)
	var refund := FurnishLogic.sell_decor(state, decor["drapes"])
	assert_eq(refund, 25)
	assert_eq(state["acorns"], 75)
	assert_false(FurnishLogic.owns_decor(state, "drapes"))


func test_owned_decor_tags_are_collected() -> void:
	var state := _state()
	state["decor"] = ["lanterns", "drapes"]
	var tags := FurnishLogic.owned_decor_tags(state, decor)
	assert_true(tags.has("cozy") and tags.has("fae") and tags.has("gothic"))
	assert_false(tags.has("sci-fi"))


## Gothic decor should make the gothic reader likelier to turn up.
func test_decor_raises_the_spawn_weight_of_matching_regulars() -> void:
	var gothic_tags := { "gothic": 1, "romance": 1 }
	var veil := FurnishLogic.spawn_weight(customers["veil"], gothic_tags)
	var wren := FurnishLogic.spawn_weight(customers["wren"], gothic_tags)
	assert_gt(veil, wren, "Lady Veil likes gothic; Wren doesn't")
	assert_eq(wren, 1, "no matching tags means the base weight")


func test_attracted_regulars_only_lists_ones_you_have_met() -> void:
	var state := _state(500, 0)
	var names := FurnishLogic.attracted_regulars(decor["lanterns"], state, customers)
	assert_true(names.has("Wren"))
	assert_false(names.has("Bramble"), "Bramble is not unlocked at 0 reputation")
