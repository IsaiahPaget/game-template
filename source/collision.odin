package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
COLLISION_TREE_CAPACITY :: 2
DEBUG_TREE :: false
CollisionLayerName :: enum {
	NIL,
	PLAYER,
	WORLD,
}

CollisionLayer :: bit_set[CollisionLayerName]

Collider :: struct {
	handle:    Handle,
	is_active: bool,
	rectangle: rl.Rectangle,
	layer:     CollisionLayer,
	mask:      CollisionLayer,
}

init_collider :: proc(
	entity: Entity,
	width: f32,
	height: f32,
	layer, mask: CollisionLayer,
) -> Collider {
	rectangle := rl.Rectangle {
		x      = entity.pos.x,
		y      = entity.pos.y,
		width  = width,
		height = height,
	}
	return Collider {
		handle = entity.handle,
		is_active = true,
		rectangle = rectangle,
		mask = mask,
		layer = layer,
	}
}

set_collision_layers :: proc(layers: []CollisionLayerName) -> CollisionLayer {
	mask: CollisionLayer
	for &layer in layers {
		mask |= {layer}
	}
	return mask
}

// WARNING: Colliders are always bottom center aligned
collision_box_update :: proc(e: ^Entity) {
	e.collider.rectangle.x = e.pos.x - (e.collider.rectangle.width / 2)
	e.collider.rectangle.y = e.pos.y - e.collider.rectangle.height
}

process_collisions :: proc() {

	g.scratch.collision_tree = collision_tree_create()

	for &ent_handle in entity_get_all() {
		ent := entity_get(ent_handle)
		if !ent.collider.is_active do continue
		fmt.assertf(ent.collider.is_active, "no point checking collider that is inactive")
		collision_tree_insert(g.scratch.collision_tree, ent.collider)
	}

	for &ent_handle in entity_get_all() {
		ent_a, ent_a_ok := entity_get(ent_handle)
		if !ent_a_ok do continue
		if !ent_a.collider.is_active do continue
		colliders := collision_tree_query(g.scratch.collision_tree, ent_a.collider)
		defer delete(colliders)

		for &collider in colliders {
			ent_b, ent_b_ok := entity_get(collider.handle)
			if !ent_b_ok do continue
			if !ent_a.collider.is_active do continue
			if ent_a.handle.id == ent_b.handle.id do continue

			if !rl.CheckCollisionRecs(ent_a.collider.rectangle, ent_b.collider.rectangle) do continue

			// Check if entity A should receive collision notification based on layer/mask
			if ent_b.collider.layer & ent_a.collider.mask != {} {
				ent_a.on_collide(ent_a, ent_b)
			}
		}
	}
}

debug_render_collision_tree :: proc(ct: ^CollisionTree, cur_depth: int = 0) -> (depth: int) {
	depth = cur_depth + 1
	max_depth := 0
	rl.DrawRectangleLinesEx(ct.bounding_box, 2, rl.ColorAlpha(rl.PINK, .5))
	if ct.nw != nil {
		max_depth = debug_render_collision_tree(ct.nw, cur_depth)
	}
	if ct.ne != nil {
		n := debug_render_collision_tree(ct.ne, cur_depth)
		if n > max_depth {
			max_depth = n
		}
	}
	if ct.sw != nil {
		n := debug_render_collision_tree(ct.sw, cur_depth)
		if n > max_depth {
			max_depth = n
		}
	}
	if ct.se != nil {
		n := debug_render_collision_tree(ct.se, cur_depth)
		if n > max_depth {
			max_depth = n
		}
	}

	return depth + max_depth
}

collide_move_and_slide :: proc(entity_a, entity_b: ^Entity) {
	entity_a_rect := entity_a.collider.rectangle
	entity_b_rect := entity_b.collider.rectangle

	overlap := get_rect_overlap(entity_a_rect, entity_b_rect)

	if overlap.x < overlap.y {
		// Push along X axis
		if entity_a_rect.x < entity_b_rect.x {
			entity_a.pos.x -= overlap.x
		} else {
			entity_a.pos.x += overlap.x
		}
	} else {
		// Push along Y axis
		if entity_a_rect.y < entity_b_rect.y {
			entity_a.pos.y -= overlap.y
		} else {
			entity_a.pos.y += overlap.y
		}
	}
}

get_rect_overlap :: proc(a, b: rl.Rectangle) -> rl.Vector2 {
	overlap_x := f32(math.min(a.x + a.width, b.x + b.width) - math.max(a.x, b.x))
	overlap_y := f32(math.min(a.y + a.height, b.y + b.height) - math.max(a.y, b.y))
	return rl.Vector2{overlap_x, overlap_y}
}

