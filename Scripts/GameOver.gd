extends Control


# This script belongs to the Gameover window that shows in-game when the player is defeated

# When the player presses the 'return to main menu' button
func _on_return_button_button_up():
	await Helper.save_helper.all_chunks_unloaded
	Helper.signal_broker.game_ended.emit()
	get_tree().change_scene_to_file("res://scene_selector.tscn")
