class_name ShelfLayout
extends RefCounted
## Which shelf of a bookcase a book stands on, and how far along it.
##
## The hall's isometric cases and the front-on view both read their order
## from here, so a book is on the same shelf, in the same place, whichever
## way the player is looking at it.

## Books fill a case one plank at a time, in whatever order the case lists
## its planks — floor shelf first, as the hall's cases are laid out. A book
## keeps its place when others arrive after it, so a part-filled case runs
## out on its last plank and a book the player has learned the place of
## stays where they left it.
static func plank_of(index: int, per_plank: int) -> int:
	return index / maxi(per_plank, 1)


## Where along its own plank a book stands, counting from the end the shelf
## fills from.
static func slot_of(index: int, per_plank: int) -> int:
	return index % maxi(per_plank, 1)


## How many books stand on each plank, top plank first. What the front-on
## view lays out a shelf at a time.
static func plank_counts(count: int, planks: int, per_plank: int) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(maxi(planks, 0))
	counts.fill(0)
	for i in mini(count, capacity(planks, per_plank)):
		counts[plank_of(i, per_plank)] += 1
	return counts


## Index of the first book on a plank, whether or not that book exists.
static func first_on_plank(plank: int, per_plank: int) -> int:
	return plank * per_plank


static func capacity(planks: int, per_plank: int) -> int:
	return maxi(planks, 0) * maxi(per_plank, 0)
