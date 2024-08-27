class_name DPlayerAttribute
extends RefCounted

# This class represents data of a player attribute with its properties like health, stamina, etc.
# This does not have any functionality for controlling the attribute itself, it only holds data

# Attribute ID (unique identifier)
var id: String

# Name of the attribute (e.g., "Health", "Stamina", "Food")
var name: String

# Description of the attribute (provides details about what the attribute represents)
var description: String

# Sprite representing the attribute in the UI
var spriteid: String
var sprite: Texture

# Minimum possible value for the attribute (e.g., 0 for health)
var min_amount: float

# Maximum possible value for the attribute (e.g., 100 for health)
var max_amount: float

# Current value of the attribute (e.g., current health level)
var current_amount: float

# The rate at which the amount depletes every second
var depletion_rate: float

# References to other entities
var references: Dictionary = {}

# Constructor to initialize the attribute properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	min_amount = data.get("min_amount", 0.0)
	max_amount = data.get("max_amount", 100.0)
	current_amount = data.get("current_amount", max_amount)  # Default to max amount if not provided
	depletion_rate = data.get("depletion_rate", 0.02)  # Default to 0.02 if not provided
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid,
		"min_amount": min_amount,
		"max_amount": max_amount,
		"current_amount": current_amount,
		"depletion_rate": depletion_rate
	}
	if not references.is_empty():
		data["references"] = references
	return data


# Removes the provided reference from references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.playerattributes.save_playerattributes_to_disk()

# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.playerattributes.save_playerattributes_to_disk()

# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.playerattributes.spritePath + spriteid

# Handles playerattribute changes and updates references if necessary
func on_data_changed(_oldplayerattribute: DPlayerAttribute):
	var changes_made = false
	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Tile reference updates saved successfully.")


# Some playerattribute has been changed
# INFO if the playerattributes reference other entities, update them here
func changed(_olddata: DPlayerAttribute):
	Gamedata.playerattributes.save_playerattributes_to_disk()


# A playerattribute is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check if the playerattribute has references to maps and remove it from those maps
	var mapsdata = Helper.json_helper.get_nested_data(references, "core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("playerattribute", id, mapsdata)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
