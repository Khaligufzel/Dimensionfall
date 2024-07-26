extends Control


# This script belongs to the Gameover window that shows in-game when the player is defeated

# When the player presses the 'return to main menu' button
func _on_return_button_button_up():
	Helper.map_manager.level_generator.unload_all_chunks()
	await Helper.map_manager.level_generator.all_chunks_unloaded
	# Devides the loaded_chunk_data.chunks into segments and saves them to disk
	Helper.overmap_manager.unload_all_remaining_segments()
	Helper.signal_broker.game_ended.emit()
	get_tree().change_scene_to_file("res://scene_selector.tscn")
