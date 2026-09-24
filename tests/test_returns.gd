extends GutTest
## Covers settling a return: the copy going back on the shelf, rewards being
## paid, a tag being discovered, and the review line landing in the journal.

var books := {
	"cozy-book": {
		"id": "cozy-book", "title": "A Cozy Book", "author": "Someone",
		"tags": ["cozy", "hopeful"],
	},
	"sad-book": {
		"id": "sad-book", "title": "A Sad Book", "author": "Someone Else",
		"tags": ["sad", "war"],
	},
	"rare-book": {
		"id": "rare-book", "title": "A Rare Book", "author": "Nobody",
		"tags": ["cozy"], "rare": true,
	},
}

var customers := {
	"wren": { "id": "wren", "name": "Wren", "likes": ["cozy"], "dislikes": ["sad", "war"] },
}

var templates := {
	"1": ["Too much {tag} for me, honestly. I won't finish {title}."],
	"2": ["{title} wasn't for me. A bit too {tag}."],
	"3": ["{title} was a decent way to spend an evening."],
	"4": ["I really enjoyed how {tag} {title} was."],
	"5": ["I loved how {tag} it was. {title} is going on my shelf forever."],
}

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7


func _state() -> Dictionary:
	return { "day": 5, "acorns": 100, "reputation": 0, "shelf": [], "loans": [], "discovered": {}, "history": [] }


func _loan(book_id: String, request: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var loan := {
		"copyId": "copy-1", "bookId": book_id, "customerId": "wren",
		"request": request, "dayOut": 2, "dayBack": 5,
	}
	loan.merge(extra)
	return loan


func test_return_puts_the_copy_back_on_the_shelf() -> void:
	var state := _state()
	ReturnsLogic.process_return(state, _loan("cozy-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)
	assert_eq(state["shelf"].size(), 1)
	assert_eq(state["shelf"][0]["bookId"], "cozy-book")
	assert_eq(state["shelf"][0]["lastLoanDay"], 5)


func test_good_match_pays_more_than_a_bad_one() -> void:
	var good := _state()
	var good_result := ReturnsLogic.process_return(good, _loan("cozy-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)

	var bad := _state()
	var bad_result := ReturnsLogic.process_return(bad, _loan("sad-book", { "wants": ["cozy"], "avoid": ["sad"] }), books, customers, _rng, templates)

	assert_gt(good_result["hearts"], bad_result["hearts"])
	assert_gt(good_result["reputation"], bad_result["reputation"])
	assert_gt(good_result["tip"], bad_result["tip"])
	assert_gt(int(good["acorns"]), int(bad["acorns"]))


func test_return_reveals_one_new_tag() -> void:
	var state := _state()
	var result := ReturnsLogic.process_return(state, _loan("cozy-book", { "wants": [], "avoid": [] }), books, customers, _rng, templates)
	assert_ne(result["newTag"], "")
	assert_eq(state["discovered"]["wren"], [result["newTag"]])


func test_return_writes_a_review_into_history() -> void:
	var state := _state()
	var result := ReturnsLogic.process_return(state, _loan("cozy-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)
	assert_eq(state["history"].size(), 1)
	var record: Dictionary = state["history"][0]
	assert_eq(record["customerId"], "wren")
	assert_eq(record["bookId"], "cozy-book")
	assert_eq(record["hearts"], result["hearts"])
	assert_eq(record["day"], 5)
	assert_eq(record["line"], result["line"])


func test_review_line_fills_in_title_and_tag() -> void:
	var state := _state()
	var result := ReturnsLogic.process_return(state, _loan("cozy-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)
	var line: String = result["line"]
	assert_string_contains(line, "A Cozy Book")
	assert_false(line.contains("{"), "no placeholder should survive: %s" % line)


func test_warm_review_talks_about_a_matching_tag() -> void:
	var tag := ReturnsLogic.review_tag(5, books["cozy-book"], ["cozy"], ["sad"], _rng)
	assert_eq(tag, "cozy")


func test_cold_review_talks_about_a_clashing_tag() -> void:
	var tag := ReturnsLogic.review_tag(1, books["sad-book"], ["adventure"], ["sad"], _rng)
	assert_eq(tag, "sad")


## With nothing matching or clashing, the line still needs a tag to talk about.
func test_review_tag_falls_back_to_a_book_tag() -> void:
	var tag := ReturnsLogic.review_tag(3, books["cozy-book"], [], [], _rng)
	assert_true(books["cozy-book"]["tags"].has(tag), "got %s" % tag)


func test_rare_book_earns_double_reputation() -> void:
	var plain := _state()
	var plain_result := ReturnsLogic.process_return(plain, _loan("cozy-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)

	_rng.seed = 7
	var rare := _state()
	var rare_result := ReturnsLogic.process_return(rare, _loan("rare-book", { "wants": ["cozy"], "avoid": [] }), books, customers, _rng, templates)

	assert_eq(rare_result["hearts"], plain_result["hearts"], "same match quality")
	assert_eq(int(rare_result["reputation"]), int(plain_result["reputation"]) * 2)


func test_hand_over_loan_guarantees_a_warm_review() -> void:
	var state := _state()
	# A book this customer would normally hate, handed over because they asked for it.
	var loan := _loan("sad-book", { "wants": [], "avoid": ["sad"] }, { "heartsFloor": 4 })
	var result := ReturnsLogic.process_return(state, loan, books, customers, _rng, templates)
	assert_gte(int(result["hearts"]), 4)
