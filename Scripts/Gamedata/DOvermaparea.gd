class_name DOvermaparea
extends RefCounted

# This class represents a overmaparea with its properties
# Example overmaparea data:
# {
#     "id": "city_00",  // id for the overmap area
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
# }

# Properties defined in the overmaparea
var id: String
var name: String
var description: String
var parent: DOvermapareas

# Dimensions of the overmap area
var min_width: int
var min_height: int
var max_width: int
var max_height: int

# Regions data, which includes spawn probability and maps for each region type
var regions: Dictionary = {}  # Example structure: { "urban": { "spawn_probability": { "range": { "start_range": 0, "end_range": 30 } }, "maps": [...] }, ... }


# Inner class to represent a region within the overmap area
class Region:
	var spawn_probability: Dictionary  # Example structure: { "range": { "start_range": 0, "end_range": 30 } }
	var maps: Array  # Example structure: [ { "id": "house_01", "weight": 10 }, ...]

	# Constructor to initialize a region with spawn probability and maps data
	func _init(spawn_probability: Dictionary = {}, maps: Array = []):
		self.spawn_probability = spawn_probability
		self.maps = maps

	# Method to return the region data as a dictionary
	func get_data() -> Dictionary:
		return {
			"spawn_probability": spawn_probability,
			"maps": maps
		}

	# Method to retrieve all unique map IDs in this region
	func get_map_ids() -> Array:
		var map_ids = []
		for map_entry in maps:
			if map_entry.has("id") and map_entry["id"] not in map_ids:
				map_ids.append(map_entry["id"])
		return map_ids

# Constructor to initialize overmaparea properties from a dictionary
func _init(data: Dictionary, myparent: DOvermapareas):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")

	# Initialize dimensions of the overmap area
	min_width = data.get("min_width", 0)
	min_height = data.get("min_height", 0)
	max_width = data.get("max_width", 0)
	max_height = data.get("max_height", 0)

	# Initialize regions from data
	for region_key in data.get("regions", {}).keys():
		var region_data = data["regions"][region_key]
		var spawn_probability = region_data.get("spawn_probability", {})
		var maps = region_data.get("maps", [])
		regions[region_key] = Region.new(spawn_probability, maps)


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
		"regions": {}
	}
	# Add regions data to the dictionary
	for region_key in regions.keys():
		data["regions"][region_key] = regions[region_key].get_data()
	return data


# Method to save any changes to the overmaparea back to disk
func save_to_disk():
	Gamedata.mods.by_id("Core").overmapareas.save_overmapareas_to_disk()


# Some overmaparea has been changed
# INFO if the overmaparea references other entities, update them here
func changed(olddata: DOvermaparea):
	# Retrieve the list of map IDs from the old data and the new data
	var old_map_ids = olddata.get_all_map_ids()
	var new_map_ids = get_all_map_ids()

	# Remove references to map IDs that are in the old data but not in the new data
	for map_id in old_map_ids:
		if map_id not in new_map_ids:
			Gamedata.mods.remove_reference(DMod.ContentType.MAPS, map_id, DMod.ContentType.OVERMAPAREAS, id)

	# Add references to map IDs that are in the new data, even if they were already in the old data
	for map_id in new_map_ids:
		Gamedata.mods.add_reference(DMod.ContentType.MAPS, map_id, DMod.ContentType.OVERMAPAREAS, id)

	# Save the updated overmap area data to disk
	parent.save_overmapareas_to_disk()


# A overmaparea is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this overmaparea. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.OVERMAPAREAS, id)
	if all_results.size() > 0:
		return
		
	var map_ids = get_all_map_ids()
	for map: String in map_ids:
		Gamedata.mods.remove_reference(DMod.ContentType.MAPS, map, DMod.ContentType.OVERMAPAREAS, id)


# Function to retrieve a list of all unique map IDs across all regions in the overmap area
func get_all_map_ids() -> Array:
	var unique_map_ids = []
	for region in regions.values():
		var region_map_ids = region.get_map_ids()
		for map_id in region_map_ids:
			if map_id not in unique_map_ids:
				unique_map_ids.append(map_id)
	return unique_map_ids


# Function to remove a specific map ID from all regions in the overmap area
func remove_map_from_all_regions(map_id: String) -> void:
	for region_key in regions.keys():
		var region = regions[region_key]
		# Filter out the map entries that do not match the given map_id
		region.maps = region.maps.filter(func(map_entry):
			return map_entry.get("id", "") != map_id
		)
	# Save the updated overmap area data to disk
	save_to_disk()
