package tests
import gm "../source"
import "core:fmt"
import "core:log"
import rl "vendor:raylib"

import "core:testing"

init_test_memory :: proc() {
	mem := new(gm.GameMemory)
	mem^ = gm.GameMemory {
		run = true,
	}
	gm.game_hot_reloaded(mem)
}

free_test_memory :: proc() {
	free_all(context.temp_allocator)
	gm.game_shutdown()
}

@(test)
entity_create_basic :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ent1 := gm.entity_create(.PLAYER)
	idx1 := ent1.handle.index
	id1 := ent1.handle.id

	testing.expect(t, gm.entity_is_valid(ent1), "ent1 should be valid after creation")
	testing.expect(t, idx1 > 0, "ent1 should have a positive index")
	testing.expect(t, id1 > 0, "ent1 should have a positive id")

	ent2 := gm.entity_create(.PLAYER)
	idx2 := ent2.handle.index
	id2 := ent2.handle.id

	testing.expect(t, gm.entity_is_valid(ent2), "ent2 should be valid after creation")
	testing.expect(t, idx2 == idx1 + 1, "ent2 index should follow ent1 when no free indices exist")
	testing.expect(t, id2 == id1 + 1, "ent2 id should increment")

}

@(test)
entity_destroy_reuses_index_and_invalidates :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ent1 := gm.entity_create(.PLAYER)
	_ = gm.entity_create(.PLAYER) // occupy next slot

	idx1 := ent1.handle.index
	id_before := ent1.handle.id

	gm.entity_destroy(ent1)
	testing.expect(t, !gm.entity_is_valid(ent1), "ent1 should be invalid after destruction")

	ent3 := gm.entity_create(.PLAYER)
	idx3 := ent3.handle.index
	id3 := ent3.handle.id

	testing.expect(t, idx3 == idx1, "ent3 should reuse ent1's freed index")
	testing.expect(t, id3 > id_before, "ent3 should have a strictly increasing id")

}

@(test)
entity_get_valid_and_invalid :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ent := gm.entity_create(.PLAYER)
	h := ent.handle

	e_ok, ok := gm.entity_get(h)
	testing.expect(t, ok, "entity_get should succeed for a valid handle")
	testing.expect(t, gm.entity_is_valid(e_ok), "Retrieved entity should be valid")

	// Invalid: zero handle
	zero_h := gm.Handle{}
	_, ok_zero := gm.entity_get(zero_h)
	testing.expect(t, !ok_zero, "entity_get should fail for zero handle")

	// Invalid: out-of-range index
	bad_index_h := gm.Handle {
		index = 999999,
		id    = 1,
	}
	_, ok_bad_idx := gm.entity_get(bad_index_h)
	testing.expect(t, !ok_bad_idx, "entity_get should fail for out-of-range index")

	// Invalid: mismatched id
	bad_id_h := gm.Handle {
		index = h.index,
		id    = h.id + 12345,
	}
	_, ok_bad_id := gm.entity_get(bad_id_h)
	testing.expect(t, !ok_bad_id, "entity_get should fail for mismatched id")

}

@(test)
entity_clear_all_empties_scratch :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	_ = gm.entity_create(.PLAYER)
	_ = gm.entity_create(.PLAYER)
	_ = gm.entity_create(.PLAYER)

	gm.rebuild_scratch()
	handles := gm.entity_get_all()
	testing.expect(t, len(handles) == 3, "Should have three entities in scratch list before clear")

	gm.entity_clear_all()
	gm.rebuild_scratch()
	handles_after := gm.entity_get_all()
	testing.expect(t, len(handles_after) == 0, "All entities should be cleared and scratch empty")
}

@(test)
collision_box_updates_correctly :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	player := gm.entity_create(.PLAYER)

	player.collider.rectangle.width = 32
	player.collider.rectangle.height = 64

	player_collider_rect_before := player.collider.rectangle

	player.pos += {10, 10}

	gm.collision_box_update(player)

	testing.expectf(
		t,
		player.collider.rectangle.y == player.pos.y - player_collider_rect_before.height,
		"The y should be equal to the player position.y - the height of the collider",
	)
	testing.expectf(
		t,
		player.collider.rectangle.x == player.pos.x - player_collider_rect_before.width / 2,
		"The x should be equal to the player position.x - half the width of the collider",
	)

}

