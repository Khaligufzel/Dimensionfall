class_name RWearableSlot
extends RefCounted

# This class represents a wearable slot with its properties
# Only used while the game is running
# Example wearable slot data:
# {
#     "description": "Holds equipment on your torso",
#     "id": "torso",
#     "name": "Torso",
#     "sprite": "wearableslot_torso_32.png",
#     "starting_item": "boots_fancy",
#     "references": {
#         "core": {
#             "items": [
#                 "jacket",
#                 "tshirt",
#                 "sweater"
#             ]
#         }
#     }
# }

# Properties defined in the wearable slot
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var starting_item: String
var parent: RWearableSlots  # Reference to the list containing all runtime wearable slots for this mod

# Constructor to initialize wearable slot properties from a dictionary
# myparent: The list containing all wearable slots for this mod
# newid: The ID of the wearable slot being created
func _init(myparent: RWearableSlots, newid: String):
	parent = myparent
	id = newid

# Overwrite this wearable slot's properties using a DWearableSlot
func overwrite_from_dwearableslot(dwearableslot: DWearableSlot) -> void:
	if not id == dwearableslot.id:
		print_debug("Cannot overwrite from a different id")
	name = dwearableslot.name
	description = dwearableslot.description
	spriteid = dwearableslot.spriteid
	sprite = dwearableslot.sprite
	starting_item = dwearableslot.starting_item

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
