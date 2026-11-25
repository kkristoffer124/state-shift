# State Shift

Entry for **GitHub Game Off 2026** (theme: **SHIFT**) — https://itch.io/jam/game-off-2026
Deadline: **Dec 1, 2026, 13:37 PST** (22:37 CET). Needs a public GitHub repo + itch.io submission. AI use must be disclosed on submit.

You're a blob of matter that shifts between three states to escape a lab.

| State | Feel | Can | Can't |
|---|---|---|---|
| ICE | heavy, slippery, no jump | survive spikes, stand on grates, shatter cracked floors by falling | pass grates, jump |
| WATER | small, nimble | jump, drip through grates | touch spikes |
| STEAM | floats up, drifts | rise, pass grates, ride fans | touch spikes, go down |

Controls: A/D move · Space jump · **E / Shift heat up** · **Q / Ctrl cool down** · R restart · Esc pause · N skip level (debug builds only)

## Project layout
- `levels/level_0X.tscn` — levels. Drag props from `scenes/props/` under `Blocks` or `Zones`; set `size` in the inspector (origin = top-left). Camera limits come from the Blocks' bounds automatically.
- `scenes/props/` — wall, grate, breakable (Block), spikes, heat_zone, freeze_zone, fan, goal (Zone).
- `scenes/player.tscn` + `scripts/player.gd` — all movement tunables are exported, grouped per state.
- `scripts/fluid_body.gd` (Player/FluidBody) — physics visuals: WATER is ~16 spring-linked droplets rendered as one metaball blob (`shaders/metaball.gdshader` on the Water CanvasGroup), STEAM is a cloud of buoyant swirling puffs. Gameplay collision still uses the Player's own shape. Swap `droplet_texture` / `puff_texture` and the shader colours (or `use_ramp`) for real art.
- `scripts/game.gd` (autoload `Game`) — level order (`LEVELS`), deaths, timer.
- `scripts/sfx.gd` (autoload `Sfx`) — placeholder synth sounds; replace via `Sfx.overrides["shatter"] = preload(...)`.
- `scenes/hud.tscn` (autoload `Hud`), `scenes/menu.tscn`, `scenes/end.tscn`.

All visuals are placeholder `_draw()` shapes — replace with your own art.

## Front-end and progression
- Main menu (`scenes/menu.tscn`): Continue, New game, Load (chapter select), Settings, Quit (hidden on web).
- Every level is a chapter with a title card and a completion card; progress and best times are saved to `user://save.cfg` by the `Save` autoload.
- `Settings` autoload: volumes (Master/Music/SFX buses), fullscreen, screen shake, camera zoom (1.5x/2x/3x, default 2x).
- `Overlay` autoload: chapter cards, pause menu (Esc), fades.
- Backdrop: `scenes/background.tscn` plays the animated e9a/e9b lab loops with parallax.
- Water/steam: `scripts/fluid_body.gd` (the player's pixel body) and `scripts/fluid_world.gd` (free falling-sand water/steam per level).

## Testing
```
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --fixed-fps 120 --path . res://tests/levels_test.tscn
godot --headless --path . res://tests/menu_test.tscn
```
Web export preset "Web" -> `../state-shift-builds/web/` (zip that folder for itch).

## Ideas / TODO
- Real art + music, more levels (8–12 for the jam), checkpoints in longer levels
- Per-level shift limits ("par") for a star rating
- Melting/condensing over time (ice melts near heat even outside zones)
- Water puts out fires, steam fogs cameras, ice plugs pipes
