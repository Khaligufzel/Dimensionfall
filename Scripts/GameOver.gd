extends Control


var is_button_pressed: bool = false
# This script belongs to the Gameover window that shows in-game when the player is defeated

# When the player presses the 'return to main menu' button
func _on_return_button_button_up():
	if is_button_pressed == false:
		is_button_pressed = true
		Helper.signal_broker.game_terminated.emit()
		Helper.exit_game()