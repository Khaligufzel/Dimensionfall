extends Object
class_name SignalFactory

# Dictionary[dictId: [Dictionary[key: Signal]]]
static var RegisteredSignals : Dictionary

static func get_signal_with_key(signal_id: String, key, args: Array = []) -> Signal:
	if !RegisteredSignals.has(signal_id):
		RegisteredSignals[signal_id] = {}
	
	if !RegisteredSignals[signal_id].has(key):
		RegisteredSignals[signal_id][key] = create_signal(signal_id + "-" + str(key), args)
		
	return RegisteredSignals[signal_id][key]

static func create_signal(signal_name: String, args: Array) -> Signal:
	var owner_class := (SignalFactory as Object)
	var signal_args = range(0, len(args), 2).map(func(n): return { "name": args[n], "type": args[n + 1] })
	owner_class.add_user_signal(signal_name, signal_args)
	return Signal(owner_class, signal_name)
