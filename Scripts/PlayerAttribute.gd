class_name PlayerAttribute
extends RefCounted

# This class manages the functionality of a player attribute using the data provided by DPlayerAttribute.
# It interacts with the player and handles attribute changes, effects, saving, and loading.

# The DPlayerAttribute data instance
var attribute_data: DPlayerAttribute

# Reference to the player instance
var player: Node

# Constructor to initialize the controller with a DPlayerAttribute and a player reference
func _init(data: DPlayerAttribute, player_reference: Node):
	attribute_data = DPlayerAttribute.new(data.get_data().duplicate(true))
	player = player_reference

# Function to get the current state of the attribute as a dictionary
func get_data() -> Dictionary:
	return attribute_data.get_data()

# Function to set the state of the attribute using a dictionary (e.g., for loading saved data)
func set_data(data: Dictionary):
	attribute_data.id = data.get("id", "")
	attribute_data.name = data.get("name", "")
	attribute_data.description = data.get("description", "")
	attribute_data.spriteid = data.get("sprite", "")
	attribute_data.min_amount = data.get("min_amount", 0.0)
	attribute_data.max_amount = data.get("max_amount", 100.0)
	attribute_data.current_amount = data.get("current_amount", attribute_data.max_amount)
	attribute_data.references = data.get("references", {})

# Function to modify the current amount of the attribute safely
func modify_current_amount(amount: float):
	attribute_data.current_amount = clamp(attribute_data.current_amount + amount, attribute_data.min_amount, attribute_data.max_amount)
	_on_attribute_changed()

# Function to reset the attribute to its maximum value (e.g., refilling health)
func reset_to_max():
	attribute_data.current_amount = attribute_data.max_amount
	_on_attribute_changed()

# Function to handle when the attribute changes (e.g., health drops to 0)
func _on_attribute_changed():
	# Example: if health drops to 0, trigger player death
	if attribute_data.id == "health" and attribute_data.current_amount <= attribute_data.min_amount:
		player.die()  # Assuming the player node has a die() method
	# Additional logic can be added here for other attributes

# Function to reduce the attribute by a specified amount
func reduce_amount(amount: float):
	modify_current_amount(-amount)

# Function to increase the attribute by a specified amount
func increase_amount(amount: float):
	modify_current_amount(amount)

# Checks if the attribute is at its minimum value
func is_at_min() -> bool:
	return attribute_data.current_amount <= attribute_data.min_amount

# Checks if the attribute is at its maximum value
func is_at_max() -> bool:
	return attribute_data.current_amount >= attribute_data.max_amount
