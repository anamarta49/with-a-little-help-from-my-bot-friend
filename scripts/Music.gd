extends Node
## Global background-music singleton (autoloaded as "Music") so the loop
## survives scene changes (Intro -> Main) without restarting or popping.
##
## Pitch is driven by whichever of these is most relevant right now:
##   - Menu mode (intro screen, pause, game over): slow, calm pitch.
##   - Just after a run starts: a bit faster than menu, but still below the
##     normal gameplay pitch, ramping up to normal by RAMP_IN_PROGRESS.
##   - Normal gameplay: pitch rises from normal toward MAX_SPEED_PITCH as the
##     player's run speed ramps toward its cap (set_speed_ratio).
##   - "Breaking" (set_broken): a crunchy distortion + pitch jitter while the
##     funky/glitch screen effect is active, overriding the above.

const BGM_PATH := "res://audio/bgm_chiptune.wav"
const MUSIC_BUS := "Music"

const MENU_PITCH := 0.45 # more than twice as slow as normal gameplay pitch.
const RUN_START_PITCH := 0.75 # a bit faster than menu, still below normal.
const BASE_PITCH := 1.0 # normal gameplay pitch (today's "default" speed).
const MAX_SPEED_PITCH := 1.25 # pitch at full speed ramp (ratio = 1.0).
## Progress at which the run-start ramp-in finishes and normal pitch kicks in
## (matches Player's first speed stage, SPEED_STAGE_INTERVAL).
const RAMP_IN_PROGRESS := 300.0

const BROKEN_PITCH_JITTER := 0.12

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

var _menu_mode: bool = true
var _progress: float = 0.0
var _speed_ratio: float = 0.0
var _is_broken: bool = false
var _distortion_fx_index: int = -1
var _jitter_timer: Timer

func _ready() -> void:
	_ensure_music_bus()
	add_child(player)
	player.bus = MUSIC_BUS
	# Web export requires "Stream" playback (the default "Sample" mode is
	# silent in HTML5 builds); explicit here so it works on itch.io too.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var stream := load(BGM_PATH) as AudioStreamWAV
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2 # 16-bit mono samples
		player.stream = stream
	player.volume_db = -6.0
	player.pitch_scale = MENU_PITCH

	_jitter_timer = Timer.new()
	_jitter_timer.wait_time = 0.12
	_jitter_timer.one_shot = false
	add_child(_jitter_timer)
	_jitter_timer.timeout.connect(_on_jitter_tick)

	Game.progress_changed.connect(_on_game_progress_changed)
	Game.game_started.connect(_on_game_started)
	Game.game_over.connect(_on_game_over)

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		_distortion_fx_index = _find_distortion_index()
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, "Master")
	var distortion := AudioEffectDistortion.new()
	distortion.mode = AudioEffectDistortion.MODE_LOFI
	distortion.drive = 0.45
	distortion.pre_gain = 6.0
	AudioServer.add_bus_effect(idx, distortion)
	_distortion_fx_index = AudioServer.get_bus_effect_count(idx) - 1
	AudioServer.set_bus_effect_enabled(idx, _distortion_fx_index, false)

func _find_distortion_index() -> int:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectDistortion:
			return i
	return -1

func start() -> void:
	if not player.playing:
		player.play()

func stop() -> void:
	player.stop()

## True while in the intro screen, paused, or on the game-over screen.
func set_menu_mode(active: bool) -> void:
	_menu_mode = active
	_refresh_pitch()

func _on_game_started() -> void:
	_progress = 0.0
	set_menu_mode(false)

func _on_game_over(_final_progress: int, _final_hallucinations: int, _is_new_high_score: bool) -> void:
	set_menu_mode(true)

func _on_game_progress_changed(new_value: int) -> void:
	_progress = float(new_value)
	_refresh_pitch()

## ratio should be 0.0 (base speed) .. 1.0 (speed cap reached).
func set_speed_ratio(ratio: float) -> void:
	_speed_ratio = clamp(ratio, 0.0, 1.0)
	_refresh_pitch()

## Toggles the "breaking" effect used while the funky/glitch screen is active:
## a lofi distortion crunch plus a jittery pitch wobble.
func set_broken(active: bool) -> void:
	_is_broken = active
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1 and _distortion_fx_index != -1:
		AudioServer.set_bus_effect_enabled(idx, _distortion_fx_index, active)
	if active:
		_jitter_timer.start()
	else:
		_jitter_timer.stop()
		_refresh_pitch()

## Pitch for the current state, ignoring the broken-mode jitter overlay.
func _current_base_pitch() -> float:
	if _menu_mode:
		return MENU_PITCH
	if _progress < RAMP_IN_PROGRESS:
		return lerp(RUN_START_PITCH, BASE_PITCH, _progress / RAMP_IN_PROGRESS)
	return lerp(BASE_PITCH, MAX_SPEED_PITCH, _speed_ratio)

func _refresh_pitch() -> void:
	if _is_broken:
		return # the jitter timer drives pitch while broken.
	player.pitch_scale = _current_base_pitch()

func _on_jitter_tick() -> void:
	var base_pitch: float = _current_base_pitch()
	player.pitch_scale = base_pitch + randf_range(-BROKEN_PITCH_JITTER, BROKEN_PITCH_JITTER)
