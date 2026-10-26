# Copilot Instructions — With a Little Help from my Bot Friend

"With a Little Help from my Bot Friend" is a Godot 4.3 (GDScript) endless
runner. The player is trapped in a
glitching AI system and must jump/crouch past deadly obstacles while catching
camouflaged bonus "hallucinations," guided (and occasionally misled) by a
narrator bot, **Trusty**. Keep this premise in mind for any new content: Trusty
is a well-meaning helper whose reliability visibly degrades as the player makes
mistakes — that tension (trustworthy AI vs. AI that hallucinates/fails) is the
whole point of the game, and it should read as charming rather than broken.
Core gameplay is about the player's attention and reflexes (reading cues,
reacting fast), not Trusty's — don't make Trusty do anything that reduces the
player's own need to watch and react.

## Project layout

- `project.godot` — main scene is `scenes/Intro.tscn`; single autoload singleton
  `Game` (`scripts/Game.gd`) holds global run state (progress, hallucinations
  caught/missed, high score, signals). `jump` = Space/Up Arrow, `crouch` =
  Down Arrow/Ctrl, `restart` = R.
- `scenes/` + `scripts/` — one `.gd` script per matching `.tscn` scene, named
  the same (e.g. `Player.tscn` + `Player.gd`). Follow this 1:1 pairing for any
  new node type.
  - `Intro.tscn`/`Intro.gd` — story typewriter intro → Trusty self-intro →
    Controls panel (merged with Yes/No start prompt) → `Main.tscn`.
  - `Main.tscn`/`Main.gd` — central game loop/spawner/UI driver; owns obstacle
    spawning, HUD, game-over flow, and reacts to `Game` signals.
  - `Player.tscn`/`Player.gd` — movement, jump/crouch/fast-fall, the
    progress-based speed ramp, and the ambient-shake escalation effect.
  - `Game.gd` — autoload singleton; single source of truth for score/progress
    and the "loose hallucinations" miss-escalation thresholds (flash at 3,
    funky screen at 4, ambient shake at 9, forced "System Corrupted" game over
    at 10). Any new scoring/penalty rule belongs here, not scattered in `Main.gd`.
  - `Narrator.tscn`/`Narrator.gd` — Trusty's speech bubble; `say_text(text, duration)`.
    Keep bubble text short — the bubble has limited width, no auto-scroll.
  - `Bonus.gd`, obstacle scenes (`Spike`, `Lava`, `Ceiling`, `Bar`, bonus
    variants) — spawnable hazards/pickups.
- `shaders/` — `crt_overlay.gdshader` (intro terminal look), `glitch.gdshader`
  (funky-screen effect on repeated misses).
- `fonts/`, `themes/` — VT323 bitmap font + shared `game_theme.tres`. Reuse the
  existing theme/font instead of introducing new ones for consistency.
- `sketches/` — reference images (e.g. UI mockups the user shares); not game
  assets, don't ship/package them.

## Conventions established this session

- **Procedural icons over Unicode/emoji glyphs.** VT323 + headless rendering
  cannot be trusted to draw emoji or extended-Unicode characters (skull,
  arrows, etc.). Use `Panel` + `StyleBoxFlat` composition for simple shapes
  (see `scenes/SkullIcon.tscn`), or a `Control` with a custom `_draw()` using
  `draw_polyline()`/primitives for linear shapes (see `scripts/ArrowIcon.gd`).
  Stick to plain ASCII in `Label.text`.