CollisionTree :: struct {
	bounding_box: rl.Rectangle,
	colliders:    [COLLISION_TREE_CAPACITY]Collider,
	amount:       int,
	capacity:     int, // max objects before splitting

	// cardinal directions
	nw:           ^CollisionTree,
	ne:           ^CollisionTree,
	sw:           ^CollisionTree,
	se:           ^CollisionTree,
}

collision_tree_create :: proc(
	bounding_box: rl.Rectangle = {
		x = -SCREEN_WIDTH / 2,
		y = -SCREEN_HEIGHT / 2,
		width = SCREEN_WIDTH,
		height = SCREEN_HEIGHT,
	},
) -> ^CollisionTree {
	collision_tree := new(CollisionTree, context.temp_allocator)
	collision_tree.bounding_box = bounding_box
	collision_tree.capacity = COLLISION_TREE_CAPACITY
	return collision_tree
}

collision_tree_insert :: proc(ct: ^CollisionTree, collider: Collider) -> (inserted: bool) {
	fmt.assertf(ct != nil, "collision tree cannot be nil")
	fmt.assertf(
		collider.rectangle.width > 0 && collider.rectangle.height > 0,
		"It does not make sense to have a collider with no size, or negative size",
	)
	if !rl.CheckCollisionRecs(ct.bounding_box, collider.rectangle) {
		return false
	}

	if ct.amount < ct.capacity && ct.nw == nil {
		ct.colliders[ct.amount] = collider
		ct.amount += 1
		return true
	} else {
		if ct.nw == nil {
			collision_tree_divide(ct)
		}
		if collision_tree_insert(ct.nw, collider) do return true
		if collision_tree_insert(ct.ne, collider) do return true
		if collision_tree_insert(ct.sw, collider) do return true
		if collision_tree_insert(ct.se, collider) do return true
	}

	return false
}

collision_tree_query :: proc(ct: ^CollisionTree, collider: Collider) -> [dynamic]Collider {

	colliders_in_range: [dynamic]Collider
	fmt.assertf(ct != nil, "collision tree cannot be nil")
	if !rl.CheckCollisionRecs(ct.bounding_box, collider.rectangle) {
		return colliders_in_range
	}

	for &c in ct.colliders {
		if entity_is_valid(c.handle) && rl.CheckCollisionRecs(c.rectangle, collider.rectangle) {
			append(&colliders_in_range, c)
		}
	}

	if ct.nw == nil {
		return colliders_in_range
	}

	colliders: [dynamic]Collider

	fmt.assertf(ct.nw != nil, "collision tree nw quad cannot be nil")
	colliders = collision_tree_query(ct.nw, collider)
	for &c in colliders {
		append(&colliders_in_range, c)
	}
	delete(colliders)

	colliders = collision_tree_query(ct.ne, collider)
	for &c in colliders {
		append(&colliders_in_range, c)
	}
	delete(colliders)

	colliders = collision_tree_query(ct.sw, collider)
	for &c in colliders {
		append(&colliders_in_range, c)
	}
	delete(colliders)

	colliders = collision_tree_query(ct.se, collider)
	for &c in colliders {
		append(&colliders_in_range, c)
	}
	delete(colliders)

	return colliders_in_range
}

collision_tree_divide :: proc(ct: ^CollisionTree) {
	ct.nw = collision_tree_create(
		rl.Rectangle {
			x = ct.bounding_box.x,
			y = ct.bounding_box.y,
			width = ct.bounding_box.width / 2,
			height = ct.bounding_box.height / 2,
		},
	)
	ct.ne = collision_tree_create(
		rl.Rectangle {
			x = ct.bounding_box.x + ct.bounding_box.width / 2,
			y = ct.bounding_box.y,
			width = ct.bounding_box.width / 2,
			height = ct.bounding_box.height / 2,
		},
	)
	ct.sw = collision_tree_create(
		rl.Rectangle {
			x = ct.bounding_box.x,
			y = ct.bounding_box.y + ct.bounding_box.height / 2,
			width = ct.bounding_box.width / 2,
			height = ct.bounding_box.height / 2,
		},
	)
	ct.se = collision_tree_create(
		rl.Rectangle {
			x = ct.bounding_box.x + ct.bounding_box.width / 2,
			y = ct.bounding_box.y + ct.bounding_box.height / 2,
			width = ct.bounding_box.width / 2,
			height = ct.bounding_box.height / 2,
		},
	)

}
