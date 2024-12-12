class_name DWearableSlot
extends RefCounted

# This class represents a wearable slot with its properties
# Example wearable slot data:
#	{
#		"description": "Holds equipment on your torso",
#		"id": "torso",
#		"name": "Torso",
#		"references": {
#			"core": {
#				"items": [
#					"jacket",
#					"tshirt",
#					"sweater"
#				]
#			}
#		},
#		"sprite": "wearableslot_torso_32.png"
#	}

# Properties defined in the wearable slot
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var parent: DWearableSlots

# Constructor to initialize quest properties from a dictionary
# myparent: The list containing all quests for this mod
func _init(data: Dictionary, myparent: DWearableSlots):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}
	return data

# Method to save any changes to the wearable slot back to disk
func save_to_disk():
	parent.save_wearableslots_to_disk()


# Some wearableslot has been changed
# INFO if the wearableslot reference other entities, update them here
func changed(_olddata: DItemgroup):
	parent.save_wearableslots_to_disk()


# A wearableslot is being deleted from the data
# We have to remove it from everything that references it
func delete():
	for mod: DMod in Gamedata.mods.get_all_mods():
		mod.items.remove_wearableslot_from_all_items(id)
