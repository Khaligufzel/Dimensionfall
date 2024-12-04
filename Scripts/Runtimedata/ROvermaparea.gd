class_name ROvermaparea
extends RefCounted

# This class represents an overmap area with its properties
# Only used while the game is running
# Example overmap area data:
# {
#     "id": "city_00",
#     "name": "Example City",
#     "description": "A densely populated urban area surrounded by suburban regions and open fields.",
#     "min_width": 5,
#     "min_height": 5,
#     "max_width": 15,
#     "max_height": 15,
#     "regions": {
#         "urban": {
#             "spawn_probability": {
#                 "range": {
#                     "start_range": 0,
#                     "end_range": 30
#                 }
#             },
#             "maps": [
#                 { "id": "house_01", "weight": 10 },
#                 { "id": "shop_01", "weight": 5 },
#                 { "id": "park_01", "weight": 2 }
#             ]
#         },
#         "field": {
#             "spawn_probability": {
#                 "range": {
#                     "start_range": 70,
#                     "end_range": 100
#                 }
#             },
#             "maps": [
#                 { "id": "field_01", "weight": 12 },
#                 { "id": "barn_01", "weight": 6 },
#                 { "id": "tree_01", "weight": 8 }
#             ]
#         }
#     }
# }

# Properties defined in the overmap area
var id: String
var name: String
var description: String
var min_width: int
var min_height: int
var max_width: int
var max_height: int
var regions: Dictionary = {}  # Example: { "urban": { "spawn_probability": {...}, "maps": [...] } }
var parent: ROvermapareas

# Constructor to initialize overmap area properties from a dictionary
func _init(myparent: ROvermapareas, newid: String):
	parent = myparent
	id = newid

# Overwrite this overmap area's properties using a DOvermaparea
func overwrite_from_dovermaparea(dovermaparea: DOvermaparea) -> void:
	if not id == dovermaparea.id:
		print_debug("Cannot overwrite from a different ID")
	name = dovermaparea.name
	description = dovermaparea.description
	min_width = dovermaparea.min_width
	min_height = dovermaparea.min_height
	max_width = dovermaparea.max_width
	max_height = dovermaparea.max_height
	regions = dovermaparea.regions.duplicate(true)

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"min_width": min_width,
		"min_height": min_height,
		"max_width": max_width,
		"max_height": max_height,
		"regions": regions
	}
	return data
