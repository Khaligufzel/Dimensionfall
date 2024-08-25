extends Node

# Autoload singleton that loads all game data required to run the game
# Accessible via Gamedata.property
var data: Dictionary = {}
var maps: DMaps
var furnitures: DFurnitures
var items: DItems
var tiles: DTiles
var mobs: DMobs
var itemgroups: DItemgroups
var playerattributes: DPlayerAttributes
var wearableslots: DWearableSlots
var stats: DStats
var skills: DSkills
var quests: DQuests

# Dictionary keys for game data categories
const DATA_CATEGORIES = {
	"overmaptiles": {"spritePath": "./Mods/Core/OvermapTiles/"},
	"tacticalmaps": {"dataPath": "./Mods/Core/TacticalMaps/"}
}

# Dictionary to store loaded textures
var textures: Dictionary = {
	"container": load("res://Textures/container_32.png"),
	"container_filled": load("res://Textures/container_filled_32.png")
}

# We write down the associated paths for the files to load
# Next, sprites are loaded from spritesPath into the .sprites property
# Finally, the data is loaded from dataPath into the .data property
func _ready():
	initialize_data_structures()
	load_sprites()
	load_data()
	data.tacticalmaps.data = Helper.json_helper.file_names_in_dir(data.tacticalmaps.dataPath, ["json"])
	maps = DMaps.new()
	furnitures = DFurnitures.new()
	items = DItems.new()
	tiles = DTiles.new()
	mobs = DMobs.new()
	itemgroups = DItemgroups.new()
	playerattributes = DPlayerAttributes.new()
	wearableslots = DWearableSlots.new()
	stats = DStats.new()
	skills = DSkills.new()
	quests = DQuests.new()


# Initializes the data structures for each category defined in DATA_CATEGORIES
func initialize_data_structures():
	for category in DATA_CATEGORIES.keys():
		data[category] = {"data": [], "sprites": {}}
		if DATA_CATEGORIES[category].has("dataPath"):
			data[category]["dataPath"] = DATA_CATEGORIES[category]["dataPath"]
		if DATA_CATEGORIES[category].has("spritePath"):
			data[category]["spritePath"] = DATA_CATEGORIES[category]["spritePath"]


#Loads json data. If no json file exists, it will create an empty array in a new file
func load_data() -> void:
	for dict in data.keys():
		if data[dict].has("dataPath"):
			var dataPath: String = data[dict].dataPath
			if FileAccess.file_exists(dataPath):
				Helper.json_helper.create_new_json_file(dataPath)
				data[dict].data = Helper.json_helper.load_json_array_file(dataPath)
			else:
				data[dict].data = []


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	for dict in data.keys():
		if data[dict].has("spritePath"):
			var loaded_sprites: Dictionary = {}
			var spritesDir: String = data[dict].spritePath
			var png_files: Array = Helper.json_helper.file_names_in_dir(spritesDir, ["png"])
			for png_file in png_files:
				# Load the .png file as a texture
				var texture := load(spritesDir + png_file) 
				# Add the material to the dictionary
				loaded_sprites[png_file] = texture
			data[dict].sprites = loaded_sprites


# Adds a sprite to a specific dictionary and emits a signal if successful
func add_sprite_to_dictionary(contentData: Dictionary, file_name: String, texture: Texture):
	if texture:
		contentData.sprites[file_name] = texture
		Helper.signal_broker.data_sprites_changed.emit(contentData, file_name)
		print("Sprite added:", file_name)
	else:
		print("Failed to add sprite:", file_name)


# This function will duplicate a file with the provided original ID
# and save it under a new ID within the same directory.
func duplicate_file_in_data(contentData: Dictionary, original_id: String, new_id: String) -> void:
	var data_path: String = contentData.dataPath
	var original_file_path: String = data_path + original_id + ".json"
	var new_file_path: String = data_path + new_id + ".json"

	if not FileAccess.file_exists(original_file_path):
		print_debug("Original file not found: " + original_file_path)
		return

	# Load the original file content.
	var orig_content = Helper.json_helper.load_json_dictionary_file(original_file_path)

	# Write the original content to a new file with the new ID.
	var save_result = Helper.json_helper.write_json_file(new_file_path, JSON.stringify(orig_content, "\t"))
	if save_result == OK:
		print_debug("File duplicated successfully: " + new_file_path)
		if contentData.data is Array and data_path.ends_with("/"):
			contentData.data.append(new_id + ".json")
	else:
		print_debug("Failed to duplicate file to: " + new_file_path)


