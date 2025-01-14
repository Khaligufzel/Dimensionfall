class_name PlayerInputSignalBroker
extends Node

@onready var registered_signals: Dictionary
#@warning_ignore("unused_signal")
#signal try_activate_equipped_item(slot_idx: int)


func try_activate_equipped_item(slot_index: int) -> Signal:
	return SignalFactory.get_signal_with_key("try_activate_equipped_item", slot_index, ["slot_index", TYPE_INT])
		
