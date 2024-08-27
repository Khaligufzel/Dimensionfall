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
var min_amount: float
var max_amount: float
var current_amount: float
var depletion_rate: float = 0.02 # Takes over an hour irl to deplete an amoun of 100

# Constructor to initialize the controller with a DPlayerAttribute and a player reference
func _init(data: DPlayerAttribute, player_reference: Node):
	attribute_data = data # Be sure to not modify the attribute_data or the change will be permanent
	player = player_reference

	# Initialize local variables from attribute_data
	id = attribute_data.id
	name = attribute_data.name
	description = attribute_data.description
	spriteid = attribute_data.spriteid
	sprite = attribute_data.sprite
	min_amount = attribute_data.min_amount
	max_amount = attribute_data.max_amount
	current_amount = attribute_data.current_amount
	depletion_rate = attribute_data.depletion_rate
	start_depletion()

# Function to get the current state of the attribute as a dictionary
func get_data() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid,
		"min_amount": min_amount,
		"max_amount": max_amount,
		"current_amount": current_amount
	}

# Function to set the state of the attribute using a dictionary (e.g., for loading saved data)
func set_data(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	min_amount = data.get("min_amount", 0.0)
	max_amount = data.get("max_amount", 100.0)
	current_amount = data.get("current_amount", max_amount)

# Function to modify the current amount of the attribute safely
func modify_current_amount(amount: float):
	current_amount = clamp(current_amount + amount, min_amount, max_amount)
	_on_attribute_changed()

# Function to reset the attribute to its maximum value (e.g., refilling health)
func reset_to_max():
	current_amount = max_amount
	_on_attribute_changed()

# Function to handle when the attribute changes (e.g., health drops to 0)
func _on_attribute_changed():
	Helper.signal_broker.player_attribute_changed.emit(player)
	# If amount drops to 0, trigger player death
	if is_at_min():
		player.die()

# Function to reduce the attribute by a specified amount
func reduce_amount(amount: float):
	modify_current_amount(-amount)

# Function to increase the attribute by a specified amount
func increase_amount(amount: float):
	modify_current_amount(amount)

# Checks if the attribute is at its minimum value
func is_at_min() -> bool:
	return current_amount <= min_amount

# Checks if the attribute is at its maximum value
func is_at_max() -> bool:
	return current_amount >= max_amount


# Function to start the depletion of the attribute
func start_depletion():
	# Create a timer to decrease the attribute over time
	var timer = Timer.new()
	timer.wait_time = 1.0  # Deplete every second
	timer.one_shot = false  # Repeat the timer
	timer.timeout.connect(_on_deplete_tick)
	player.add_child(timer)  # Add the timer to the player's node to start it
	timer.start()


# Function that gets called every tick to decrease the attribute
func _on_deplete_tick():
	reduce_amount(depletion_rate)

	# Optional: Stop the timer if the attribute reaches the minimum amount
	if is_at_min():
		var timer = player.get_node_or_null("Timer")
		if timer:
			timer.stop()
			timer.queue_free()
