extends GutTest
## Both views of a bookcase read their order from ShelfLayout, so what
## matters is that it is stable and that it never points past the case.


func test_fills_one_plank_at_a_time_in_the_cases_own_order() -> void:
	assert_eq(ShelfLayout.plank_of(0, 3), 0)
	assert_eq(ShelfLayout.plank_of(2, 3), 0)
	assert_eq(ShelfLayout.plank_of(3, 3), 1)
	assert_eq(ShelfLayout.slot_of(3, 3), 0)
	assert_eq(ShelfLayout.slot_of(5, 3), 2)


## A book keeps its shelf whatever arrives after it, so the player can learn
## where their books are.
func test_a_books_place_does_not_move_when_the_shelf_grows() -> void:
	for count in range(1, 13):
		assert_eq(ShelfLayout.plank_of(4, 3), 1, "book 4 stays on the second shelf")
		assert_eq(ShelfLayout.slot_of(4, 3), 1, "and in the same slot")


func test_counts_run_out_on_the_last_plank() -> void:
	assert_eq(ShelfLayout.plank_counts(10, 4, 3), [3, 3, 3, 1] as Array[int])
	assert_eq(ShelfLayout.plank_counts(12, 4, 3), [3, 3, 3, 3] as Array[int])
	assert_eq(ShelfLayout.plank_counts(2, 4, 3), [2, 0, 0, 0] as Array[int])


func test_counts_never_exceed_the_case() -> void:
	assert_eq(ShelfLayout.plank_counts(99, 4, 3), [3, 3, 3, 3] as Array[int])
	assert_eq(ShelfLayout.capacity(4, 3), 12)


func test_empty_case_holds_nothing() -> void:
	assert_eq(ShelfLayout.plank_counts(0, 4, 3), [0, 0, 0, 0] as Array[int])
	assert_eq(ShelfLayout.capacity(0, 3), 0)


func test_first_index_on_each_plank() -> void:
	assert_eq(ShelfLayout.first_on_plank(0, 3), 0)
	assert_eq(ShelfLayout.first_on_plank(2, 3), 6)


## Guards the division, which a case with no slots configured would hit.
func test_a_case_with_no_slots_does_not_divide_by_zero() -> void:
	assert_eq(ShelfLayout.plank_of(5, 0), 5)
	assert_eq(ShelfLayout.slot_of(5, 0), 0)