@(test)
animate_proc_basic_functionality :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	// Create an entity with animation
	ent := gm.entity_create(.PLAYER)

	// Set up animation with known values
	ent.animation.kind = .IDLE
	ent.animation.frame_count = 4
	ent.animation.current_frame = 0
	ent.animation.frame_timer = 0
	ent.animation.frame_length = 0.1 // 100ms per frame

	// Test initial state
	testing.expect(t, ent.animation.current_frame == 0, "Animation should start at frame 0")
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should start at 0")

	// Simulate frame time and animate
	// Mock rl.GetFrameTime() by directly setting frame_timer
	ent.animation.frame_timer = 0.05 // Half way through first frame
	gm.animate(ent)
	testing.expect(
		t,
		ent.animation.current_frame == 0,
		"Should not advance frame when timer < frame_length",
	)
	testing.expect(
		t,
		ent.animation.frame_timer == 0.05,
		"Frame timer should remain unchanged when not advancing",
	)

	// Advance to next frame
	ent.animation.frame_timer = 0.15 // Exceeds frame_length
	gm.animate(ent)
	testing.expect(
		t,
		ent.animation.current_frame == 1,
		"Should advance to frame 1 when timer exceeds frame_length",
	)
	testing.expect(
		t,
		ent.animation.frame_timer == 0,
		"Frame timer should reset to 0 when advancing frame",
	)

	// Advance to frame 2
	ent.animation.frame_timer = 0.12 // Exceeds frame_length again
	gm.animate(ent)
	testing.expect(t, ent.animation.current_frame == 2, "Should advance to frame 2")
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 again")

	// Test looping back to frame 0
	ent.animation.current_frame = 3 // Last frame
	ent.animation.frame_timer = 0.11 // Exceeds frame_length
	gm.animate(ent)
	testing.expect(
		t,
		ent.animation.current_frame == 0,
		"Should loop back to frame 0 when reaching frame_count",
	)
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 when looping")
}

@(test)
animate_proc_nil_animation_early_return :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	// Create an entity with NIL animation
	ent := gm.entity_create(.PLAYER)
	ent.animation.kind = .NIL
	ent.animation.frame_count = 4
	ent.animation.current_frame = 1
	ent.animation.frame_timer = 0.5
	ent.animation.frame_length = 0.1

	// Store initial values
	initial_frame := ent.animation.current_frame
	initial_timer := ent.animation.frame_timer

	// Call animate - should return early without changes
	gm.animate(ent)

	// Verify no changes occurred
	testing.expect(
		t,
		ent.animation.current_frame == initial_frame,
		"Current frame should not change for NIL animation",
	)
	testing.expect(
		t,
		ent.animation.frame_timer == initial_timer,
		"Frame timer should not change for NIL animation",
	)
}

@(test)
animate_proc_multiple_frame_advances :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	// Create an entity with animation
	ent := gm.entity_create(.PLAYER)
	ent.animation.kind = .IDLE
	ent.animation.frame_count = 3
	ent.animation.current_frame = 0
	ent.animation.frame_timer = 0
	ent.animation.frame_length = 0.1

	// Simulate multiple frame advances
	for i in 0 ..< 5 {
		ent.animation.frame_timer = 0.15 // Always exceeds frame_length
		gm.animate(ent)

		expected_frame := (i + 1) % 3 // Should loop: 0, 1, 2, 0, 1
		testing.expectf(
			t,
			ent.animation.current_frame == expected_frame,
			"Frame should be %d after %d advances",
			expected_frame,
			i + 1,
		)
		testing.expect(
			t,
			ent.animation.frame_timer == 0,
			"Frame timer should reset to 0 after each advance",
		)
	}
}

@(test)
set_collision_layers :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	player := gm.entity_create(.PLAYER)

	player.collider.layer = gm.set_collision_layers({.PLAYER})
	player.collider.mask = gm.set_collision_layers({.WORLD})

	testing.expectf(
		t,
		player.collider.layer == gm.CollisionLayer{.PLAYER},
		"player should be on player layer",
	)
	testing.expectf(
		t,
		player.collider.mask == gm.CollisionLayer{.WORLD},
		"player should mask world layer",
	)
}
@(test)
set_multiple_collision_layers :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	player := gm.entity_create(.PLAYER)

	player.collider.layer = gm.set_collision_layers({.PLAYER, .WORLD})
	player.collider.mask = gm.set_collision_layers({.WORLD, .PLAYER})

	testing.expectf(
		t,
		player.collider.layer == gm.CollisionLayer{.PLAYER, .WORLD},
		"player should be on player layer",
	)
	testing.expectf(
		t,
		player.collider.mask == gm.CollisionLayer{.WORLD, .PLAYER},
		"player should mask world layer",
	)
}

