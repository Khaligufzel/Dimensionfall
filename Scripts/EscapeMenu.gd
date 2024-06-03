extends Control

# This script is supposed to work with EscapeMenu.tscn
# It pauses the game when it is visible and unpauses the game when invisible
# The resume button hides the menu and unpauses the game.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		_toggle_menu()

# Called when the resume button is pressed.
func _on_resume_button_button_up():
	hide()
	if is_inside_tree():
		get_tree().paused = false

# Called when the return button is pressed.
func _on_return_button_button_up():
	if is_inside_tree():
		get_tree().paused = false
		Helper.save_game()
		await Helper.save_helper.all_chunks_unloaded
		Helper.reset() # Resets the game, as though you re-started it
		get_tree().change_scene_to_file("res://scene_selector.tscn")


# Called when the node's visibility changes.
func _on_visibility_changed():
	if is_visible():
		if is_inside_tree():
			get_tree().paused = true
	else:
		if is_inside_tree():
			get_tree().paused = false


# Toggle the menu's visibility
func _toggle_menu():
	if is_visible():
		hide()
	else:
		show()