- **GridContainer for aligned label columns** when a UI needs a left column of
  mixed icon/text widgets and a right column of consistent text (e.g. the
  Controls panel's "= Jump" / "= Crouch" column) — far more robust than manual
  spacers.
- **Button styling**: distinct `StyleBoxFlat` resources per button per state
  (`normal`/`hover`/`pressed`/`focus`), with rounded corners + a `shadow_color`/
  `shadow_size` glow for a "shiny" look. Keep Yes/No (or similar binary choice)
  visually distinct (e.g. green vs. neutral) but both legible against the dark
  background.
- **GDScript typing gotcha**: iterating `for p in SOME_UNTYPED_CONST_ARRAY`
  yields an untyped/Variant loop variable. `var y := p.y` fails to infer ("Cannot
  infer the type of 'y'"). Explicitly type the intermediate: `var point: Vector2 = p`.
- **Speed/difficulty ramps belong in `Player.gd`**, driven by `Game` progress
  signals, as a continuous formula with diminishing increments converging to a
  cap (not hardcoded discrete jumps) — keeps the game "humanly possible"
  indefinitely rather than spiking to unplayable.
- Comment density: medium. Explain *why* (non-obvious reasoning, trade-offs,
  gotchas) rather than restating *what* the code does line-by-line.

## Coding practices

- Keep gameplay rules (scoring, thresholds, win/lose conditions) centralized in
  `Game.gd`; keep presentation/reaction logic (what plays, what Trusty says,
  what flashes) in `Main.gd`/`Player.gd`/`Narrator.gd`. Don't duplicate
  threshold constants across files — reference/signal from `Game.gd`.
  Avoid magic numbers: new thresholds/speeds should be named `const`s.
- Prefer Godot signals over polling for cross-node state changes (this is the
  existing pattern — `Game` emits signals like `system_corrupted`,
  `loose_hallucinations_changed`, consumed by `Main.gd`).
- No secrets, API keys, tokens, or personal data belong in this repo (project
  has none today — keep it that way). Exported binaries (`With a Little Help from my Bot Friend.exe`,
  `*.console.exe`) and `.godot/`/`.import/` are already gitignored — don't
  remove them from `.gitignore` or commit build output.
- This is a single-player, offline, local-only game with no network calls,
  file I/O outside Godot's own save system, or external input beyond
  keyboard — if a future feature introduces any of those (e.g. a leaderboard),
  flag the added attack surface explicitly before implementing.

## Validation workflow (no local Godot editor installed)

A one-time cached headless Godot install lives outside the repo so re-validation
is fast and doesn't re-download every session:

```
$exe = "$env:LOCALAPPDATA\GodotHeadless\4.3\Godot_v4.3-stable_win64_console.exe"
if (-not (Test-Path $exe)) {
    $dir = Split-Path $exe
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip" -OutFile "$dir\godot.zip"
    Expand-Archive -Path "$dir\godot.zip" -DestinationPath $dir -Force
    Remove-Item "$dir\godot.zip"
}
& $exe --headless --path . --import
& $exe --headless --path . scenes/<Scene>.tscn --quit-after 120   # smoke test
```

- Always re-run `--import` after `.tscn`/`.gd` changes before testing a scene.
- `--quit-after N` counts **frames, not seconds** — scale `N` up generously
  when a scene awaits `create_timer()` sequences (hundreds to low thousands of
  frames for multi-second tweens/dialogue sequences).
- For logic that's hard to trigger via real input in headless mode (see next
  bullet), write a throwaway `Node`-based test harness (`_Test<Name>Harness.gd`
  + matching `.tscn`) that `preload()`s/instantiates the real scene, calls its
  methods or sets state directly, `print()`s assertions, and `get_tree().quit()`s.
  **Always delete the harness files (and their `.uid` companions) when done** —
  never leave them in the working tree.
- `Input.action_press()/action_release()` do **not** reliably register as
  "just pressed" within a single headless physics frame. For input-timing-
  sensitive tests, construct a real `InputEventKey` and call
  `Input.parse_input_event()` instead (allow 1-2 extra frames to propagate).
  For pure UI/flow-state tests, skip simulated input entirely and call the
  script's internal handler methods directly — simpler and deterministic.
- Watch for incidental gameplay side effects when driving a full `Main.tscn`/
  `Player.tscn` in a test (e.g. an unattended player can fall into a hole and
  die mid-test, silently invalidating later assertions since `Game` ignores
  further progress once a run has ended). Disable physics
  (`set_physics_process(false)`) or isolate the component under test when that
  risk doesn't matter for what's being validated.
- Treat any `ERROR`/`SCRIPT ERROR`/`Parse Error` in `--import` or scene output
  as a blocking failure to fix before considering a change done.

## Workflow / commit policy

- **Never run `git commit` (or stage/push) unless the user explicitly asks
  for it in that turn.** Leave all changes as uncommitted working-tree
  modifications by default so the user can review/test/commit themselves.
- Don't create ad-hoc markdown planning/notes files in the repo; use the
  session workspace for scratch artifacts instead.