// ============================================================================
// COLLISION TREE TEST HELPERS
// ============================================================================

// Helper function to create a collision tree for testing
create_test_collision_tree :: proc() -> ^gm.CollisionTree {
	return gm.collision_tree_create()
}

// Helper function to create a ball entity with standard collider
create_test_ball :: proc(x, y: f32) -> ^gm.Entity {
	ball := gm.entity_create(.BALL)
	ball.collider.rectangle = rl.Rectangle {
		x      = x,
		y      = y,
		width  = 10,
		height = 10,
	}
	return ball
}


// ============================================================================
// COLLISION TREE TESTS
// ============================================================================

@(test)
test_create_collision_tree :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()
	
	ct := create_test_collision_tree()
	
	testing.expectf(t, ct != nil, "collision tree should not be nil")
	testing.expectf(
		t,
		ct.capacity == gm.COLLISION_TREE_CAPACITY,
		"collision tree capacity should equal COLLISION_TREE_CAPACITY constant",
	)
	testing.expectf(t, ct.amount == 0, "collision tree should start with 0 colliders")
}

@(test)
test_collision_tree_insert_basic :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ct := create_test_collision_tree()

	// Test inserting first collider
	player := gm.entity_create(.PLAYER)
	ok := gm.collision_tree_insert(ct, player.collider)
	
	testing.expectf(t, ok, "inserting first collider should succeed")
	testing.expectf(t, ct.amount == 1, "tree should contain 1 collider after first insert")

	// Test inserting second collider
	ball1 := create_test_ball(0, 0)
	ball1_ok := gm.collision_tree_insert(ct, ball1.collider)
	
	testing.expectf(t, ball1_ok, "inserting second collider should succeed")
	testing.expectf(t, ct.amount == 2, "tree should contain 2 colliders after second insert")
}

@(test)
test_collision_tree_insert_capacity_exceeded :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ct := create_test_collision_tree()

	// Fill tree to capacity
	player := gm.entity_create(.PLAYER)
	gm.collision_tree_insert(ct, player.collider)
	
	ball1 := create_test_ball(0, 0)
	gm.collision_tree_insert(ct, ball1.collider)
	
	ball2 := create_test_ball(0, 0)
	gm.collision_tree_insert(ct, ball2.collider)
	
	ball3 := create_test_ball(0, 0)
	gm.collision_tree_insert(ct, ball3.collider)

	testing.expectf(t, ct.amount == gm.COLLISION_TREE_CAPACITY, 
		"tree should be at capacity (%d) before subdivision", gm.COLLISION_TREE_CAPACITY)

	// Insert one more to trigger subdivision
	ball4 := create_test_ball(0, 0)
	gm.collision_tree_insert(ct, ball4.collider)

	// Verify subdivision occurred
	testing.expectf(t, ct.nw != nil && ct.ne != nil && ct.sw != nil && ct.se != nil,
		"tree should be subdivided into four quadrants")
	
	testing.expectf(t, ct.bounding_box.width == (ct.nw.bounding_box.width + ct.ne.bounding_box.width),
		"X-axis subdivision should split width in half")
	
	testing.expectf(t, ct.bounding_box.height == (ct.nw.bounding_box.height + ct.sw.bounding_box.height),
		"Y-axis subdivision should split height in half")
}

@(test)
test_collision_tree_query_single_layer :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ct := create_test_collision_tree()
	
	// Insert only 2 colliders to stay within capacity (COLLISION_TREE_CAPACITY = 2)
	player := gm.entity_create(.PLAYER)
	player.collider.rectangle = rl.Rectangle{x = 0, y = 0, width = 10, height = 10}
	gm.collision_tree_insert(ct, player.collider)

	ball1 := create_test_ball(5, 5) // Overlapping with player rectangle
	gm.collision_tree_insert(ct, ball1.collider)

	// Test query on single layer (before subdivision)
	testing.expectf(t, ct.amount == 2, "first layer should contain 2 colliders (at capacity)")
	
	colliders := gm.collision_tree_query(ct, player.collider)
	defer delete(colliders)
	
	testing.expectf(t, len(colliders) == 2, 
		"query should return 2 colliders from single layer, got %d", len(colliders))
}

