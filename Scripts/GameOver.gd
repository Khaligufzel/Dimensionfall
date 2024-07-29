extends Control


# This script belongs to the Gameover window that shows in-game when the player is defeated

# When the player presses the 'return to main menu' button
func _on_return_button_button_up():
	Helper.exit_game()
