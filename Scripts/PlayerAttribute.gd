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
	# Example: if health drops to 0, trigger player death
	if id == "health" and current_amount <= min_amount:
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
	return current_amount <= min_amount

# Checks if the attribute is at its maximum value
func is_at_max() -> bool:
	return current_amount >= max_amount
