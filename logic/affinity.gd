class_name AffinityLogic
extends RefCounted
## How fond each regular is of the librarian, and what gifts do to that.

const LIKED := "liked"
const DISLIKED := "disliked"
const NEUTRAL := "neutral"


static func reaction_to(customer: Dictionary, gift_id: String) -> String:
	if customer.get("giftLikes", []).has(gift_id):
		return LIKED
	if customer.get("giftDislikes", []).has(gift_id):
		return DISLIKED
	return NEUTRAL


static func gain_for(reaction: String) -> int:
	match reaction:
		LIKED:
			return Tuning.GIFT_AFFINITY_LIKED
		DISLIKED:
			return Tuning.GIFT_AFFINITY_DISLIKED
		_:
			return Tuning.GIFT_AFFINITY_NEUTRAL


static func level(state: Dictionary, customer_id: String) -> int:
	return int(state.get("affinity", {}).get(customer_id, 0))


## Adds to a regular's affinity and returns the new level, capped.
static func award(state: Dictionary, customer_id: String, amount: int) -> int:
	if customer_id == "" or amount <= 0:
		return level(state, customer_id)
	var affinity: Dictionary = state.get("affinity", {})
	var next := mini(Tuning.AFFINITY_MAX, level(state, customer_id) + amount)
	affinity[customer_id] = next
	state["affinity"] = affinity
	return next


## A regular fond enough of you saves their one special request for you.
static func special_request_ready(state: Dictionary, customer_id: String) -> bool:
	if level(state, customer_id) < Tuning.AFFINITY_SPECIAL_REQUEST:
		return false
	return not state.get("specialUsed", {}).has(customer_id)


static func mark_special_used(state: Dictionary, customer_id: String) -> void:
	var used: Dictionary = state.get("specialUsed", {})
	used[customer_id] = true
	state["specialUsed"] = used


## At the top of the meter they tip on every visit, not just good ones.
static func is_patron(state: Dictionary, customer_id: String) -> bool:
	return level(state, customer_id) >= Tuning.AFFINITY_PATRON