# This function appends a new object to an existing array
# Pass the contentData dictionary to this function and the value of the ID
# If the data directory ends in .json, it will append an object
# The object that will be appended will be nothing more then {"id": id}
# if the data directory does not end in .json, a new file will be added
# This file will get the name as specified by id, so for example "myhouse"
# After the ID is added, the data array will be saved to disk
func add_id_to_data(contentData: Dictionary, id: String):
	if not contentData.has("data"):
		return
	if contentData.dataPath.ends_with(".json"):
		if get_array_index_by_id(contentData, id) != -1:
			print_debug("Tried to add an existing id to an array")
			return
		contentData.data.append({"id": id})
		save_data_to_file(contentData)
	else:
		if id in contentData.data:
			print_debug("Tried to add an existing file to a file array")
			return
		contentData.data.append(id + ".json")
		#Create a new json file in the directory with only {} in the file
		Helper.json_helper.create_new_json_file(contentData.dataPath + id + ".json", false)


# Will remove an item from the data
# If the first item in data is a dictionary, we remove an item that has the provided id
# If the first item in data is a string, we remove the string and the associated json file
func remove_item_from_data(contentData: Dictionary, id: String):
	if contentData.data.is_empty():
		return
	if contentData.dataPath.ends_with(".json"): # It's a json file
		remove_references_of_deleted_id(contentData, id)
		contentData.data.remove_at(get_array_index_by_id(contentData, id))
		save_data_to_file(contentData)
	elif contentData.dataPath.ends_with("/"): # It's a folder
		remove_references_of_deleted_id(contentData, id)
		contentData.data.erase(id)
		var json_file_path = contentData.dataPath + id + ".json"
		Helper.json_helper.delete_json_file(json_file_path)
	else:
		print_debug("Tried to remove item from data, but the data's datapath ends with \
		neither .json nor /")


# Gets the array index of an item by its ID
func get_array_index_by_id(contentData: Dictionary, id: String) -> int:
	# Iterate through the array
	for i in range(len(contentData.data)):
		# Check if the current item is a dictionary
		if typeof(contentData.data[i]) == TYPE_DICTIONARY:
			# Check if it has the 'id' key and matches the given ID
			if contentData.data[i].has("id") and contentData.data[i]["id"] == id:
				return i
		# Check if the current item is a string and matches the given ID
		elif typeof(contentData.data[i]) == TYPE_STRING and contentData.data[i] == id:
			return i
	# Return -1 if the ID is not found
	return -1


# Saves data to file
func save_data_to_file(contentData: Dictionary):
	var datapath: String = contentData.dataPath
	if datapath.ends_with(".json"):
		Helper.json_helper.write_json_file(datapath, JSON.stringify(contentData.data, "\t"))


# Takes contentdata and an id and returns the json that belongs to an id
# For example, contentData can be Gamedata.data.overmaps
# and id can be "plain_grass" and it will return the json data for plain_grass
func get_data_by_id(contentData: Dictionary, id: String) -> Dictionary:
	var idnr: int = get_array_index_by_id(contentData, id)
	if idnr < 0:
		return {}
	return contentData.data[idnr]


# Takes contentData and an id and returns the sprite associated with the id
# For example, contentData can be Gamedata.data.overmaps
# and id can be "plain_grass" and it will return the sprite for plain_grass
func get_sprite_by_id(contentData: Dictionary, id: String) -> Resource:
	if contentData.sprites.is_empty() or contentData.data.is_empty():
		return null
	
	# Check if the datapath ends with .json (indicating a list item)
	if contentData.dataPath.ends_with(".json"):
		var item_json = get_data_by_id(contentData, id)
		if item_json.has("sprite"):
			return contentData.sprites.get(item_json["sprite"], null)
		else:
			return null
	else:
		# Treat as a file in a folder
		return contentData.sprites.get(id + ".png", null)


# Removes all references of a deleted entity ID
func remove_references_of_deleted_id(contentData: Dictionary, id: String):
	if contentData == data.tacticalmaps:
		on_tacticalmap_deleted(id)


# Erases a nested property from a dictionary based on a dot-separated path
func erase_property_by_path(mydata: Dictionary, item_id: String, property_path: String):
	var entity_data = get_data_by_id(mydata, item_id)
	if entity_data.is_empty():
		print_debug("Entity with ID", item_id, "not found.")
		return false

	# Split the path and process the nesting
	var path_parts = property_path.split(".")
	var current_dict = entity_data
	for i in range(path_parts.size() - 1):  # Navigate to the last dictionary
		if path_parts[i] in current_dict:
			current_dict = current_dict[path_parts[i]]
		else:
			print_debug("Path not found:", path_parts[i])
			return false

	# Last part of the path is the key to erase
	var last_key = path_parts[-1]
	if last_key in current_dict:
		current_dict.erase(last_key)
		print_debug("Property", last_key, "erased successfully.")
		return true
	else:
		print_debug("Property", last_key, "not found.")
		return false

