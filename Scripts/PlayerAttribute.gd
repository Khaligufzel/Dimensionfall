class_name PlayerAttribute
extends RefCounted

# This class manages the functionality of a player attribute using the data provided by DPlayerAttribute.
# It interacts with the player and handles attribute changes, effects, saving, and loading.

# The DPlayerAttribute data instance
var attribute_data: DPlayerAttribute

# Reference to the player instance
var player: Node

# Local copies of the attribute properties
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture

# Inner class for DefaultMode
class DefaultMode:
	var min_amount: float
	var max_amount: float
	var current_amount: float
	var depletion_effect: String
	var depletion_rate: float = 0.02
	var depletion_timer: Timer
	# Reference to the player instance
	var player: Node
	var playerattr: PlayerAttribute
	
	# Constructor to initialize DefaultMode properties
	func _init(data: Dictionary, playernode: CharacterBody3D, myplayerattr: PlayerAttribute):
		min_amount = data.get("min_amount", 0.0)
		max_amount = data.get("max_amount", 100.0)
		current_amount = data.get("current_amount", max_amount)
		depletion_rate = data.get("depletion_rate", 0.02)  # Default to 0.02
		depletion_effect = data.get("depletion_effect", "none")
		player = playernode
		playerattr = myplayerattr
		start_depletion()
	
	# Get data function to return the properties in a dictionary
	func get_data() -> Dictionary:
		return {
			"min_amount": min_amount,
			"max_amount": max_amount,
			"current_amount": current_amount,
			"depletion_rate": depletion_rate,
			"depletion_effect": depletion_effect
		}
	
	# Start depletion for DefaultMode
	func start_depletion():
		depletion_timer = Timer.new()
		depletion_timer.wait_time = 1.0  # Deplete every second
		depletion_timer.one_shot = false  # Repeat the timer
		depletion_timer.timeout.connect(_on_deplete_tick)
		player.add_child(depletion_timer)
		depletion_timer.start()

	# Stop depletion when min value is reached
	func stop_depletion():
		if depletion_timer:
			depletion_timer.stop()
			depletion_timer.queue_free()

	# Function to handle when the attribute changes (e.g., health drops to 0)
	func _on_attribute_changed():
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)
		# Trigger the depletion effect if amount drops to min and the effect is "death"
		if is_at_min() and depletion_effect == "death":
			player.die()
	
	# Function to check if the attribute is at minimum value (for DefaultMode)
	func is_at_min() -> bool:
		return current_amount <= min_amount
	
	# Function to modify the current amount safely (for DefaultMode)
	func modify_current_amount(amount: float):
		current_amount = clamp(current_amount + amount, min_amount, max_amount)
		_on_attribute_changed()

	# Function that gets called every tick to decrease the attribute
	func _on_deplete_tick():
		modify_current_amount(-depletion_rate)

		# Stop depletion if at min
		if is_at_min():
			stop_depletion()


# Inner class for FixedMode
class FixedMode:
	var player: Node
	var playerattr: PlayerAttribute
	var amount: float:
		set(value):
			amount = value
			Helper.signal_broker.player_attribute_changed.emit(player, playerattr)

	# Constructor to initialize FixedMode properties
	func _init(data: Dictionary, playernode: CharacterBody3D, myplayerattr: PlayerAttribute):
		amount = data.get("amount", 0.0)
		player = playernode
		playerattr = myplayerattr

	# Get data function to return the properties in a dictionary
	func get_data() -> Dictionary:
		return {
			"amount": amount
		}

# Properties for default and fixed modes
var default_mode: DefaultMode
var fixed_mode: FixedMode

# Constructor to initialize the controller with a DPlayerAttribute and a player reference
func _init(data: DPlayerAttribute, player_reference: Node):
	attribute_data = data  # Store attribute data
	player = player_reference

	# Initialize local variables from attribute_data
	id = attribute_data.id
	name = attribute_data.name
	description = attribute_data.description
	spriteid = attribute_data.spriteid
	sprite = attribute_data.sprite

	# Check if DefaultMode or FixedMode exists and initialize them
	if attribute_data.default_mode:
		default_mode = DefaultMode.new(attribute_data.default_mode.get_data(), player, self)
	elif attribute_data.fixed_mode:
		fixed_mode = FixedMode.new(attribute_data.fixed_mode.get_data(), player, self)

# Function to get the current state of the attribute as a dictionary
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}

	# Add the mode data
	if default_mode:
		data["default_mode"] = default_mode.get_data()
	if fixed_mode:
		data["fixed_mode"] = fixed_mode.get_data()

	return data

# Function to set the state of the attribute using a dictionary (e.g., for loading saved data)
func set_data(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	
	# Set the data for DefaultMode or FixedMode
	if data.has("default_mode"):
		default_mode = DefaultMode.new(data["default_mode"], player, self)
	elif data.has("fixed_mode"):
		fixed_mode = FixedMode.new(data["fixed_mode"], player, self)


# Reduces the amount of the default_mode
func reduce_amount(amount: float):
	if default_mode:
		modify_current_amount(-amount)

# Modifies the amount of the default_mode by the given amount
func modify_current_amount(amount: float):
	if default_mode:
		default_mode.modify_current_amount(amount)

# Modifies the amount of the fixed_mode by the given amount
func modify_fixed_amount(amount: float):
	if fixed_mode:
		fixed_mode.amount = amount
