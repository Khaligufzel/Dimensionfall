class_name TimeHelper
extends Node # Needs to be node in order to have the `_process` function

# This script is loaded into the helper.gd autoload singleton
# It can be accessed through Helper.time_helper
# This is a helper script that manages time, supporting many game mechanics.

# Internal state
var _elapsed_time: float = 0.0  # Total elapsed time for the current game session (in seconds)
var _is_tracking_time: bool = false  # Flag to track if we are actively counting time
var _last_tick_time: int = 0  # The last recorded tick time (in milliseconds)

# Time constants
const daytime: int = 20  # Daytime in minutes
const nighttime: int = 15  # Nighttime in minutes
const day_duration: int = daytime + nighttime  # Total duration of a day in real-life minutes
const in_game_day_minutes: int = 24 * 60  # In-game minutes in a full day (1440)

# Signal to notify when an in-game minute has passed
signal minute_passed(current_time: String)
# Internal state to track the last emitted in-game minute
var _last_emitted_minute: int = -1


func _ready():
	# Connect signals for game state changes
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	Helper.signal_broker.game_ended.connect(_on_game_ended)

func _process(_delta: float):
	if _is_tracking_time:
		# Update elapsed time based on ticks for precision
		var current_ticks = Time.get_ticks_msec()
		_elapsed_time += (current_ticks - _last_tick_time) / 1000.0  # Convert ms to seconds
		_last_tick_time = current_ticks

		# Get the current in-game minute
		var current_in_game_minutes = get_current_in_game_minutes()

		# Emit signal if a new in-game minute has passed
		if current_in_game_minutes != _last_emitted_minute:
			_last_emitted_minute = current_in_game_minutes
			var current_time: String = get_current_time()  # Optionally still provide the formatted string
			minute_passed.emit(current_time)


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


# Returns the number of in-game days since the start
func get_days_since_start() -> int:
	return int(_elapsed_time / (day_duration * 60))  # Convert minutes to seconds


# Returns a string representing the current time in-game in 24h format
func get_current_time() -> String:
	# Reuse the current in-game minutes calculation
	var current_minutes_of_day: int = get_current_in_game_minutes()

	# Convert total in-game minutes into hours and minutes
	var hours: int = current_minutes_of_day / 60  # Convert to hours
	var minutes: int = current_minutes_of_day % 60  # Remaining minutes

	# Format as a 24-hour time string (e.g., "14:35")
	return "%02d:%02d" % [hours, minutes]


# Returns the percentage of the in-game day that has progressed
func get_day_progress_percentage() -> float:
	# Reuse the current in-game minutes calculation
	var current_minutes_of_day: int = get_current_in_game_minutes()

	# Calculate the percentage of the day completed
	# Divide the current minutes of the day by the total in-game minutes per day
	return (current_minutes_of_day / float(in_game_day_minutes)) * 100.0


# Returns the current in-game minute as an integer value (0 to 1440),
# representing the number of minutes passed since the start of the in-game day.
func get_current_in_game_minutes() -> int:
	# Scale real-life elapsed time to in-game time.
	# _elapsed_time is the total real-life time in seconds, divided by day_duration to scale to in-game days.
	# Multiplying by in_game_day_minutes converts the scaled time to in-game minutes.
	# Example: Real-life elapsed time (_elapsed_time): 1050 seconds (17.5 minutes in real time)
	# _elapsed_time / day_duration: 1050 / (35 * 60) = 0.5 (Half an in-game day has passed).
	# scaled_elapsed_time = 0.5 * 1440 = 720 (720 in-game minutes have passed).
	var scaled_elapsed_time = (_elapsed_time / day_duration) * in_game_day_minutes

	# Convert the scaled time into a whole number of in-game minutes.
	# This represents the total number of in-game minutes passed since the game started.
	# Example: total_in_game_minutes = int(720) = 720.
	var total_in_game_minutes: int = int(scaled_elapsed_time)

	# Use modulo operation to wrap the total minutes into a single in-game day.
	# This ensures the result is always between 0 and 1439 (1440 total minutes in a day).
	# Example: current_minutes_of_day = 720 % 1440 = 720.
	var current_minutes_of_day: int = total_in_game_minutes % in_game_day_minutes

	# Return the current in-game minute of the day.
	return current_minutes_of_day
