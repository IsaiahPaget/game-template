package tests
import gm "../source"

import "core:testing"

init_test_memory :: proc() {
	mem := new(gm.GameMemory)
	mem^ = gm.GameMemory {
		run = true,
	}
	gm.game_hot_reloaded(mem)
}

@(test)
entity_create_basic :: proc(t: ^testing.T) {
	init_test_memory()

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
	testing.expect(t, ent.animation.current_frame == 0, "Should not advance frame when timer < frame_length")
	testing.expect(t, ent.animation.frame_timer == 0.05, "Frame timer should remain unchanged when not advancing")

	// Advance to next frame
	ent.animation.frame_timer = 0.15 // Exceeds frame_length
	gm.animate(ent)
	testing.expect(t, ent.animation.current_frame == 1, "Should advance to frame 1 when timer exceeds frame_length")
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 when advancing frame")

	// Advance to frame 2
	ent.animation.frame_timer = 0.12 // Exceeds frame_length again
	gm.animate(ent)
	testing.expect(t, ent.animation.current_frame == 2, "Should advance to frame 2")
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 again")

	// Test looping back to frame 0
	ent.animation.current_frame = 3 // Last frame
	ent.animation.frame_timer = 0.11 // Exceeds frame_length
	gm.animate(ent)
	testing.expect(t, ent.animation.current_frame == 0, "Should loop back to frame 0 when reaching frame_count")
	testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 when looping")
}

@(test)
animate_proc_nil_animation_early_return :: proc(t: ^testing.T) {
	init_test_memory()

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
	testing.expect(t, ent.animation.current_frame == initial_frame, "Current frame should not change for NIL animation")
	testing.expect(t, ent.animation.frame_timer == initial_timer, "Frame timer should not change for NIL animation")
}

@(test)
animate_proc_multiple_frame_advances :: proc(t: ^testing.T) {
	init_test_memory()

	// Create an entity with animation
	ent := gm.entity_create(.PLAYER)
	ent.animation.kind = .IDLE
	ent.animation.frame_count = 3
	ent.animation.current_frame = 0
	ent.animation.frame_timer = 0
	ent.animation.frame_length = 0.1

	// Simulate multiple frame advances
	for i in 0..<5 {
		ent.animation.frame_timer = 0.15 // Always exceeds frame_length
		gm.animate(ent)
		
		expected_frame := (i + 1) % 3 // Should loop: 0, 1, 2, 0, 1
		testing.expectf(t, ent.animation.current_frame == expected_frame, "Frame should be %d after %d advances", expected_frame, i + 1)
		testing.expect(t, ent.animation.frame_timer == 0, "Frame timer should reset to 0 after each advance")
	}
}
