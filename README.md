# Odin + Raylib + Entity System Template

This is an [Odin](https://github.com/odin-lang/Odin) + [Raylib](https://github.com/raysan5/raylib) game template that combines hot reloading capabilities with a comprehensive entity system. The template features a flexible entity-component architecture, collision detection with spatial partitioning, animation system, and hot reloading for rapid game development.

Supported platforms: Windows, macOS, Linux and [web](#web-build).

## Quick Start

### Hot Reload Development

> [!NOTE]
> These instructions use Linux/macOS terminology. If you are on Windows, then replace these words:
> - `sh` -> `bat`
> - `bin` -> `exe`
> - `so` -> `dll` (Windows), `dylib` (mac)

1. Run `./build_hot_reload.sh` to create `game_hot_reload.bin` (located at the root of the project) and `game.so` (located in `build/hot_reload`). Note: It expects odin compiler to be part of your PATH environment variable.
2. Run `./game_hot_reload.bin`, leave it running.
3. The game will start with a player (corgi sprite) that you can move with arrow keys, and 10 bouncing balls. The player can destroy balls by colliding with them.
4. Make changes to the gameplay code in `source/game.odin` or entity behavior in `source/entity_setup.odin`. For example, change the background color or modify player movement speed.
5. Run `./build_hot_reload.sh` again, it will recompile `game.so`.
6. The running `./game_hot_reload.bin` will see that `game.so` changed and reload it automatically, preserving the current game state.

Note: `./build_hot_reload.sh` does not rebuild `game_hot_reload.bin` if it's already running. It only recompiles the game shared library for hot reloading.

### Running Tests

```bash
./test.sh
```

This runs all tests in the `tests/` directory, validating entity creation, destruction, collision detection, and other core systems.

## Entity System Architecture

The template includes uses the Mega Struct architecture. The idea is that there is only 'Entities'
all entities use the same struct and even thought it might seem wasteful, it's ok because your game probably isn't
that huge anyways. If you really need a lighter weight entity you can just create the seperate struct later.

### Entity Lifecycle

1. **Creation**: `entity_create(kind)` creates a new entity with automatic setup
2. **Update**: Entities are updated each frame through the update table
3. **Collision**: Collision detection runs after all entity updates
4. **Drawing**: Entities are drawn in z-index order
5. **Destruction**: `entity_destroy(entity)` removes entities and frees their slots

### Example Entity Setup

```odin
// Define a new entity kind
EntityKind :: enum {
    PLAYER,
    ENEMY,
    // ... other kinds
}

// Register entity procedures
load_entity_functions :: proc() {
	g.entity_setup_table = [EntityKind.COUNT]EntitySetupProc {
		EntityKind.PLAYER = player_setup,
		EntityKind.BALL   = ball_setup,
	}

	g.entity_update_table = [EntityKind.COUNT]EntityUpdateProc {
		EntityKind.PLAYER = player_update,
		EntityKind.BALL   = ball_update,
	}

	g.entity_collide_table = [EntityKind.COUNT]EntityCollideProc {
		EntityKind.PLAYER = player_collide,
		EntityKind.BALL   = ball_collide,
	}

	g.entity_draw_table = [EntityKind.COUNT]EntityDrawProc {
		EntityKind.PLAYER = player_draw,
		EntityKind.BALL   = ball_draw,
	}

}

// Implement entity behavior
player_setup :: proc(player: ^Entity) {
    player.pos = {0, 0}
    player.animation = init_player_animation()
    player.collider = init_collider(player^, width=30, height=20, layer={.PLAYER}, mask={.WORLD})
}
```

## Release builds

Run `./build_release.sh` to create a release build in `build/release`. That executable does not have the hot reloading stuff, since you probably do not want that in the released version of your game. This means that the release version does not use `game.so`, instead it imports the `source` folder as a normal Odin package.

`./build_debug.sh` is like `./build_release.sh` but makes a debuggable executable, in case you need to debug your non-hot-reload executable.

## Web build

`./build_web.sh` builds a release web executable (no hot reloading!).

### Web build requirements

- Emscripten. Download and install somewhere on your computer. Follow the instructions here: https://emscripten.org/docs/getting_started/downloads.html (follow the stuff under "Installation instructions using the emsdk (recommended)").
- Recent Odin compiler: This uses Raylib binding changes that were done on January 1, 2025.

### Web build quick start

1. Point `EMSCRIPTEN_SDK_DIR` in `build_web.sh` to where you installed emscripten.
2. Run `./build_web.sh`.
3. Web game is in the `build/web` folder.

> [!NOTE]
> `./build_web.sh` is for Linux / macOS, `build_web.bat` is for Windows.

> [!WARNING]
> You can't run `build/web/index.html` directly due to "CORS policy" javascript errors. You can work around that by running a small python web server:
> - Go to `build/web` in a console.
> - Run `python -m http.server`
> - Go to `localhost:8000` in your browser.
>
> _For those who don't have python: Emscripten comes with it. See the `python` folder in your emscripten installation directory._

Build a desktop executable using `./build_desktop.sh`. It will end up in the `build/desktop` folder.

There's a wrapper for `read_entire_file` and `write_entire_file` from `core:os` that can files from `assets` directory, even on web. See `source/utils.odin`

### Web build troubleshooting

See the README of the [Odin + Raylib on the web repository](https://github.com/karl-zylinski/odin-raylib-web?tab=readme-ov-file#troubleshooting) for troubleshooting steps.


## Assets
You can put assets such as textures, sounds and music in the `assets` folder. That folder will be copied when a release build is created and also integrated into the web build.

The hot reload build doesn't do any copying, because the hot reload executable lives in the root of the repository, alongside the `assets` folder.

### Aseprite plugin

Inside the asset_workbench directory there is a lua script which is a plugin that allows you to automatically export the selected layer in aseprite into this project

## Atlas builder

The template works nicely together with Karl Zylinski's [atlas builder](https://github.com/karl-zylinski/atlas-builder). The atlas builder can build an atlas texture from a folder of png or aseprite files. Using an atlas can drastically reduce the number of draw calls your game uses. There's an example in that repository on how to set it up. The atlas generation step can easily be integrated into the build scripts such as `./build_hot_reload.sh`

## TODOs
#### Errors
```bash
=> ./build_hot_reload.sh
Building game.so
./build_hot_reload.sh: line 37: 744324 Segmentation fault         (core dumped) odin build source -extra-linker-flags:"$EXTRA_LINKER_FLAGS" -define:RAYLIB_SHARED=true -build-mode:dll -out:$OUT_DIR/game_tmp$DLL_EXT -strict-style -vet -debug
```

## Credits

This template combines two excellent open-source projects:

- **Hot Reload System**: Based on [Karl Zylinski's Odin + Raylib + Hot Reload template](https://github.com/karl-zylinski/odin-raylib-hot-reload). The hot reloading system allows you to reload gameplay code while the game is running, enabling rapid iteration during development.

- **Entity System**: Adapted from [baldgg/blueprint](https://github.com/baldgg/blueprint), providing a flexible entity-component architecture with collision detection, animation system, and spatial partitioning.

See The Legend of Tuna repository for an example project that also uses Box2D: https://github.com/karl-zylinski/the-legend-of-tuna

Karl Zylinski used this kind of hot reloading while developing his game [CAT & ONION](https://store.steampowered.com/app/2781210/CAT__ONION/).
