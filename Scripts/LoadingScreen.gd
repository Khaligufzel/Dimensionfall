extends Control


# This script belongs to the loading window that shows in-game when the map is loading
@export var sub_label: Label


func _init():
	Helper.signal_broker.initial_chunks_generated.connect(_on_initial_chunks_generated)
	Helper.signal_broker.game_started.connect(update_sub_text.bind("Creating new save"))
	Helper.signal_broker.game_loaded.connect(update_sub_text.bind("Loading saved game"))
	Helper.signal_broker.player_spawned.connect(_on_player_spawned)
	
func _on_initial_chunks_generated():
	visible = false
	# When we are spawned and ready, save the game so that the world
	# is somewhat sensible when we load it after a game crash
	if Helper.save_helper.is_new_game():
		Helper.save_helper.save_game()

func update_sub_text(newtext: String):
	sub_label.text = newtext

# Function for handling player spawned signal
func _on_player_spawned(_playernode):
	sub_label.text = "Spawning player"


func on_exit_game():
	visible = true
	sub_label.text = "Quitting game..."
