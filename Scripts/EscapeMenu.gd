extends Control

# This script works with EscapeMenu.tscn
# It pauses the game when visible and unpauses the game when invisible
# The resume button hides the menu and unpauses the game.
@export var resume_button: Button
@export var return_button: Button
@export var save_button: Button
@export var loadingscreen: Control

# A boolean variable used in an "if" statement to check if the game is paused or not.
var game_paused: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect button signals
	resume_button.button_up.connect(_on_resume_button_pressed)
	return_button.button_up.connect(_on_return_button_pressed)
	save_button.button_up.connect(_on_save_button_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("escape") and game_paused == false:
		_toggle_menu()
	elif Input.is_action_just_pressed("escape") and game_paused == true:
		_resume_game()


# Called when the save button is pressed.
func _on_save_button_pressed():
	Helper.save_helper.save_game()


# Called when the resume button is pressed.
func _on_resume_button_pressed():
	_resume_game()


# Called when the return button is pressed.
func _on_return_button_pressed():
	_return_to_main_menu()


# Called when the node's visibility changes.
func _on_visibility_changed():
	if not is_inside_tree():
		return
	get_tree().paused = is_visible()


# Toggle the menu's visibility
func _toggle_menu():
	game_paused = true
	Helper.time_helper._stop_tracking_time()
	visible = not visible


# Resume the game by hiding the menu and unpausing the game.
func _resume_game():
	game_paused = false
	Helper.time_helper._start_tracking_time()
	hide()
	if is_inside_tree():
		get_tree().paused = false


# Handle the return to the main menu, unpause the game, save the game, and change the scene.
func _return_to_main_menu():
	if is_inside_tree():
		_disable_all_controls()  # Disable controls before exiting
		get_tree().paused = false
		Helper.signal_broker.game_terminated.emit()
		loadingscreen.on_exit_game()
		Helper.save_and_exit_game()


# Function to disable all the controls in this script
func _disable_all_controls():
	# Disable each control by setting their disabled property
	if resume_button:
		resume_button.disabled = true
	if return_button:
		return_button.disabled = true
	if save_button:
		save_button.disabled = true
