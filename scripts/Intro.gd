extends Control
## Intro/story screen: terminal-style typewriter text, then a Trusty greeting
## with a Yes/No choice before handing off to the actual game scene.

const STORY_TEXT := "SYSTEM TERMINAL -- SESSION #8841
> connecting to reality.exe ......... OK
> scanning for anomalies ............ FAILED

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
@onready var choice_panel: Panel = $ChoicePanel
@onready var yes_button: Button = $ChoicePanel/HBoxContainer/YesButton
@onready var no_button: Button = $ChoicePanel/HBoxContainer/NoButton

var _typing_done: bool = false
var _awaiting_space: bool = false
var _story_tween: Tween

func _ready() -> void:
	prompt_label.visible = false
	trusty.visible = false
	choice_panel.visible = false
	story_label.text = STORY_TEXT
	story_label.visible_ratio = 0.0
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
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
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(prompt_label, "modulate:a", 0.2, 0.5)
	tween.tween_property(prompt_label, "modulate:a", 1.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if _awaiting_space:
		_awaiting_space = false
		_show_trusty_greeting()
	elif not _typing_done:
		_skip_typing()

func _skip_typing() -> void:
	if _story_tween and _story_tween.is_valid():
		_story_tween.kill()
	story_label.visible_ratio = 1.0
	_on_typing_finished()

func _show_trusty_greeting() -> void:
	terminal.visible = false
	trusty.visible = true
	choice_panel.visible = true
	trusty.say_text("Hello there, are you ready to clear the system with me?", 0.0)

func _on_yes_pressed() -> void:
	_start_game()

func _on_no_pressed() -> void:
	choice_panel.visible = false
	trusty.say_text(NO_RESPONSE, 2.2)
	await get_tree().create_timer(2.2).timeout
	_start_game()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
