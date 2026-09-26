# Isometric art

Everything is **true 30° isometric**, drawn at **2×** and scaled to 0.5 in
game.

## Start from a template

`templates/` has one PNG per kind of object. Import the matching one into
Procreate as its own layer, draw on top of it, hide it, export. That is the
whole workflow — nothing below needs measuring.

Each template marks three things:

- **amber** — the footprint. The object sits *on* this shape. For a floor
  tile it is the tile itself; for a wall it is the single tile edge the wall
  stands along; for a bookcase it is the two tiles it covers.
- **magenta cross** — the anchor. See below.
- **faint blue** — surrounding floor tiles for context, and a height ruler
  ticked once per tile of height.

| Template | Canvas | Ink should span |
| --- | --- | --- |
| `template_floor.png` | 256 × 148 | the whole canvas |
| `template_wall_left.png` / `_right.png` | 256 × 512 | 128 wide, 384 tall |
| `template_bookcase.png` | 512 × 720 | 512 wide, ~560 tall |
| `template_spine_1..5.png` | 52–84 × 200 | the whole canvas |

The canvas is deliberately larger than the ink on the walls and the
bookcase. That margin is what makes the anchor come out right, so export at
the template's size rather than cropping to the drawing.

**The two walls are not interchangeable.** `left` stands along the room's
back-left edge and its base slopes **up** to the right; `right` stands along
the back-right edge and slopes **down** to the right. Swapping them makes a
wall run sawtooth instead of joining up. Each template already slopes the
right way, so draw on the one you mean.

There are five spine templates because the game picks a width from the book
id, narrowest first. Draw the same spine design on each.

## The anchor

The anchor is the one pixel the game steers by: **the point where the object
meets the floor**, at the centre of its footprint — not the centre of the
image. Place a bookcase at a tile and the anchor is what lands on that tile;
everything else hangs off it.

**You do not have to find it.** Every template puts the footprint's front
corner at the bottom centre of the canvas, so the anchor is a fixed distance
above that — 74px for anything one tile deep, 148px for the bookcase, whose
footprint is two tiles deep. The game reads it off the image size, so as long
as you draw on a template and export at the template's size, it is already
correct.

The magenta cross is there so you can see where the weight of the object
should fall while drawing, not so you can write the number down.

Two exceptions:

- A **spine** stands on a plank, not the floor, and books line up along the
  shelf from their front corner, so it anchors at the bottom **left** of its
  own art.
- A **book in flight** has no ground point, so it anchors at its own centre.

If you ever draw something without a template, set `art_anchor` on the scene
by hand and it wins over the calculated value.

## Sizes

One tile is 128 × 74 in game, so 256 × 148 drawn at 2×. One tile **edge** —
the module walls and shelves run along — is **128px wide at 2×**, rising 74.
Widths that are not a whole number of edges cannot tile.

| Thing | In game | Draw at 2× |
| --- | --- | --- |
| Floor tile | 128 × 74 | 256 × 148 |
| Wall segment, 1 tile | 64 × 192 | 128 × 384 |
| Bookcase, 2 tiles wide | 256 × 280 | 512 × 560 |
| Book spine | 26–42 × 100 | 52–84 × 200 |

A bookcase's shelves sit **240px apart at 2×**, which is what leaves room for
a 200px spine. Shelves drawn closer together than the books are tall is the
easiest way to make art that cannot be used.

## Folders

| Folder | Contents |
| --- | --- |
| `templates/` | the drawing templates above |
| `iso/structure/` | floor tiles, walls, corner, door, window, counter |
| `iso/books/` | spine variants (painted **white**), loose book in 3/4 |
| `iso/decor/` | the nine pieces named in `data/decor.json` |
| `iso/customers/` | seven regulars + a wanderer, bodies and faces separate |
| `iso/overlays/` | optional lighting passes, window glass sheen |

## Two rules that are expensive to undo

**Paint neutral.** The game multiplies a `CanvasModulate` over the scene to
shift morning to dusk. Baked-in warm light turns muddy under it. Keep
lighting on separate layers and export it to `iso/overlays/`.

**Spines are white.** The game tints each book from its id via
`Palette.spine_color_for_id`, so the base art has to be near-white — around
240 or brighter. Grey art comes out muted once the tint multiplies over it.

## Trying art out

Just run the game. The library is `scenes/zones/IsoHall.tscn` and it is
what the Library tab shows, so art appears at the real camera zoom with the
real save's books on the shelves. Press **L** to flip between the phone's
portrait frame and a 16:9 landscape one.

To rearrange the room, open `IsoHall.tscn`. The floor and the two wall runs
are `TileMapLayer`s — select one in the scene tree and paint with the
TileMap panel at the bottom of the editor. Bookcases are ordinary nodes
under `World/Props/Bookcases`: drag them and they snap to the grid.

### Adding a new floor or wall piece

Drop the PNG in `iso/structure/`, add it to `tools/make_tileset.gd`, and
run:

```
godot --headless --path . -s tools/make_tileset.gd
```

That reads each image's anchor with the same rule the templates are drawn
to and writes it into the tile's `texture_origin`, so a piece drawn on a
template needs no numbers typed anywhere. It rebuilds
`scenes/iso/room_tiles.tres` from scratch, so tweaks made by hand in the
TileSet editor are lost — change the script instead.

Spines are not tiles. They are nodes, because the game tints each one from
its book id and the shelf contents change daily.
