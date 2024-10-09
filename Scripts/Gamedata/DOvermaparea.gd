class_name DOvermaparea
extends RefCounted

# This class represents a overmaparea with its properties
# Example overmaparea data:
# {
#   "overmap_area": {
#     "name": "Example City",  // Name for the overmap area
#     "description": "A densely populated urban area surrounded by suburban regions and open fields.",  // Description of the overmap area
#     "min_width": 5,  // Minimum width of the overmap area
#     "min_height": 5,  // Minimum height of the overmap area
#     "max_width": 15,  // Maximum width of the overmap area
#     "max_height": 15,  // Maximum height of the overmap area
#     "regions": {
#       "urban": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 0,  // Will start spawning at 0% distance from the center
#             "end_range": 30     // Will stop spawning at 30% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "house_01",
#             "weight": 10  // Higher weight means this map has a higher chance to spawn in this region
#           },
#           {
#             "id": "shop_01",
#             "weight": 5
#           },
#           {
#             "id": "park_01",
#             "weight": 2
#           }
#         ]
#       },
#       "suburban": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 20,  // Will start spawning at 20% distance from the center
#             "end_range": 80     // Will stop spawning at 80% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "house_02",
#             "weight": 8
#           },
#           {
#             "id": "garden_01",
#             "weight": 4
#           },
#           {
#             "id": "school_01",
#             "weight": 3
#           }
#         ]
#       },
#       "field": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 70,  // Will start spawning at 70% distance from the center
#             "end_range": 100     // Will stop spawning at 100% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "field_01",
#             "weight": 12
#           },
#           {
#             "id": "barn_01",
#             "weight": 6
#           },
#           {
#             "id": "tree_01",
#             "weight": 8
#           }
#         ]
#       }
#     }
#   }
# }

# Properties defined in the overmaparea
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var references: Dictionary = {}

# Constructor to initialize overmaparea properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("sprite", "")
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid
	}
	if not references.is_empty():
		data["references"] = references
	return data


# Method to save any changes to the overmaparea back to disk
func save_to_disk():
	Gamedata.overmapareas.save_overmapareas_to_disk()


# Removes the provided reference from references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.overmapareas.save_overmapareas_to_disk()


# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.overmapareas.save_overmapareas_to_disk()


# Some overmaparea has been changed
# INFO if the overmaparea references other entities, update them here
func changed(_olddata: DOvermaparea):
	Gamedata.overmapareas.save_overmapareas_to_disk()


# A overmaparea is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes: Dictionary = {"made":false}
	
	# This callable will remove this overmaparea from items that reference this overmaparea.
	var myfunc: Callable = func (item_id):
		var item_data: DItem = Gamedata.items.by_id(item_id)
		item_data.remove_overmaparea(id)
		changes.made = true
	
	# Pass the callable to every item in the overmaparea's references
	# It will call myfunc on every item in overmaparea_data.references.core.items
	execute_callable_on_references_of_type("core", "items", myfunc)
	
	# Save changes to the data file if any changes were made
	if changes.made:
		Gamedata.items.save_items_to_disk()
	else:
		print_debug("No changes needed for item", id)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
