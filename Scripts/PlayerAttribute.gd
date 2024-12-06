class_name PlayerAttribute
extends RefCounted

# This class manages the functionality of a player attribute using the data provided by DPlayerAttribute.
# It interacts with the player and handles attribute changes, effects, saving, and loading.

# The DPlayerAttribute data instance
var attribute_data: RPlayerAttribute

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
	var maxed_effect: String
	var depletion_effect: String
	var depleting_effect: String
	var depletion_rate: float = 0.02
	var depletion_timer: Timer
	var hide_when_empty: bool  # Property to determine if the attribute should hide when empty
	# Property for drain attributes. Example: "drain_attributes": {"torso_health": 1.0,"head_health": 1.0}
	var drain_attributes: Dictionary  
	# Reference to the player instance
	var player: Node
	var playerattr: PlayerAttribute
	
	# Constructor to initialize DefaultMode properties
	func _init(data: Dictionary, playernode: CharacterBody3D, myplayerattr: PlayerAttribute):
		min_amount = data.get("min_amount", 0.0)
		max_amount = data.get("max_amount", 100.0)
		current_amount = data.get("current_amount", max_amount)
		depletion_rate = data.get("depletion_rate", 0.02)  # Default to 0.02
		maxed_effect = data.get("maxed_effect", "none")
		depletion_effect = data.get("depletion_effect", "none")
		depleting_effect = data.get("depleting_effect", "none")
		hide_when_empty = data.get("hide_when_empty", false)  # Initialize from data
		drain_attributes = data.get("drain_attributes", {})  # Initialize from data
		player = playernode
		playerattr = myplayerattr
		start_depletion()
	
	# Get data function to return the properties in a dictionary
	func get_data() -> Dictionary:
		var new_data: Dictionary = {
			"min_amount": min_amount,
			"max_amount": max_amount,
			"current_amount": current_amount,
			"depletion_rate": depletion_rate,
			"maxed_effect": maxed_effect,
			"depletion_effect": depletion_effect,
			"depleting_effect": depleting_effect,  # Include in output
			"hide_when_empty": hide_when_empty
		}
		if not drain_attributes.is_empty():
			new_data["drain_attributes"] = drain_attributes
		return new_data
	
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

	# Function to handle when the attribute changes (e.g., health drops to 0 or reaches max)
	func _on_attribute_changed():
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)
		
		# Trigger the depletion effect if amount drops to min and the effect is "death"
		if is_at_min() and depletion_effect == "death":
			player.die()
		
		# Trigger the maxed effect if the amount reaches max and the effect is "death"
		if is_at_max() and maxed_effect == "death":
			player.die()

	# Function to check if the attribute is at maximum value (for DefaultMode)
	func is_at_max() -> bool:
		return current_amount >= max_amount
	
	# Function to check if the attribute is at minimum value (for DefaultMode)
	func is_at_min() -> bool:
		return current_amount <= min_amount
	
	# Modify the `modify_current_amount` function to restart depletion when needed
	func modify_current_amount(amount: float):
		var was_at_min = is_at_min()  # Check if the attribute was at min before modifying
		current_amount = clamp(current_amount + amount, min_amount, max_amount)
		_on_attribute_changed()

		# If the attribute was previously at min but now is above min, restart depletion
		if was_at_min and current_amount > min_amount:
			start_depletion()

	# Function that gets called every tick to decrease the attribute
	func _on_deplete_tick():
		modify_current_amount(-depletion_rate)

		# Check if depleting_effect is set to "drain other attributes"
		if depleting_effect == "drain other attributes" and not drain_attributes.is_empty():
			# Collect the attribute IDs from the drain_attributes dictionary
			var attribute_ids: Array = drain_attributes.keys()
			
			# Get the matching player attributes
			var attributes_to_drain = player.get_matching_player_attributes(attribute_ids)
			
			# Drain the specified amount from each attribute
			for attr in attributes_to_drain:
				if attr:
					var drain_amount = drain_attributes.get(attr.id, 0.0)
					attr.modify_current_amount(-drain_amount)

		# Stop depletion if at min
		if is_at_min():
			stop_depletion()



# Inner class for FixedMode. This is used in the background to control some game mechanics
# but can be influenced by items and game events. For example,
# inventory_space may be altered by equipping items
class FixedMode:
	var player: Node
	var playerattr: PlayerAttribute

	# Define the three amounts
	var base_amount: float   # Set only during initialization
	var temp_amount: float   # Temporary, modified during gameplay but not saved
	var perm_amount: float   # Permanent, saved during gameplay

	# Constructor to initialize FixedMode properties
	func _init(data: Dictionary, playernode: CharacterBody3D, myplayerattr: PlayerAttribute):
		# Initialize amounts from data, using 0.0 as default if not provided
		base_amount = data.get("amount", 0.0)
		temp_amount = 0.0  # Always starts at 0 during initialization
		perm_amount = data.get("perm_amount", 0.0)
		player = playernode
		playerattr = myplayerattr

	# Function to get data, but only return base_amount and perm_amount (not temp_amount)
	func get_data() -> Dictionary:
		return {
			"amount": base_amount,
			"perm_amount": perm_amount
		}

	# Function to get the total effective amount (base + perm + temp)
	func get_total_amount() -> float:
		return base_amount + perm_amount + temp_amount

	# Set the temp_amount during gameplay (temporary effect)
	func set_temp_amount(value: float):
		temp_amount = value
		print_debug("Updated attribute temp_amount '%s': %f" % [playerattr.id, temp_amount])
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)

	# Modify the temp_amount by adding or subtracting from it
	func modify_temp_amount(value: float):
		temp_amount += value
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)

	# Set the perm_amount during gameplay (this will be saved)
	func set_perm_amount(value: float):
		perm_amount = value
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)

	# Modify the perm_amount by adding or subtracting from it
	func modify_perm_amount(value: float):
		perm_amount += value
		Helper.signal_broker.player_attribute_changed.emit(player, playerattr)


# Properties for default and fixed modes
var default_mode: DefaultMode
var fixed_mode: FixedMode

# Constructor to initialize the controller with a DPlayerAttribute and a player reference
func _init(data: RPlayerAttribute, player_reference: Node):
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

# Modifies the amount of the fixed_mode by the given amount
func modify_temp_amount(amount: float):
	if fixed_mode:
		fixed_mode.modify_temp_amount(amount)
