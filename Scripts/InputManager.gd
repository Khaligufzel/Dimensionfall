extends Node


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var s = Helper.player_input_signal_broker.try_activate_equipped_item(0)
			s.emit(0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Helper.player_input_signal_broker.try_activate_equipped_item(1).emit(1)
