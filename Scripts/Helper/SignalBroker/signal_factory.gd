extends Object
class_name SignalFactory

# This class allows the creation of signals at runtime. Signals are referenced as key/value pairs for the given signal_id.
# Signals created with this factory have an id that describes the class of signal they are, while the key adds an axis
# that lets listeners filter by an additional parameter.  For instance, a signal take_damage would consume 
# all events when anybody takes damage, but by adding a key for the RID of the entity that took damage, we can
# create a signal that only listens to the damage taken by a specific entity.

static var owner_class = (SignalFactory as Object)

# Dictionary[dictId: [Dictionary[key: Signal]]]
static var RegisteredSignals : Dictionary

# Gets the signal matching the given signal_id and key.  If this signal does not already exist,
# it creates it before returning it.
# signal_id: The identifier for the class of signal
# key: The key to identify the specific signal within the class of signal
# args: The arguments used to construct the signal if there is not already one present.
# args must be length 2n, following this format: https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-add-user-signal
static func get_signal_with_key(signal_id: String, key, args: Array = []) -> Signal:
	if !RegisteredSignals.has(signal_id):
		RegisteredSignals[signal_id] = {}
	
	if !RegisteredSignals[signal_id].has(key):
		RegisteredSignals[signal_id][key] = create_signal(build_signal_name(signal_id, key), args, owner_class)
		
	return RegisteredSignals[signal_id][key]

# Create and return a signal with the given name and arguments, attached to the given owner.
# signal_name: The name for the signal
# args: The arguments used to construct the signal if there is not already one present.
# args must be length 2n, following this format: https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-add-user-signal
# owner: The object to which the signal will be attached
static func create_signal(signal_name: String, args: Array, owner) -> Signal:
	var signal_args = range(0, len(args), 2).map(func(n): return { "name": args[n], "type": args[n + 1] })
	owner.add_user_signal(signal_name, signal_args)
	return Signal(owner, signal_name)

# Destroy the signal tracked by the given id and key.
# signal_id: The identifier for the class of signal
# key: The key to identify the specific signal within the class of signal
static func destroy_factory_signal(signal_id: String, key) -> void:
	if RegisteredSignals.has(signal_id) and RegisteredSignals[signal_id].has(key):
		var signal_name = build_signal_name(signal_id, key)
		owner_class.remove_user_signal(signal_name)
		RegisteredSignals[signal_id].erase(key)
		
		if RegisteredSignals[signal_id].is_empty():
			RegisteredSignals.erase(signal_id)

# Return a string identifier based on the signal_id and key provided.
# signal_id: The identifier for the class of signal
# key: The key to identify the specific signal within the class of signal
static func build_signal_name(signal_id: String, key) -> String:
	return signal_id + "-" + str(key)