@(test)
test_collision_tree_query_multiple_layers :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	ct := create_test_collision_tree()
	
	// Create entities that will be distributed across quadrants after subdivision
	player := gm.entity_create(.PLAYER)
	player.collider.rectangle = rl.Rectangle{x = 0, y = 0, width = 10, height = 10}
	gm.collision_tree_insert(ct, player.collider)

	ball1 := create_test_ball(5, 5) // Overlapping with player
	gm.collision_tree_insert(ct, ball1.collider)

	// Insert third collider to trigger subdivision (capacity = 2)
	ball2 := create_test_ball(200, 200) // Far from player
	gm.collision_tree_insert(ct, ball2.collider)

	// Verify subdivision occurred
	testing.expectf(t, ct.nw != nil, "NW quadrant should exist after subdivision")
	testing.expectf(t, ct.ne != nil, "NE quadrant should exist after subdivision")
	testing.expectf(t, ct.sw != nil, "SW quadrant should exist after subdivision")
	testing.expectf(t, ct.se != nil, "SE quadrant should exist after subdivision")

	// Add more entities to test deeper subdivision
	ball3 := create_test_ball(2, 2) // Should overlap with player
	gm.collision_tree_insert(ct, ball3.collider)

	ball4 := create_test_ball(150, 50) // Should go in NE quadrant
	gm.collision_tree_insert(ct, ball4.collider)

	// Test query across multiple layers
	colliders := gm.collision_tree_query(ct, player.collider)
	defer delete(colliders)
	
	// Should return exactly 3 colliders: player, ball1, and ball3 (all overlapping with player)
	testing.expectf(t, len(colliders) == 3, 
		"query should return exactly 3 colliders (player, ball1, ball3), got %d", len(colliders))
	
	// Verify that we get the expected colliders by checking their handles
	found_player := false
	found_ball1 := false
	found_ball3 := false
	found_ball2 := false
	found_ball4 := false
	
	for c in colliders {
		if c.handle.id == player.handle.id {
			found_player = true
			testing.expectf(t, c.handle.index == player.handle.index, 
				"player collider should have correct index")
		} else if c.handle.id == ball1.handle.id {
			found_ball1 = true
			testing.expectf(t, c.handle.index == ball1.handle.index, 
				"ball1 collider should have correct index")
		} else if c.handle.id == ball3.handle.id {
			found_ball3 = true
			testing.expectf(t, c.handle.index == ball3.handle.index, 
				"ball3 collider should have correct index")
		} else if c.handle.id == ball2.handle.id {
			found_ball2 = true
		} else if c.handle.id == ball4.handle.id {
			found_ball4 = true
		}
	}
	
	testing.expectf(t, found_player, "query should include player collider")
	testing.expectf(t, found_ball1, "query should include ball1 collider (overlapping)")
	testing.expectf(t, found_ball3, "query should include ball3 collider (overlapping)")
	
	// Verify that ball2 and ball4 are NOT included (they don't overlap with player)
	testing.expectf(t, !found_ball2, "query should NOT include ball2 collider (non-overlapping)")
	testing.expectf(t, !found_ball4, "query should NOT include ball4 collider (non-overlapping)")
}

@(test)
test_collision_destroy_entity_mid_collision :: proc(t: ^testing.T) {
	init_test_memory()
	defer free_test_memory()

	// Create a collision handler that destroys entities
	destroying_collision_handler :: proc(entity_a, entity_b: ^gm.Entity) {
		// Destroy entity_b when collision occurs
		gm.entity_destroy(entity_b)
	}

	// Create two entities that will collide
	entity1 := gm.entity_create(.PLAYER)
	entity1.collider = gm.init_collider(
		entity1^,
		width = 20,
		height = 20,
		layer = gm.CollisionLayer{.PLAYER},
		mask = gm.CollisionLayer{.WORLD},
	)
	entity1.on_collide = destroying_collision_handler

	entity2 := gm.entity_create(.BALL)
	entity2.collider = gm.init_collider(
		entity2^,
		width = 20,
		height = 20,
		layer = gm.CollisionLayer{.WORLD},
		mask = gm.CollisionLayer{.PLAYER},
	)
	// Don't set collision handler for entity2 to avoid mutual destruction

	// Position them to overlap
	entity1.pos = {0, 0}
	entity2.pos = {5, 5} // Overlapping

	// Update collision boxes
	gm.collision_box_update(entity1)
	gm.collision_box_update(entity2)

	// Rebuild scratch to include both entities
	gm.rebuild_scratch()

	// This should not crash - the collision system should handle destroyed entities gracefully
	gm.process_collisions()

	// Verify entity2 was destroyed
	testing.expectf(t, !gm.entity_is_valid(entity2), "entity2 should be destroyed after collision")
	
	// Verify entity1 is still valid
	testing.expectf(t, gm.entity_is_valid(entity1), "entity1 should still be valid after collision")
}
