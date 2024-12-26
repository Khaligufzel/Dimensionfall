class_name DWearableSlot
extends RefCounted

# This class represents a wearable slot with its properties
# Example wearable slot data:
#	{
#		"description": "Holds equipment on your torso",
#		"id": "torso",
#		"name": "Torso",
#       "starting_item": "boots_fancy",
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
var starting_item: String
var parent: DWearableSlots

# Constructor to initialize quest properties from a dictionary
# myparent: The list containing all quests for this mod
func _init(data: Dictionary, myparent: DWearableSlots):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	starting_item = data.get("starting_item", "")

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}
	if starting_item:
		data["starting_item"] = starting_item
	return data

# Method to save any changes to the wearable slot back to disk
func save_to_disk():
	parent.save_wearableslots_to_disk()


# Some wearableslot has been changed
# INFO if the wearableslot reference other entities, update them here
func changed(olddata: DItemgroup):
	_update_references(olddata.starting_item, starting_item)
	parent.save_wearableslots_to_disk()


func _update_references(old_value: String, new_value: String):
	if old_value != new_value:
		if old_value != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, old_value, DMod.ContentType.WEARABLESLOTS, id)
		if new_value != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMS, new_value, DMod.ContentType.WEARABLESLOTS, id)


# A wearableslot is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this furniture. If one or more remain, we can keep references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.WEARABLESLOTS, id)
	if all_results.size() > 1:
		parent.remove_reference(id)  # Erase the reference for the ID in this mod
		return

	for mod: DMod in Gamedata.mods.get_all_mods():
		mod.items.remove_wearableslot_from_all_items(id)
	Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, starting_item, DMod.ContentType.WEARABLESLOTS, id)


func remove_item(item_id: String):
	if starting_item == item_id:
		starting_item = ""
	parent.save_furnitures_to_disk()
