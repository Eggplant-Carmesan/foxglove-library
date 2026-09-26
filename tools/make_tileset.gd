extends SceneTree
## One-off: builds the room's TileSets from the art in art/iso/structure.
## Re-run it after adding or redrawing a piece.
##
## One TileSet per layer, not one shared between them. A shared palette
## offers every piece whichever layer is selected, and painting a wall onto
## the floor layer silently puts it at a tile centre instead of a tile edge
## — it looks like a bug in the wall art rather than a wrong layer.
##
## Source ids stay distinct across the three files (floor 0, right wall 1,
## left wall 2) so already-painted cells keep resolving.
##
## texture_origin comes from IsoGrid.anchor_for, the same rule the drawing
## templates are built to, so no per-piece numbers are typed by hand. Only
## the footprint depth differs: a floor tile is one tile deep, a wall stands
## on a line so its base rises half a tile.

const TILE := Vector2i(256, 148)


func _build(path: String, id: int, art: String, depth: float) -> void:
	var texture: Texture2D = load(art)
	if texture == null:
		push_error("missing art: " + art)
		return
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(texture.get_size())
	source.create_tile(Vector2i.ZERO)

	# Godot subtracts texture_origin when it draws, so this is the anchor
	# measured out from the region's centre.
	var anchor := IsoGrid.anchor_for(texture, depth)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = Vector2i(anchor - texture.get_size() * 0.5)
	data.y_sort_origin = 0

	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = TILE
	tile_set.add_source(source, id)

	var err := ResourceSaver.save(tile_set, path)
	print("  %-38s source %d  %-22s %dx%d  depth %.1f  origin %s  -> %s"
		% [path.get_file(), id, art.get_file(), texture.get_width(),
			texture.get_height(), depth, data.texture_origin, error_string(err)])


func _init() -> void:
	_build("res://scenes/iso/floor_tiles.tres", 0,
		"res://art/iso/structure/floor_plain.png", 1.0)
	# A wall's base is a line along one tile edge, so it rises half a tile.
	# back_right falls to the right; back_left rises to the right.
	_build("res://scenes/iso/wall_right_tiles.tres", 1,
		"res://art/iso/structure/wall_back_right.png", 0.5)
	_build("res://scenes/iso/wall_left_tiles.tres", 2,
		"res://art/iso/structure/wall_back_left.png", 0.5)
	quit()
