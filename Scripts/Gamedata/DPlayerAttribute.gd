class_name DPlayerAttribute
extends RefCounted

# This class represents data of a player attribute with its properties like health, stamina, etc.
# This does not have any functionality for controlling the attribute itself, it only holds data

# Example data:
#	{
#		"default_mode": {
#			"color": "258d1bff",
#			"current_amount": 100,
#			"maxed_effect": "death",
#			"depletion_effect": "death",
#			"depleting_effect": "drain",
#			"depletion_rate": 0.02,
#			"max_amount": 100,
#			"min_amount": 0,
#			"hide_when_empty": false,
#			"drain_attributes": {
#				"torso_health": 1.0,
#				"head_health": 1.0,
#			}
#		},
#		"description": "You starve when this is empty. You are full when this is full.",
#		"id": "food",
#		"name": "Food",
#		"sprite": "apple_32.png"
#	}


# Attribute ID (unique identifier)
var id: String

# Name of the attribute (e.g., "Health", "Stamina", "Food")
var name: String

# Description of the attribute (provides details about what the attribute represents)
var description: String

# Sprite representing the attribute in the UI
var spriteid: String
var sprite: Texture

# Inner class for DefaultMode properties
class DefaultMode:
	var min_amount: float # Minimum possible value for the attribute (e.g., 0 for health)
	var max_amount: float # Maximum possible value for the attribute (e.g., 100 for health)
	var current_amount: float # Current value of the attribute (e.g., current health level)
	var depletion_rate: float # The rate at which the amount depletes every second
	var ui_color: String # Variable to store the UI color as a string (e.g., "ffffffff" for white)
	var maxed_effect: String
	var depletion_effect: String # The effect that will happen when depleted
	var depleting_effect: String  # New property for handling the effect when depleting
	var hide_when_empty: bool  # New property to determine if the attribute should hide when empty
	var drain_attributes: Dictionary  # New property for drain attributes
	
	# Constructor to initialize the properties from a dictionary
	func _init(data: Dictionary):
		min_amount = data.get("min_amount", 0.0)
		max_amount = data.get("max_amount", 100.0)
		current_amount = data.get("current_amount", max_amount)  # Default to max amount if not provided
		depletion_rate = data.get("depletion_rate", 0.02)  # Default to 0.02 if not provided
		ui_color = data.get("color", "ffffffff")  # Default to white if not provided
		maxed_effect = data.get("maxed_effect", "none")
		depletion_effect = data.get("depletion_effect", "none")
		depleting_effect = data.get("depleting_effect", "none")  # Initialize from data
		hide_when_empty = data.get("hide_when_empty", false)  # Initialize from data
		drain_attributes = data.get("drain_attributes", {})  # Initialize from data
	
	# Get data function to return a dictionary of properties
	func get_data() -> Dictionary:
		var new_data: Dictionary = {
			"min_amount": min_amount,
			"max_amount": max_amount,
			"current_amount": current_amount,
			"depletion_rate": depletion_rate,
			"color": ui_color,
			"maxed_effect": maxed_effect,
			"depletion_effect": depletion_effect,
			"depleting_effect": depleting_effect,
			"hide_when_empty": hide_when_empty
		}
		if not drain_attributes.is_empty():
			new_data["drain_attributes"] = drain_attributes
		return new_data


# Inner class for FixedMode properties
class FixedMode:
	var amount: float  # Single float variable for fixed amount
	
	# Constructor to initialize the fixed amount from a dictionary
	func _init(data: Dictionary):
		amount = data.get("amount", 0.0)  # Default to 0.0 if not provided
	
	# Get data function to return a dictionary with the amount
	func get_data() -> Dictionary:
		return {
			"amount": amount
		}


# Attribute properties stored inside DefaultMode and FixedMode classes
var default_mode: DefaultMode
var fixed_mode: FixedMode
var parent: DPlayerAttributes

# Constructor to initialize playerattribute properties from a dictionary
# myparent: The list containing all playerattributes for this mod
func _init(data: Dictionary, myparent: DPlayerAttributes):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	
	# Initialize Craft and Magazine subclasses if they exist in data
	if data.has("default_mode"):
		default_mode = DefaultMode.new(data["default_mode"])
	else:
		default_mode = null
	
	if data.has("fixed_mode"):
		fixed_mode = FixedMode.new(data["fixed_mode"])
	else:
		fixed_mode = null

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}

	# Add defaultmode data if they exist
	if default_mode:
		data["default_mode"] = default_mode.get_data()
	
	# Add FixedMode data if it exists
	if fixed_mode:
		data["fixed_mode"] = fixed_mode.get_data()
	return data

# Returns the path of the sprite
func get_sprite_path() -> String:
	return parent.spritePath + spriteid

# Handles playerattribute changes and updates references if necessary
func on_data_changed(_oldplayerattribute: DPlayerAttribute):
	var changes_made = false
	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Tile reference updates saved successfully.")

# Some playerattribute has been changed
# INFO: if the playerattributes reference other entities, update them here
func changed(_olddata: DPlayerAttribute):
	parent.save_playerattributes_to_disk()

# A playerattribute is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check if the playerattribute has references to items and remove it from those items
	var itemsdata: Array = parent.references.get("id", {}).get("items", [])
	if itemsdata:
		for item_id in itemsdata:
			var ditem = Gamedata.items.by_id(item_id)
			if ditem.wearable and not ditem.wearable.player_attributes.is_empty():
				ditem.wearable.remove_player_attribute(id)
			if ditem.food and not ditem.food.attributes.is_empty():
				ditem.food.remove_player_attribute(id)
			if ditem.medical and not ditem.medical.attributes.is_empty():
				ditem.medical.remove_player_attribute(id)
		Gamedata.items.save_items_to_disk()