# Executes a callable function on each reference of the given type
# data = json data representing one entity
# module = name of the mod. for example "core"
# type = the type of reference we want to handle. For example "item"
# callable = a function to execute on each reference ID
# We will check if data has the ["references"] and [type] properties and execute the callable on each found ID
func execute_callable_on_references_of_type(mydata: Dictionary, module: String, type: String, callable: Callable):
	# Check if 'data' contains a 'references' dictionary and if it contains the specified 'type'
	if mydata.has("references") and mydata["references"].has(module) and mydata["references"][module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in mydata["references"][module][type]:
			callable.call(ref_id)


# Retrieves the value of a nested property from a dictionary based on a dot-separated path
func get_property_by_path(mydata: Dictionary, property_path: String, entity_id: String) -> Variant:
	var entity_data = get_data_by_id(mydata, entity_id)
	if entity_data.is_empty():
		print_debug("Entity with ID", entity_id, "not found.")
		return null
	return Helper.json_helper.get_nested_data(entity_data, property_path)


# A tacticalmap is being deleted. Remove all references to this tacticalmap
func on_tacticalmap_deleted(tacticalmap_id: String):
	var file = data.tacticalmaps.dataPath + tacticalmap_id + ".json"
	var tacticalmapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(file)
	if not tacticalmapdata.has("chunks"):
		print("Tacticalmap data does not contain 'chunks'.")
		return
	for i in range(tacticalmapdata["chunks"].size()):
		var chunk = tacticalmapdata["chunks"][i]
		# If the chunk has the target id, remove the reference from the map
		if chunk.has("id"):
			maps.remove_reference_from_map(chunk["id"],"core", "tacticalmaps",tacticalmap_id + ".json")


func on_tacticalmapdata_changed(tacticalmap_id: String, newdata: Dictionary, olddata: Dictionary):
	# Collect unique IDs from old data
	var unique_old_ids: Array = []
	var ids_dict_old: Dictionary = {}
	if olddata.has("chunks") and olddata["chunks"] is Array:
		for chunk in olddata["chunks"]:
			if chunk.has("id"):
				ids_dict_old[chunk["id"]] = true
	unique_old_ids = ids_dict_old.keys()

	# Collect unique IDs from new data
	var unique_new_ids: Array = []
	var ids_dict_new: Dictionary = {}
	if newdata.has("chunks") and newdata["chunks"] is Array:
		for chunk in newdata["chunks"]:
			if chunk.has("id"):
				ids_dict_new[chunk["id"]] = true
	unique_new_ids = ids_dict_new.keys()
	tacticalmap_id = tacticalmap_id.get_file()
	# Add references for new IDs
	for id in unique_new_ids:
		maps.add_reference_to_map(id, "core", "tacticalmaps", tacticalmap_id)
	# Remove references for IDs not present in new data
	for id in unique_old_ids:
		if id not in unique_new_ids:
			maps.remove_reference_from_map(id, "core", "tacticalmaps", tacticalmap_id)




# Removes the provided reference from references
# For example, remove "town_00" from references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
# TODO: Have this function replace add_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dremove_reference(references: Dictionary, module: String, type: String, refid: String) -> bool:
	var changes_made = false
	var refs = references[module][type]
	if refid in refs:
		refs.erase(refid)
		changes_made = true
		# Clean up if necessary
		if refs.size() == 0:
			references[module].erase(type)
		if references[module].is_empty():
			references.erase(module)
	return changes_made


# Adds a reference to the references list
# For example, add "town_00" to references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
# TODO: Have this function replace add_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dadd_reference(references: Dictionary, module: String, type: String, refid: String) -> bool:
	var changes_made: bool = false
	if not references.has(module):
		references[module] = {}
	if not references[module].has(type):
		references[module][type] = []
	if refid not in references[module][type]:
		references[module][type].append(refid)
		changes_made = true
	return changes_made


# Helper function to update references if they have changed.
# old: an entity id that is present in the old data
# new: an entity id that is present in the new data
# entity_id: The entity that's referenced in old and/or new
# type: The type of entity that will be referenced
# Example usage: update_reference(old_quest, new_quest, item_id, "item")
# This example will remove item_id from the old_quest's references and
# add the item_id to the new_quest's refrences
# TODO: Have this function replace update_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dupdate_reference(ref: Dictionary, old: String, new: String, type: String) -> bool:
	if old == new:
		return false  # No change detected, exit early

	var changes_made = false

	# Remove from old group if necessary
	if old != "":
		changes_made = dremove_reference(ref, "core", type, old) or changes_made
	if new != "":
		changes_made = dadd_reference(ref, "core", type, new) or changes_made
	return changes_made
