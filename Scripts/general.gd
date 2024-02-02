extends Node

# Existing variables
var is_mouse_outside_HUD = false
var is_allowed_to_shoot = true
var player_inventory_dict: Dictionary
var player_equipment_dict: Dictionary

# New variables
var is_action_in_progress = false
var action_timer: Timer
var action_complete_callback: Callable  # Use Callable to store the function reference
signal start_timer_progressbar(time_left: float)

func _ready():
	# Initialize the timer
	action_timer = Timer.new()
	action_timer.timeout.connect(_on_action_timer_timeout)
	add_child(action_timer)
	start_timer_progressbar.connect(Helper.signal_broker.on_start_timer_progressbar)

# Function to start an action
func start_action(duration: float, callback: Callable):
	if not is_action_in_progress:
		is_action_in_progress = true
		action_complete_callback = callback  # Store the callback function
		action_timer.start(duration)
		start_timer_progressbar.emit(duration)
		# Other necessary code to start the action
	else:
		print_debug("Another action is currently in progress.")

# Function called when the action timer runs out
func _on_action_timer_timeout():
	is_action_in_progress = false
	# Call the callback function if it exists
	if action_complete_callback:
		action_complete_callback.call()
	# Reset the callback function
	action_complete_callback = Callable()
	# Code to handle the completion of the action

