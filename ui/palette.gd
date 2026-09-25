class_name Palette
extends RefCounted
## Colors that scripts pick at runtime. The Theme resource carries its own
## copies as literals, so only what code actually reads lives here.

const MIST_TEXT := Color("#B9C2B0")

const SPINE_COLORS: Array[Color] = [
	Color("#7A3E3A"),
	Color("#3F5E6B"),
	Color("#8C6A2F"),
	Color("#4E6B3F"),
	Color("#5B4570"),
	Color("#A2553A"),
	Color("#2F4A44"),
	Color("#8A7B5A"),
	Color("#6B3550"),
	Color("#3C4F7A"),
]


## Stable hash of an id string, used to seed anything that must look the
## same for a given book or customer every time (color, spine size).
static func hash_id(id: String) -> int:
	var h := 0
	for i in id.length():
		h = (h * 31 + id.unicode_at(i)) & 0x7FFFFFFF
	return h


## Deterministic spine color for a book id, so a given book always
## looks the same without storing a color per book.
static func spine_color_for_id(id: String) -> Color:
	return SPINE_COLORS[hash_id(id) % SPINE_COLORS.size()]
