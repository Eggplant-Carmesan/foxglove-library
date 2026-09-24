class_name Bookcase
extends Node2D
## One bookcase: two planks of five spines each. The frame and planks live
## in the .tscn; spines are instanced per copy because the shelf contents
## change every day.

const SPINE_SCENE := preload("res://scenes/Spine.tscn")
const SLOTS_PER_PLANK := 5
const SLOTS := 10
const SPINE_GAP := 2.0

var spines: Array[Spine] = []


func set_copies(copies: Array) -> void:
	for spine in spines:
		spine.queue_free()
	spines.clear()

	var planks: Array[Node2D] = [$Shelf1, $Shelf2]
	var next_x: Array[float] = [0.0, 0.0]

	for i in mini(copies.size(), SLOTS):
		var plank_index := i / SLOTS_PER_PLANK
		var spine: Spine = SPINE_SCENE.instantiate()
		planks[plank_index].add_child(spine)
		spine.setup(copies[i])
		spine.position.x = next_x[plank_index]
		next_x[plank_index] += spine.spine_width + SPINE_GAP
		spines.append(spine)


## The spine whose rectangle contains a world point, or null.
func spine_at(world_point: Vector2) -> Spine:
	for spine in spines:
		if spine.get_world_rect().has_point(world_point):
			return spine
	return null
