class_name PlayerInputSignalBroker
extends Object

static func try_activate_equipped_item(slot_index: int) -> Signal:
	return SignalFactory.get_signal_with_key("try_activate_equipped_item", slot_index, ["slot_index", TYPE_INT])
