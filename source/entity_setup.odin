package game
import "core:fmt"
import rl "vendor:raylib"

player_setup :: proc(player: ^Entity) {
	player.pos.xy = 0
	player.animation = init_player_run_animation()
	player.collider = init_collider(
		player^,
		width = 10,
		height = 10,
		layer = {.PLAYER},
		mask = {.WORLD},
	)
	player.on_update = player_update
	player.on_draw = player_draw
	player.on_collide = player_collide
}

player_collide :: proc(player, entity: ^Entity) {
	fmt.println("collision")
}

player_update :: proc(player: ^Entity) {

	player.velocity.xy = 0
	player.velocity.y += f32(rl.GetRandomValue(-100, 100))
	player.velocity.x += f32(rl.GetRandomValue(-100, 100))

	// WARNING: nothing goes after this line
	player.pos += player.velocity * rl.GetFrameTime()
}
player_draw :: proc(player: Entity) {
	entity_draw_default(player)
}
init_player_run_animation :: proc() -> Animation {
	return Animation {
		texture = g.textures.player_run,
		frame_count = 4,
		frame_timer = 0,
		current_frame = 0,
		frame_length = 0.1,
		kind = .IDLE,
	}
}
ball_setup :: proc(ball: ^Entity) {
	ball.animation = init_ball_run_animation()
	ball.on_update = ball_update
	ball.on_draw = ball_draw
	ball.on_collide = ball_collide
}

ball_collide :: proc(ball, entity: ^Entity) {
	// fmt.println("ball collided")
}

ball_update :: proc(ball: ^Entity) {

	ball.velocity.xy = 0
	ball.velocity.y += f32(rl.GetRandomValue(-50, 50))
	ball.velocity.x += f32(rl.GetRandomValue(-50, 50))

	// WARNING: nothing goes after this line
	ball.pos += ball.velocity * rl.GetFrameTime()
}
ball_draw :: proc(ball: Entity) {
	rl.DrawCircleV(ball.pos, 5, ball.tint)
	if DEBUG {
		rl.DrawRectangleRec(ball.collider.rectangle, rl.ColorAlpha(rl.BLUE, 0.5))
	}
}
init_ball_run_animation :: proc() -> Animation {
	return Animation {
		texture = g.textures.player_run,
		frame_count = 4,
		frame_timer = 0,
		current_frame = 0,
		frame_length = 0.1,
		kind = .IDLE,
	}
}
