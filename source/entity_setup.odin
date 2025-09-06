package game
import rl "vendor:raylib"
PLAYER_MOVE_SPEED :: 100
player_setup :: proc(player: ^Entity) {
	player.pos.xy = 0
	player.animation = init_player_run_animation()
	player.collider = init_collider(
		player^,
		width = 30,
		height = 20,
		layer = {.PLAYER},
		mask = {.WORLD},
	)
	player.on_update = player_update
	player.on_draw = player_draw
	player.on_collide = player_collide
}

player_collide :: proc(player, entity: ^Entity) {
	entity_destroy(entity)
}


player_update :: proc(player: ^Entity) {

	// player input
	player.velocity.xy = 0
	if rl.IsKeyDown(.UP) {
		player.velocity.y -= PLAYER_MOVE_SPEED
	}
	if rl.IsKeyDown(.LEFT) {
		player.velocity.x -= PLAYER_MOVE_SPEED
	}
	if rl.IsKeyDown(.DOWN) {
		player.velocity.y += PLAYER_MOVE_SPEED
	}
	if rl.IsKeyDown(.RIGHT) {
		player.velocity.x += PLAYER_MOVE_SPEED
	}

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

BALL_TERMINAL_VELOCITY :: 20
ball_setup :: proc(ball: ^Entity) {
	ball.animation = init_ball_run_animation()
	ball.collider = init_collider(
		ball^,
		width = 10,
		height = 10,
		layer = {.WORLD},
		mask = {.PLAYER},
	)
	ball.on_update = ball_update
	ball.on_draw = ball_draw
	ball.on_collide = ball_collide
	ball.velocity.y += f32(rl.GetRandomValue(-BALL_TERMINAL_VELOCITY, BALL_TERMINAL_VELOCITY))
	ball.velocity.x += f32(rl.GetRandomValue(-BALL_TERMINAL_VELOCITY, BALL_TERMINAL_VELOCITY))
}

ball_collide :: proc(ball, entity: ^Entity) {
	ball.velocity -= entity.velocity / 2
}

ball_update :: proc(ball: ^Entity) {
	if ball.velocity.x > BALL_TERMINAL_VELOCITY || ball.velocity.x < -BALL_TERMINAL_VELOCITY {
		ball.velocity.x = BALL_TERMINAL_VELOCITY
	}
	if ball.velocity.y > BALL_TERMINAL_VELOCITY || ball.velocity.y < -BALL_TERMINAL_VELOCITY {
		ball.velocity.y = BALL_TERMINAL_VELOCITY
	}

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
