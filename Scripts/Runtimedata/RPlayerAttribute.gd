class_name RPlayerAttribute
extends RefCounted

# This class represents a player attribute with its properties
# Only used while the game is running
# Example player attribute data:
# {
#     "default_mode": {
#         "color": "258d1bff",
#         "current_amount": 100,
#         "maxed_effect": "death",
#         "depletion_effect": "death",
#         "depleting_effect": "drain",
#         "depletion_rate": 0.02,
#         "max_amount": 100,
#         "min_amount": 0,
#         "hide_when_empty": false,
#         "drain_attributes": {
#             "torso_health": 1.0,
#             "head_health": 1.0
#         }
#     },
#     "description": "You starve when this is empty. You are full when this is full.",
#     "id": "food",
#     "name": "Food",
#     "references": {
#         "core": {
#             "items": [
#                 "canned_food",
#                 "tofu"
#             ]
#         }
#     },
#     "sprite": "apple_32.png"
# }

# Properties defined in the player attribute
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var parent: RPlayerAttributes  # Reference to the list containing all runtime player attributes for this mod
# Attribute properties stored inside DefaultMode and FixedMode classes
var default_mode: DefaultMode
var fixed_mode: FixedMode

# Inner class for DefaultMode properties
class DefaultMode:
	var min_amount: float
	var max_amount: float
	var current_amount: float
	var depletion_rate: float
	var ui_color: String
	var maxed_effect: String
	var depletion_effect: String
	var depleting_effect: String
	var hide_when_empty: bool
	var drain_attributes: Dictionary

	func _init(data: Dictionary):
		min_amount = data.get("min_amount", 0.0)
		max_amount = data.get("max_amount", 100.0)
		current_amount = data.get("current_amount", max_amount)
		depletion_rate = data.get("depletion_rate", 0.02)
		ui_color = data.get("color", "ffffffff")
		maxed_effect = data.get("maxed_effect", "none")
		depletion_effect = data.get("depletion_effect", "none")
		depleting_effect = data.get("depleting_effect", "none")
		hide_when_empty = data.get("hide_when_empty", false)
		drain_attributes = data.get("drain_attributes", {})

	func get_data() -> Dictionary:
		var data = {
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
			data["drain_attributes"] = drain_attributes
		return data


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


# Constructor to initialize player attribute properties
# myparent: The list containing all player attributes for this mod
# newid: The ID of the player attribute being created
func _init(myparent: RPlayerAttributes, newid: String):
	parent = myparent
	id = newid

# Overwrite this player attribute's properties using a DPlayerAttribute
func overwrite_from_dplayerattribute(dplayerattribute: DPlayerAttribute) -> void:
	if not id == dplayerattribute.id:
		print_debug("Cannot overwrite from a different id")
	name = dplayerattribute.name
	description = dplayerattribute.description
	spriteid = dplayerattribute.spriteid
	sprite = dplayerattribute.sprite
	if dplayerattribute.default_mode:
		default_mode = DefaultMode.new(dplayerattribute.default_mode.get_data())
	else:
		default_mode = null
	if dplayerattribute.fixed_mode:
		fixed_mode = FixedMode.new(dplayerattribute.fixed_mode.get_data())
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
	if default_mode:
		data["default_mode"] = default_mode.get_data()
	if fixed_mode:
		data["fixed_mode"] = fixed_mode.get_data()
	return data
