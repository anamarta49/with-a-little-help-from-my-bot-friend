extends Control
## Intro/story screen: terminal-style typewriter text, then a Trusty greeting
## with a Yes/No choice before handing off to the actual game scene.

const STORY_TEXT := "SYSTEM TERMINAL -- SESSION #8841
> connecting to reality.exe ......... OK
> scanning for anomalies ............ ANOMALY DETECTED

Something went wrong. You're trapped inside a glitching AI world,
and it's filling up with hallucinations -- rogue, camouflaged errors
disguised as part of the system.

The only way out is through: survive, dodge the obstacles, and catch
every hallucination you can find.

Luckily, you're not alone.
> loading companion module ........... TRUSTY.exe  [OK]"

const NO_RESPONSE := "Ha! Not really optional... let's clear this system together!"

@onready var story_label: RichTextLabel = $Terminal/StoryLabel
@onready var prompt_label: Label = $Terminal/PromptLabel
@onready var terminal: Control = $Terminal
@onready var trusty: Control = $Trusty
@onready var key_map_panel: Control = $KeyMapPanel
@onready var buttons_row: Control = $ButtonsRow
@onready var yes_button: Button = $ButtonsRow/YesButton
@onready var no_button: Button = $ButtonsRow/NoButton

var _typing_done: bool = false
var _awaiting_space: bool = false
var _story_tween: Tween

func _ready() -> void:
	prompt_label.visible = false
	trusty.visible = false
	key_map_panel.visible = false
	buttons_row.visible = false
	story_label.text = STORY_TEXT
	story_label.visible_ratio = 0.0
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	Music.start()
	_start_typing()

func _start_typing() -> void:
	_story_tween = create_tween()
	_story_tween.tween_property(story_label, "visible_ratio", 1.0, 4.5)
	_story_tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	_typing_done = true
	_awaiting_space = true
	prompt_label.visible = true
	_blink_prompt()

func _blink_prompt() -> void:
	_blink_label(prompt_label)

func _blink_label(lbl: Label) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(lbl, "modulate:a", 0.2, 0.5)
	tween.tween_property(lbl, "modulate:a", 1.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if _awaiting_space:
		_awaiting_space = false
		_begin_trusty_intro()
	elif not _typing_done:
		_skip_typing()

func _skip_typing() -> void:
	if _story_tween and _story_tween.is_valid():
		_story_tween.kill()
	story_label.visible_ratio = 1.0
	_on_typing_finished()

func _begin_trusty_intro() -> void:
	terminal.visible = false
	trusty.visible = true
	trusty.say_text("Hi, I'm Trusty!", 1.8)
	await get_tree().create_timer(1.8).timeout
	trusty.say_text("Let me walk you through the controls real quick.", 2.4)
	await get_tree().create_timer(2.4).timeout
	_show_key_map()

func _show_key_map() -> void:
	key_map_panel.visible = true
	buttons_row.visible = true
	trusty.say_text("Are you ready to catch some Hallucinations?", 0.0)

func _on_yes_pressed() -> void:
	_start_game()

func _on_no_pressed() -> void:
	key_map_panel.visible = false
	buttons_row.visible = false
	trusty.say_text(NO_RESPONSE, 2.2)
	await get_tree().create_timer(2.2).timeout
	_start_game()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
