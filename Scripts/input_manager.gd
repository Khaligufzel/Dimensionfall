extends Node
# This class is the single point of control for all input events
# (TODO: move existing input logic from everywhere else to make this statement actually true)
# This class is responsible for listening for input events from the player, and converting them into 
# signals usable by the rest of the scene.  This class should have limited knowledge about the current
# game state, merely mapping input to signal

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		PlayerInputSignalBroker.try_activate_equipped_item(0).emit(0)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		PlayerInputSignalBroker.try_activate_equipped_item(1).emit(1)
