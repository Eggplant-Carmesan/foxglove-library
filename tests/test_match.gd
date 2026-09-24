extends GutTest
## Covers MatchLogic.score_match: wants/likes/avoid/dislikes weighting and
## the pluggable random factor from SPEC.md's Matching table.


func test_wants_tag_scores_plus_three() -> void:
	var book := { "tags": ["cozy"] }
	var request := { "wants": ["cozy"], "avoid": [] }
	var customer := { "likes": [], "dislikes": [] }
	assert_eq(MatchLogic.score_match(book, request, customer), 3)


func test_customer_like_scores_plus_two() -> void:
	var book := { "tags": ["fae"] }
	var request := { "wants": [], "avoid": [] }
	var customer := { "likes": ["fae"], "dislikes": [] }
	assert_eq(MatchLogic.score_match(book, request, customer), 2)


func test_avoid_tag_scores_minus_four() -> void:
	var book := { "tags": ["sad"] }
	var request := { "wants": [], "avoid": ["sad"] }
	var customer := { "likes": [], "dislikes": [] }
	assert_eq(MatchLogic.score_match(book, request, customer), -4)


func test_customer_dislike_scores_minus_three() -> void:
	var book := { "tags": ["romance"] }
	var request := { "wants": [], "avoid": [] }
	var customer := { "likes": [], "dislikes": ["romance"] }
	assert_eq(MatchLogic.score_match(book, request, customer), -3)


func test_multiple_tags_sum_all_categories() -> void:
	# cozy: wants (+3) and likes (+2); sad: avoid (-4) and dislikes (-3) = -2
	var book := { "tags": ["cozy", "sad"] }
	var request := { "wants": ["cozy"], "avoid": ["sad"] }
	var customer := { "likes": ["cozy"], "dislikes": ["sad"] }
	assert_eq(MatchLogic.score_match(book, request, customer), -2)


func test_random_factor_is_added_verbatim() -> void:
	var book := { "tags": [] }
	var request := { "wants": [], "avoid": [] }
	var customer := { "likes": [], "dislikes": [] }
	assert_eq(MatchLogic.score_match(book, request, customer, -1), -1)
	assert_eq(MatchLogic.score_match(book, request, customer, 1), 1)


func test_no_matching_tags_scores_zero() -> void:
	var book := { "tags": ["mystery"] }
	var request := { "wants": ["adventure"], "avoid": ["dark"] }
	var customer := { "likes": ["funny"], "dislikes": ["gothic"] }
	assert_eq(MatchLogic.score_match(book, request, customer), 0)


func test_rewards_for_score_thresholds() -> void:
	assert_eq(ReturnsLogic.rewards_for_score(7), { "hearts": 5, "reputation": 12, "tip": 20 })
	assert_eq(ReturnsLogic.rewards_for_score(9), { "hearts": 5, "reputation": 12, "tip": 20 })
	assert_eq(ReturnsLogic.rewards_for_score(4), { "hearts": 4, "reputation": 7, "tip": 12 })
	assert_eq(ReturnsLogic.rewards_for_score(6), { "hearts": 4, "reputation": 7, "tip": 12 })
	assert_eq(ReturnsLogic.rewards_for_score(1), { "hearts": 3, "reputation": 3, "tip": 5 })
	assert_eq(ReturnsLogic.rewards_for_score(0), { "hearts": 2, "reputation": 0, "tip": 0 })
	assert_eq(ReturnsLogic.rewards_for_score(-2), { "hearts": 2, "reputation": 0, "tip": 0 })
	assert_eq(ReturnsLogic.rewards_for_score(-3), { "hearts": 1, "reputation": -2, "tip": 0 })
	assert_eq(ReturnsLogic.rewards_for_score(-100), { "hearts": 1, "reputation": -2, "tip": 0 })
