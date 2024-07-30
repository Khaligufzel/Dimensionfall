extends Control

# This script works with EscapeMenu.tscn
# It pauses the game when visible and unpauses the game when invisible
# The resume button hides the menu and unpauses the game.
@export var resume_button: Button
@export var return_button: Button
@export var save_button: Button
@export var loadingscreen: Control


# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect button signals
	resume_button.button_up.connect(_on_resume_button_pressed)
	return_button.button_up.connect(_on_return_button_pressed)
	save_button.button_up.connect(_on_save_button_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		_toggle_menu()


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
	visible = not visible


# Resume the game by hiding the menu and unpausing the game.
func _resume_game():
	hide()
	if is_inside_tree():
		get_tree().paused = false


# Handle the return to the main menu, unpause the game, save the game, and change the scene.
func _return_to_main_menu():
	if is_inside_tree():
		get_tree().paused = false
		loadingscreen.on_exit_game()
		Helper.save_and_exit_game()
