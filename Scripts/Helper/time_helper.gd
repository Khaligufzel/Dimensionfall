class_name TimeHelper
extends RefCounted

# Internal state
var _elapsed_time: float = 0.0  # Total elapsed time for the current game session (in seconds)
var _is_tracking_time: bool = false  # Flag to track if we are actively counting time
var _last_tick_time: int = 0  # The last recorded tick time (in milliseconds)

func _ready():
	# Connect signals for game state changes
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	Helper.signal_broker.game_ended.connect(_on_game_ended)

func _process(delta: float):
	if _is_tracking_time:
		# Update elapsed time based on ticks for precision
		var current_ticks = Time.get_ticks_msec()
		_elapsed_time += (current_ticks - _last_tick_time) / 1000.0  # Convert ms to seconds
		_last_tick_time = current_ticks

# --- Signal Handlers ---
# Called when a new game starts. Resets time tracking and begins counting from zero.
func _on_game_started():
	_elapsed_time = 0.0  # Reset elapsed time for a new game
	_start_tracking_time()

# Called when a game is loaded. Resumes time tracking from the saved time.
func _on_game_loaded(saved_time: float):
	_elapsed_time = saved_time  # Resume from the saved time
	_start_tracking_time()

# Called when the game ends. Stops time tracking.
func _on_game_ended():
	_stop_tracking_time()

# --- Private Helpers ---

# Starts time tracking by recording the current tick time.
func _start_tracking_time():
	_last_tick_time = Time.get_ticks_msec()
	_is_tracking_time = true

# Stops time tracking by clearing the tracking flag.
func _stop_tracking_time():
	_is_tracking_time = false

# --- Public API ---

# Returns the total elapsed time in seconds for the current session.
func get_elapsed_time() -> float:
	return _elapsed_time


# Sets the elapsed time for saving/loading purposes.
# Resets the reference for accurate tracking.
func set_elapsed_time(new_time: float):
	_elapsed_time = new_time
	if _is_tracking_time:
		_last_tick_time = Time.get_ticks_msec()


# Returns the time difference between a given past time and the current time.
func get_time_difference(past_time: float) -> float:
	return max(0.0, _elapsed_time - past_time)
