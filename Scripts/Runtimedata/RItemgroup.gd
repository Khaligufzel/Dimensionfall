class_name RItemgroup
extends RefCounted

# This class represents an item group with its properties, only used while the game is running.
# Example itemgroup data:
# {
#     "id": "mob_loot",
#     "name": "Mob loot",
#     "description": "Loot that's dropped by a mob",
#     "mode": "Collection",
#     "items": [
#         {
#             "id": "bullet_9mm",
#             "max": 20,
#             "min": 10,
#             "probability": 20
#         },
#         {
#             "id": "pistol_magazine",
#             "max": 1,
#             "min": 1,
#             "probability": 20
#         }
#     ]
# }

# Subclass to represent individual items in the itemgroup
class Item:
	var id: String
	var maxc: int # max count
	var minc: int # min count
	var probability: int

	func _init(data: Dictionary):
		id = data.get("id", "")
		maxc = data.get("max", 1)
		minc = data.get("min", 1)
		probability = data.get("probability", 100)

	func get_data() -> Dictionary:
		return {
			"id": id,
			"max": maxc,
			"min": minc,
			"probability": probability
		}

# Properties defined in the itemgroup
var id: String
var name: String
var description: String
var mode: String # "Collection" or "Distribution"
var items: Array[Item] = []
var use_sprite: bool = false
var spriteid: String
var parent: RItemgroups  # Reference to the list containing all runtime itemgroups for this mod

# Constructor to initialize itemgroup properties
# myparent: The list containing all runtime itemgroups for this mod
# newid: The ID of the itemgroup being created
func _init(myparent: RItemgroups, newid: String):
	parent = myparent
	id = newid

# Overwrite this itemgroup's properties using a DItemgroup
func overwrite_from_ditemgroup(ditemgroup: DItemgroup) -> void:
	if not id == ditemgroup.id:
		print_debug("Cannot overwrite from a different id")
	name = ditemgroup.name
	description = ditemgroup.description
	mode = ditemgroup.mode
	use_sprite = ditemgroup.use_sprite
	spriteid = ditemgroup.spriteid
	
	# Convert DItemgroup items to RItemgroup items
	items.clear()
	for ditem in ditemgroup.items:
		items.append(Item.new(ditem.get_data()))

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var item_data = []
	for item in items:
		item_data.append(item.get_data())

	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"mode": mode,
		"items": item_data
	}
	return data
