extends GutTest
## The isometric projection, and the snapping that lets a room be laid
## out by dragging pieces around.


func test_snap_lands_on_a_tile_centre() -> void:
	var near_origin := IsoGrid.tile_to_world(Vector2(2, 1)) + Vector2(9.0, -4.0)
	assert_almost_eq(IsoGrid.snap(near_origin), IsoGrid.tile_to_world(Vector2(2, 1)), Vector2.ONE)


func test_snap_to_half_tiles_allows_the_edge_between_two() -> void:
	# Where a wall stands: the boundary between tile (0, 0) and the tile
	# behind it, which whole-tile snapping cannot express.
	var edge := IsoGrid.tile_to_world(Vector2(0.0, -0.5))
	assert_almost_eq(IsoGrid.snap(edge + Vector2(5.0, 3.0), 0.5), edge, Vector2.ONE)
	assert_ne(IsoGrid.snap(edge, 1.0), edge)


func test_snap_is_the_inverse_of_tile_to_world() -> void:
	for tile in [Vector2(0, 0), Vector2(3, 2), Vector2(-1, 4)]:
		assert_almost_eq(IsoGrid.snap(IsoGrid.tile_to_world(tile)),
			IsoGrid.tile_to_world(tile), Vector2.ONE)


func test_half_steps_reach_the_back_middle_and_front_of_a_tile() -> void:
	# What half-tile snapping buys: a piece can sit against the wall behind
	# a tile, in its middle, or at its front edge.
	var middle := IsoGrid.tile_to_world(Vector2(2, 2))
	var back := IsoGrid.tile_to_world(Vector2(2, 1.5))
	var front := IsoGrid.tile_to_world(Vector2(2, 2.5))
	for spot in [middle, back, front]:
		assert_almost_eq(IsoGrid.snap(spot, 0.5), spot, Vector2.ONE)
	# whole tiles cannot express them: anything short of the next tile's
	# half-way line collapses onto the middle.
	assert_almost_eq(IsoGrid.snap(IsoGrid.tile_to_world(Vector2(2, 1.6)), 1.0),
		middle, Vector2.ONE)
	assert_almost_eq(IsoGrid.snap(IsoGrid.tile_to_world(Vector2(2, 2.4)), 1.0),
		middle, Vector2.ONE)


func test_quarter_steps_are_finer_still() -> void:
	var quarter := IsoGrid.tile_to_world(Vector2(2, 1.75))
	assert_almost_eq(IsoGrid.snap(quarter, 0.25), quarter, Vector2.ONE)
	assert_ne(IsoGrid.snap(quarter, 0.5), quarter)


func test_snapping_defaults_to_half_tiles() -> void:
	# The project default: placing anything without saying how finely should
	# allow tile edges, not just centres.
	var edge := IsoGrid.tile_to_world(Vector2(2, 1.5))
	assert_almost_eq(IsoGrid.snap(edge), edge, Vector2.ONE)
