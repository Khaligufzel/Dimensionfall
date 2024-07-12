extends Node

# Autoload singleton that loads all game data required to run the game
# Accessible via Gamedata.property
var data: Dictionary = {}
const map_references_Class = preload("res://Scripts/Gamedata/map_references.gd")
var map_references: Node = null
const itemgroup_references_Class = preload("res://Scripts/Gamedata/itemgroup_references.gd")
var itemgroup_references: Node = null

# Dictionary keys for game data categories
const DATA_CATEGORIES = {
	"tiles": {"dataPath": "./Mods/Core/Tiles/Tiles.json", "spritePath": "./Mods/Core/Tiles/"},
	"mobs": {"dataPath": "./Mods/Core/Mobs/Mobs.json", "spritePath": "./Mods/Core/Mobs/"},
	"items": {"dataPath": "./Mods/Core/Items/Items.json", "spritePath": "./Mods/Core/Items/"},
	"furniture": {"dataPath": "./Mods/Core/Furniture/Furniture.json", "spritePath": "./Mods/Core/Furniture/"},
	"overmaptiles": {"spritePath": "./Mods/Core/OvermapTiles/"},
	"tacticalmaps": {"dataPath": "./Mods/Core/TacticalMaps/"},
	"maps": {"dataPath": "./Mods/Core/Maps/", "spritePath": "./Mods/Core/Maps/"},
	"itemgroups": {"dataPath": "./Mods/Core/Itemgroups/Itemgroups.json", "spritePath": "./Mods/Core/Items/"},
	"wearableslots": {"dataPath": "./Mods/Core/Wearableslots/Wearableslots.json", "spritePath": "./Mods/Core/Wearableslots/"},
	"stats": {"dataPath": "./Mods/Core/Stats/Stats.json", "spritePath": "./Mods/Core/Stats/"},
	"skills": {"dataPath": "./Mods/Core/Skills/Skills.json", "spritePath": "./Mods/Core/Skills/"},
	"quests": {"dataPath": "./Mods/Core/Quests/Quests.json", "spritePath": "./Mods/Core/Items/"}
}


# We write down the associated paths for the files to load
# Next, sprites are loaded from spritesPath into the .sprites property
# Finally, the data is loaded from dataPath into the .data property
# Maps tile sprites and map data are different so they 
# are loaded in using their respective functions
func _ready():
	initialize_data_structures()
	load_sprites()
	load_tile_sprites()
	load_data()
	update_item_protoset_json_data("res://ItemProtosets.tres", JSON.stringify(data.items.data, "\t"))
	data.maps.data = Helper.json_helper.file_names_in_dir(data.maps.dataPath, ["json"])
	data.tacticalmaps.data = Helper.json_helper.file_names_in_dir(data.tacticalmaps.dataPath, ["json"])
	map_references = map_references_Class.new()
	itemgroup_references = itemgroup_references_Class.new()

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


# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_tile_sprites() -> void:
	var tile_materials: Dictionary = {} # Materials used to represent tiles
	var tilesDir = data.tiles.spritePath
	var png_files: Array = Helper.json_helper.file_names_in_dir(tilesDir, ["png"])
	for png_file in png_files:
		var texture := load(tilesDir + png_file) # Load the .png file as a texture
		var material := StandardMaterial3D.new() 
		material.albedo_texture = texture # Set the texture of the material
		material.uv1_scale = Vector3(3,2,1)
		tile_materials[png_file] = material # Add the material to the dictionary
	data.tiles.sprites = tile_materials


# Adds a sprite to a specific dictionary and emits a signal if successful
func add_sprite_to_dictionary(contentData: Dictionary, file_name: String, texture: Texture):
	if texture:
		contentData.sprites[file_name] = texture
		Helper.signal_broker.data_sprites_changed.emit(contentData, file_name)
		print("Sprite added:", file_name)
	else:
		print("Failed to add sprite:", file_name)


#This function will take two strings called ID and newID
#It will find an item with this ID in a json file specified by the source variable
#It will then duplicate that item into the json file and change the ID to newID
func duplicate_item_in_data(contentData: Dictionary, id: String, newID: String):
	if contentData.data.is_empty():
		return

	if contentData.dataPath.ends_with((".json")):
		# Check if an item with the given ID exists in the file.
		var item_index: int = get_array_index_by_id(contentData,id)
		if item_index == -1:
			return
		
		# Duplicate the found item recursively
		var item_to_duplicate = contentData.data[item_index].duplicate(true)
		
		# If there is no item to duplicate, return without doing anything.
		if item_to_duplicate == null:
			return
		# This new item cannot have anything reference it, because it was just created
		# So we remove all refrences that might have been duplicated from the original
		item_to_duplicate.erase("references")
		# Change the ID of the duplicated item.
		item_to_duplicate["id"] = newID
		# Add the duplicated item to the JSON data.
		contentData.data.append(item_to_duplicate)
		Helper.json_helper.write_json_file(contentData.dataPath, JSON.stringify(contentData.data, "\t"))
		on_data_changed(contentData, item_to_duplicate, {})
	else:
		print_debug("There should be code here for when a file gets duplicated")


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
			if data_path.ends_with("/Maps/"): # Update references to this duplicated map
				map_references.on_mapdata_changed(new_file_path, orig_content, {"levels": []})
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
		var png_file_path = id + ".png"
		Helper.json_helper.delete_json_file(json_file_path)
		# Use DirAccess to check and delete the PNG file (for maps)
		var dir = DirAccess.open(contentData.dataPath)
		if dir.file_exists(png_file_path):
			dir.remove(id + ".png")
			dir.remove(id + ".png.import")
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
	if contentData == data.items:
		# Update the itemprotosets
		update_item_protoset_json_data("res://ItemProtosets.tres", JSON.stringify(contentData.data, "\t"))


# Takes contentdata and an id and returns the json that belongs to an id
# For example, contentData can be Gamedata.data.tiles
# and id can be "plain_grass" and it will return the json data for plain_grass
func get_data_by_id(contentData: Dictionary, id: String) -> Dictionary:
	var idnr: int = get_array_index_by_id(contentData, id)
	if idnr < 0:
		return {}
	return contentData.data[idnr]


# Takes contentData and an id and returns the sprite associated with the id
# For example, contentData can be Gamedata.data.tiles
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

# This function is called when an editor has changed data
# The contenteditor (that initializes the individual editors)
# connects the changed_data signal to this function
# and binds the appropriate data array so it can be saved in this function
func on_data_changed(contentData: Dictionary, newEntityData: Dictionary, oldEntityData: Dictionary):
	if contentData == data.itemgroups:
		itemgroup_references.on_itemgroup_changed(newEntityData, oldEntityData)
	if contentData == data.mobs:
		on_mob_changed(newEntityData, oldEntityData)
	if contentData == data.furniture:
		on_furniture_changed(newEntityData, oldEntityData)
	if contentData == data.items:
		on_item_changed(newEntityData, oldEntityData)
	if contentData == data.quests:
		on_quest_changed(newEntityData, oldEntityData)
	save_data_to_file(contentData)


# This will update the given resource file with the provided json data
# It is intended to save item data from json to the res://ItemProtosets.tres file
# So we can use the item json data in-game
func update_item_protoset_json_data(tres_path: String, new_json_data: String) -> void:
	# Load the ItemProtoset resource
	var item_protoset = load(tres_path) as ItemProtoset
	if not item_protoset:
		print_debug("Failed to load ItemProtoset resource from:", tres_path)
		return

	# Update the json_data property
	item_protoset.json_data = new_json_data

	# Save the resource back to the .tres file
	var save_result = ResourceSaver.save(item_protoset, tres_path)
	if save_result != OK:
		print_debug("Failed to save updated ItemProtoset resource to:", tres_path)
	else:
		print_debug("ItemProtoset resource updated and saved successfully to:", tres_path)

# Filters items by type
func get_items_by_type(item_type: String) -> Array:
	var filtered_items = []
	if data.has("items") and data.items.has("data") and typeof(data.items.data) == TYPE_ARRAY:
		for item in data.items.data:
			if item is Dictionary and item.has(item_type):
				filtered_items.append(item)
	return filtered_items

# Adds a reference to an entity
# data = any data group, like Gamedata.data.itemgroups
# type = the type of reference, for example furniture
# onid = where to add the reference to
# refid = The reference to add on the fromid
# Example usage: var changes_made = add_reference(Gamedata.data.itemgroups, "core", 
# "furniture", itemgroup_id, furniture_id)
# This example will add the specified furniture from the itemgroup's references
func add_reference(mydata: Dictionary, module: String, type: String, onid: String, refid: String) -> bool:
	var changes_made: bool = false

	# If onid ends with ".json", handle it as a file reference case
	if onid.ends_with(".json"):
		var filepath = mydata.dataPath + onid
		var file_data = Helper.json_helper.load_json_dictionary_file(filepath)
		if not file_data.has("references"):
			file_data["references"] = {}
		if not file_data["references"].has(module):
			file_data["references"][module] = {}
		if not file_data["references"][module].has(type):
			file_data["references"][module][type] = []
		if refid not in file_data["references"][module][type]:
			file_data["references"][module][type].append(refid)
			changes_made = true

		# Save the updated data back to the file
		var data_json = JSON.stringify(file_data.duplicate(), "\t")
		Helper.json_helper.write_json_file(filepath, data_json)

	# Default behavior for other cases
	else:
		if onid != "":
			var entitydata = get_data_by_id(mydata, onid)
			if not entitydata.has("references"):
				entitydata["references"] = {}
			if not entitydata["references"].has(module):
				entitydata["references"][module] = {}
			if not entitydata["references"][module].has(type):
				entitydata["references"][module][type] = []
			if refid not in entitydata["references"][module][type]:
				entitydata["references"][module][type].append(refid)
				changes_made = true
	return changes_made


# Removes a reference from an entity. 
# data = any data group, like Gamedata.data.itemgroups
# type = the type of reference, for example furniture
# fromid = where to remove the reference from
# refid = The reference to remove from the fromid
# Example usage: var changes_made = remove_reference(Gamedata.data.itemgroups, "core", 
# "furniture", itemgroup_id, furniture_id)
# This example will remove the specified furniture from the itemgroup's references
func remove_reference(mydata: Dictionary, module: String, type: String, fromid: String, refid: String) -> bool:
	var changes_made: bool = false
	
	# If fromid ends with ".json", handle it as a file reference case
	if fromid.ends_with(".json"):
		var filepath = mydata.dataPath + fromid
		var file_data = Helper.json_helper.load_json_dictionary_file(filepath)
		if file_data.has("references") and file_data["references"].has(module) and file_data["references"][module].has(type):
			var refs = file_data["references"][module][type]
			if refid in refs:
				refs.erase(refid)
				changes_made = true
				# Clean up if necessary
				if refs.size() == 0:
					file_data["references"][module].erase(type)
				if file_data["references"][module].is_empty():
					file_data["references"].erase(module)
				if file_data["references"].is_empty():
					file_data.erase("references")

				# Save the updated data back to the file
				var data_json = JSON.stringify(file_data.duplicate(), "\t")
				Helper.json_helper.write_json_file(filepath, data_json)

	# Default behavior for other cases
	else:
		if fromid != "":
			var entitydata = get_data_by_id(mydata, fromid)
			if entitydata.has("references") and entitydata["references"].has(module) and entitydata["references"][module].has(type):
				var refs = entitydata["references"][module][type]
				if refid in refs:
					refs.erase(refid)
					changes_made = true
					if refs.size() == 0:
						entitydata["references"][module].erase(type)
					if entitydata["references"][module].is_empty():
						entitydata["references"].erase(module)
					if entitydata["references"].is_empty():
						entitydata.erase("references")
	return changes_made

# Removes all references of a deleted entity ID
func remove_references_of_deleted_id(contentData: Dictionary, id: String):
	if contentData == data.itemgroups:
		itemgroup_references.on_itemgroup_deleted(id)
	if contentData == data.items:
		on_item_deleted(id)
	if contentData == data.furniture:
		on_furniture_deleted(id)
	if contentData == data.maps:
		map_references.on_map_deleted(id)
	if contentData == data.tacticalmaps:
		on_tacticalmap_deleted(id)
	if contentData == data.mobs:
		on_mob_deleted(id)
	if contentData == data.tiles:
		on_tile_deleted(id)
	if contentData == data.skills:
		on_skill_deleted(id)
	if contentData == data.wearableslots:
		on_wearableslot_deleted(id)
	if contentData == data.quests:
		on_quest_deleted(id)


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
# type = the type of reference we want to handle. For example "furniture"
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


# A mob has been changed.
func on_mob_changed(newdata: Dictionary, olddata: Dictionary):
	var old_loot_group: String = olddata.get("loot_group")
	var new_loot_group: String = newdata.get("loot_group")
	var mob_id: String = newdata.get("id")
	# Exit if old_group and new_group are the same
	if old_loot_group == new_loot_group:
		print_debug("No change in itemgroup. Exiting function.")
		return
	var changes_made = false
	# This furniture will be removed from the old itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	changes_made = remove_reference(data.itemgroups, "core", "mobs", old_loot_group, mob_id) or changes_made
	# This furniture will be added to the new itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	changes_made = add_reference(data.itemgroups, "core", "mobs", new_loot_group, mob_id) or changes_made
	# Save changes if any modifications were made
	if changes_made:
		if old_loot_group != "":
			save_data_to_file(data.itemgroups)
		if new_loot_group != "" and new_loot_group != old_loot_group:
			save_data_to_file(data.itemgroups)

# Handles furniture changes and updates references if necessary
func on_furniture_changed(newdata: Dictionary, olddata: Dictionary):
	var old_container_group = olddata.get("Function", {}).get("container", {}).get("itemgroup", "")
	var new_container_group = newdata.get("Function", {}).get("container", {}).get("itemgroup", "")
	var old_destruction_group = olddata.get("destruction", {}).get("group", "")
	var new_destruction_group = newdata.get("destruction", {}).get("group", "")
	var old_disassembly_group = olddata.get("disassembly", {}).get("group", "")
	var new_disassembly_group = newdata.get("disassembly", {}).get("group", "")
	var furniture_id: String = newdata.get("id", "")
	var changes_made = false

	# Handle container itemgroup changes
	changes_made = update_reference(old_container_group, new_container_group, furniture_id, "furniture") or changes_made

	# Handle destruction group changes
	changes_made = update_reference(old_destruction_group, new_destruction_group, furniture_id, "furniture") or changes_made

	# Handle disassembly group changes
	changes_made = update_reference(old_disassembly_group, new_disassembly_group, furniture_id, "furniture") or changes_made

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Furniture reference updates saved successfully.")
		save_data_to_file(data.itemgroups)

# Helper function to update references if they have changed.
# old: an entity id that is present in the old data
# new: an entity id that is present in the new data
# entity_id: The entity that's referenced in old and/or new
# type: The type of entity that will be referenced
# Example usage: update_reference(old_itemgroup, new_itemgroup, furniture_id, "furniture")
# This example will remove furniture_id from the old_itemgroup's references and
# add the furniture_id to the new_itemgroup's refrences
func update_reference(old: String, new: String, entity_id: String, type: String) -> bool:
	if old == new:
		return false  # No change detected, exit early

	var changes_made = false

	# Remove from old group if necessary
	if old != "":
		changes_made = remove_reference(data.itemgroups, "core", type, old, entity_id) or changes_made
	if new != "":
		changes_made = add_reference(data.itemgroups, "core", type, new, entity_id) or changes_made
	return changes_made


# Some furniture is being deleted from the data
# We have to remove it from everything that references it
func on_furniture_deleted(furniture_id: String):
	var changes_made = false
	var furniture_data = get_data_by_id(data.furniture, furniture_id)
	if furniture_data.is_empty():
		print_debug("Item with ID", furniture_data, "not found.")
		return
	var itemgroup: String = get_property_by_path(data.furniture, "Function.container.itemgroup", furniture_id)
	changes_made = remove_reference(data.itemgroups, "core", "furniture", itemgroup, furniture_id) or changes_made
	var destruction_group: String = ""
	if furniture_data.has("destruction") and furniture_data["destruction"].has("group"):
		destruction_group = furniture_data["destruction"]["group"]
	changes_made = remove_reference(data.itemgroups, "core", "furniture", destruction_group, furniture_id) or changes_made
	var disassembly_group: String = ""
	if furniture_data.has("disassembly") and furniture_data["disassembly"].has("group"):
		disassembly_group = furniture_data["disassembly"]["group"]
	changes_made = remove_reference(data.itemgroups, "core", "furniture", disassembly_group, furniture_id) or changes_made
	var maps = Helper.json_helper.get_nested_data(furniture_data, "references.core.maps")
	for map_id in maps:
		map_references.remove_entity_from_map(map_id, "furniture", furniture_id)
	if changes_made:
		save_data_to_file(data.itemgroups)
	else:
		print_debug("No changes needed for item", furniture_id)


# Some mob is being deleted from the data
# We have to remove it from everything that references it
func on_mob_deleted(mob_id: String):
	var changes_made = { "value": false }
	var mob_data = get_data_by_id(data.mobs, mob_id)
	if mob_data.is_empty():
		print_debug("Item with ID", mob_data, "not found.")
		return
		
	# Remove the reference to this mob from the loot_group
	var loot_group: String = mob_data.get("loot_group", "")
	changes_made["value"] = remove_reference(data.itemgroups, "core", "mobs", loot_group, mob_id) or changes_made["value"]
	
	# Check if the mob has references to maps and remove it from those maps
	var maps = Helper.json_helper.get_nested_data(mob_data,"references.core.maps")
	if maps:
		for map_id in maps:
			map_references.remove_entity_from_map(map_id, "mob", mob_id)
	
	# This callable will handle the removal of this mob from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		var quest_data = get_data_by_id(data.quests, quest_id)
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, "steps.mob", mob_id) or changes_made["value"]
		
	# Pass the callable to every quest in the mob's references
	# It will call remove_from_quest on every mob in mob_data.references.core.quests
	execute_callable_on_references_of_type(mob_data, "core", "quests", remove_from_quest)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		save_data_to_file(data.itemgroups)
		save_data_to_file(data.quests)
	else:
		print_debug("No changes needed for item", mob_id)

# Some tile is being deleted from the data
# We have to remove it from everything that references it
func on_tile_deleted(tile_id: String):
	var tile_data = get_data_by_id(data.tiles, tile_id)
	if tile_data.is_empty():
		print_debug("Item with ID", tile_data, "not found.")
		return

	# Check if the tile has references to maps and remove it from those maps
	var modules = tile_data.get("references", [])
	for mod in modules:
		var maps = Helper.json_helper.get_nested_data(tile_data, "references." + mod + ".maps")
		for map_id in maps:
			map_references.remove_entity_from_map(map_id, "tile", tile_id)


# A map is being deleted. Remove all references to this map
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
			remove_reference(Gamedata.data.maps, "core", "tacticalmaps", \
				chunk["id"], tacticalmap_id + ".json")


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
		add_reference(data.maps, "core", "tacticalmaps", id, tacticalmap_id)
	# Remove references for IDs not present in new data
	for id in unique_old_ids:
		if id not in unique_new_ids:
			remove_reference(data.maps, "core", "tacticalmaps", id, tacticalmap_id)

# Some item has been changed
# We need to update the relation between the item and other items based on crafting recipes
func on_item_changed(newdata: Dictionary, olddata: Dictionary):
	var item_id: String = newdata["id"]
	var changes_made = false
	
	# Handle wearable slot references
	var new_slot = newdata.get("Wearable", {}).get("slot", null)
	var old_slot = olddata.get("Wearable", {}).get("slot", null)
	if new_slot and new_slot != old_slot:
		# Add or update the reference to the new slot
		changes_made = add_reference(data.wearableslots, "core", "items", new_slot, item_id) or changes_made
	if old_slot and old_slot != new_slot:
		changes_made = remove_reference(data.wearableslots, "core", "items", old_slot, item_id) or changes_made
	
	# Dictionaries to track unique resource IDs across all recipes
	var old_resource_ids: Dictionary = {}
	var new_resource_ids: Dictionary = {}

	# Collect all unique resource IDs from old recipes
	for recipe in olddata.get("Craft", []):
		for resource in recipe.get("required_resources", []):
			old_resource_ids[resource["id"]] = true

	# Collect all unique resource IDs from new recipes
	for recipe in newdata.get("Craft", []):
		for resource in recipe.get("required_resources", []):
			new_resource_ids[resource["id"]] = true

	# Resources that are no longer in the recipe will no longer reference this item
	for res_id in old_resource_ids:
		if not new_resource_ids.has(res_id):
			changes_made = remove_reference(data.items, "core", "items", res_id, item_id) or changes_made
	
	# Add references for new resources, nothing happens if they are already present
	for res_id in new_resource_ids:
		changes_made = add_reference(data.items, "core", "items", res_id, item_id) or changes_made
	update_item_skill_references(newdata, olddata)
	
	# Save changes if any modifications were made
	if changes_made:
		save_data_to_file(data.items)
		save_data_to_file(data.wearableslots)
		print_debug("Item changes saved successfully.")
	else:
		print_debug("No changes were made to item.")


# Collects all skills defined in an item and updates the references to that skill
func update_item_skill_references(newdata: Dictionary, olddata: Dictionary):
	var item_id: String = newdata["id"]
	var changes_made = false

	# Function to collect skill IDs from recipes
	var collect_skill_ids: Callable = func (itemdata: Dictionary):
		var skill_ids: Dictionary = {}
		for recipe in itemdata.get("Craft", []):
			var req = Helper.json_helper.get_nested_data(recipe, "skill_requirement.id")
			if req and req != "":
				skill_ids[req] = true
			var prog = Helper.json_helper.get_nested_data(recipe, "skill_progression.id")
			if prog and prog != "":
				skill_ids[prog] = true
		return skill_ids

	# Collect skill IDs from old and new recipes
	var old_skill_ids = collect_skill_ids.call(olddata)
	var new_skill_ids = collect_skill_ids.call(newdata)

	# Check for "Ranged" property and collect skill IDs
	var collect_ranged_skill_id: Callable = func (itemdata: Dictionary, skill_ids: Dictionary):
		if itemdata.has("Ranged") and itemdata["Ranged"].has("used_skill"):
			var skill_id = itemdata["Ranged"]["used_skill"].get("skill_id", "")
			if skill_id != "":
				skill_ids[skill_id] = true
	collect_ranged_skill_id.call(olddata, old_skill_ids)
	collect_ranged_skill_id.call(newdata, new_skill_ids)

	# Check for "Melee" property and collect skill IDs
	var collect_melee_skill_id: Callable = func (itemdata: Dictionary, skill_ids: Dictionary):
		if itemdata.has("Melee") and itemdata["Melee"].has("used_skill"):
			var skill_id = itemdata["Melee"]["used_skill"].get("skill_id", "")
			if skill_id != "":
				skill_ids[skill_id] = true
	collect_melee_skill_id.call(olddata, old_skill_ids)
	collect_melee_skill_id.call(newdata, new_skill_ids)

	# Remove old skill references that are not in the new list
	for old_skill_id in old_skill_ids.keys():
		if not new_skill_ids.has(old_skill_id):
			changes_made = remove_reference(data.skills, "core", "items", old_skill_id, item_id) or changes_made
	
	# Add new skill references
	for new_skill_id in new_skill_ids.keys():
		changes_made = add_reference(data.skills, "core", "items", new_skill_id, item_id) or changes_made
		
	# Save changes if any modifications were made
	if changes_made:
		save_data_to_file(data.skills)
		print_debug("Item skill changes saved successfully.")
	else:
		print_debug("No skill changes were made to item.")


# An item is being deleted from the data
# We have to remove it from everything that references it
func on_item_deleted(item_id: String):
	var changes_made = { "value": false }
	var item_data = get_data_by_id(data.items, item_id)
	if item_data.is_empty():
		print_debug("Item with ID", item_id, "not found.")
		return
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (itemgroup_id):
		var itemlist: Array = get_property_by_path(data.itemgroups, "items", itemgroup_id)
		for i in range(itemlist.size()):
			if itemlist[i].has("id") and itemlist[i]["id"] == item_id:
				itemlist.remove_at(i)
				changes_made["value"] = true
				break  # Exit loop after removal to avoid index issues
	# Pass the callable to every itemgroup in the item's references
	# It will call myfunc on every itemgroup in item_data.references.core.itemgroups
	execute_callable_on_references_of_type(item_data, "core", "itemgroups", myfunc)
	
	# This callable will handle the removal of this item from all crafting recipes in other items
	var remove_from_item: Callable = func(other_item_id: String):
		var other_item_data = get_data_by_id(data.items, other_item_id)
		if other_item_data and other_item_data.has("Craft"):
			for recipe in other_item_data["Craft"]:
				var resources = recipe.get("required_resources", [])
				for i in range(len(resources) - 1, -1, -1):
					if resources[i].get("id") == item_id:
						resources.remove_at(i)
						changes_made["value"] = true

	# Pass the callable to every item in the item's references
	# It will call remove_from_item on every item in item_data.references.core.items
	execute_callable_on_references_of_type(item_data, "core", "items", remove_from_item)
	
	# This callable will handle the removal of this item from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		var quest_data = get_data_by_id(Gamedata.data.quests, quest_id)
		# Removes all steps where the item is equal to item_id
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, \
		"steps.item", item_id) or changes_made["value"]
		# Removes all rewards where the reward's item_id is equal to item_id
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, \
		"rewards.item_id", item_id) or changes_made["value"]

	# Pass the callable to every quest in the item's references
	# It will call remove_from_quest on every item in item_data.references.core.quests
	execute_callable_on_references_of_type(item_data, "core", "quests", remove_from_quest)
	
	# For each recipe and for each item in each recipe, remove the reference to this item
	# Collect unique skill IDs from the item's recipes
	var skill_ids: Dictionary = {}
	if item_data.has("Craft"):
		for recipe in item_data["Craft"]:
			var resources = recipe.get("required_resources", [])
			for resource in resources:
				if resource.has("id"):
					changes_made["value"] = remove_reference(data.items, "core", "items", resource["id"], item_id) or changes_made["value"]
			if recipe.has("skill_requirement"):
				var skill_req_id = recipe["skill_requirement"].get("id", "")
				if skill_req_id != "":
					skill_ids[skill_req_id] = true
			if recipe.has("skill_progression"):
				var skill_prog_id = recipe["skill_progression"].get("id", "")
				if skill_prog_id != "":
					skill_ids[skill_prog_id] = true

	# Add the ranged skill to the skill list
	var ranged_skill_id = Helper.json_helper.get_nested_data(item_data, "Ranged.used_skill.skill_id")
	if ranged_skill_id:
		skill_ids[ranged_skill_id] = true

	# Add the melee skill to the skill list
	var melee_skill_id = Helper.json_helper.get_nested_data(item_data, "Melee.used_skill.skill_id")
	if melee_skill_id:
		skill_ids[melee_skill_id] = true

	# Remove the reference of this item from each skill
	for skill_id in skill_ids.keys():
		changes_made["value"] = remove_reference(data.skills, "core", \
		"items", skill_id, item_id) or changes_made["value"]

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		save_data_to_file(data.itemgroups)
		save_data_to_file(data.items)
		save_data_to_file(data.skills)
		save_data_to_file(data.quests)
	else:
		print_debug("No changes needed for item", item_id)


# A wearableslot is being deleted from the data
# We have to remove it from everything that references it
func on_wearableslot_deleted(wearableslot_id: String):
	var changes_made = false
	var wearableslot_data = get_data_by_id(data.wearableslots, wearableslot_id)
	if wearableslot_data.is_empty():
		print_debug("Item with ID", wearableslot_data, "not found.")
		return
	
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (item_id):
		var item_data: Dictionary = get_data_by_id(data.items, item_id)
		item_data.erase("Wearable")
		changes_made = true
	# Pass the callable to every item in the wearableslot's references
	# It will call myfunc on every item in wearableslot_data.references.core.items
	execute_callable_on_references_of_type(wearableslot_data, "core", "items", myfunc)
	
	# Save changes to the data file if any changes were made
	if changes_made:
		save_data_to_file(data.items)
	else:
		print_debug("No changes needed for item", wearableslot_id)


# A skill is being deleted from the data
# We have to remove it from everything that references it
func on_skill_deleted(skill_id: String):
	var changes_made = { "value": false }  # Using a Dictionary to hold the change status
	var skill_data = get_data_by_id(data.skills, skill_id)

	if skill_data.is_empty():
		print_debug("Skill with ID", skill_id, "not found.")
		return

	# This callable will remove the skill references from items that reference this skill.
	var remove_skill_from_item: Callable = func (item_id):
		var item_data: Dictionary = get_data_by_id(data.items, item_id)
		var recipes = item_data.get("Craft", [])

		# Iterate through the recipes to remove the skill reference
		for recipe in recipes:
			var skill_req = recipe.get("skill_requirement", {})
			var skill_prog = recipe.get("skill_progression", {})

			# Remove skill requirement if it matches the deleted skill
			if skill_req.get("id", "") == skill_id:
				recipe.erase("skill_requirement")
				changes_made["value"] = true

			# Remove skill progression if it matches the deleted skill
			if skill_prog.get("id", "") == skill_id:
				recipe.erase("skill_progression")
				changes_made["value"] = true
		var ranged_skill_id = Helper.json_helper.get_nested_data(item_data, "Ranged.used_skill.skill_id")
		if ranged_skill_id and ranged_skill_id == skill_id:
			changes_made["value"] = Helper.json_helper.delete_nested_property(item_data, "Ranged.used_skill")
		var melee_skill_id = Helper.json_helper.get_nested_data(item_data, "Melee.used_skill.skill_id")
		if melee_skill_id and melee_skill_id == skill_id:
			changes_made["value"] = Helper.json_helper.delete_nested_property(item_data, "Melee.used_skill")

	# Pass the callable to every item in the skill's references
	# It will call myfunc on every item in skill_data.references.core.items
	execute_callable_on_references_of_type(skill_data, "core", "items", remove_skill_from_item)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		save_data_to_file(data.items)
	else:
		print_debug("No changes needed for skill", skill_id)

# Handles quest deletion
func on_quest_deleted(quest_id: String):
	var changes_made = { "value": false }  # Using a Dictionary to hold the change status
	var quest_data = get_data_by_id(data.quests, quest_id)

	if quest_data.is_empty():
		print_debug("quest with ID", quest_id, "not found.")
		return
	var stepitems: Array = Helper.json_helper.get_unique_values(quest_data, "steps.item")
	for item_id in stepitems:
		changes_made["value"] = remove_reference(data.items, "core", "quests", item_id, quest_id) or changes_made["value"]
	var stepmobs: Array = Helper.json_helper.get_unique_values(quest_data, "steps.mob")
	for mob_id in stepmobs:
		changes_made["value"] = remove_reference(data.mobs, "core", "quests", mob_id, quest_id) or changes_made["value"]
	var steprewards: Array = Helper.json_helper.get_unique_values(quest_data, "rewards.item_id")
	for item_id in steprewards: # Remove the reference to this quest from the reward item
		changes_made["value"] = remove_reference(data.items, "core", "quests", item_id, quest_id) or changes_made["value"]

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		save_data_to_file(data.items)
		save_data_to_file(data.mobs)
	else:
		print_debug("No changes needed for quest", quest_id)

# Handles quest changes
func on_quest_changed(newdata: Dictionary, olddata: Dictionary):
	# Get unique values from old and new data for items and rewards
	var old_quest_items: Array = Helper.json_helper.get_unique_values(olddata, "steps.item")
	var new_quest_items: Array = Helper.json_helper.get_unique_values(newdata, "steps.item")
	var old_quest_rewards: Array = Helper.json_helper.get_unique_values(olddata, "rewards.item_id")
	var new_quest_rewards: Array = Helper.json_helper.get_unique_values(newdata, "rewards.item_id")
	var old_quest_mobs: Array = Helper.json_helper.get_unique_values(olddata, "steps.mob")
	var new_quest_mobs: Array = Helper.json_helper.get_unique_values(newdata, "steps.mob")
	
	# Merge items and rewards, removing duplicates
	var old_items_merged = Helper.json_helper.merge_unique(old_quest_items, old_quest_rewards)
	var new_items_merged = Helper.json_helper.merge_unique(new_quest_items, new_quest_rewards)
	var quest_id: String = newdata.get("id", "")
	var changes_made = false

	# Remove references for old items and rewards
	for old_item in old_items_merged:
		if old_item not in new_items_merged:
			changes_made = remove_reference(data.items, "core", "quests", old_item, quest_id) or changes_made

	# Add references for new items and rewards
	for new_item in new_items_merged:
		changes_made = add_reference(data.items, "core", "quests", new_item, quest_id) or changes_made

	# Remove references for old mobs
	for old_mob in old_quest_mobs:
		if old_mob not in new_quest_mobs:
			changes_made = remove_reference(data.mobs, "core", "quests", old_mob, quest_id) or changes_made

	# Add references for new mobs
	for new_mob in new_quest_mobs:
		changes_made = add_reference(data.mobs, "core", "quests", new_mob, quest_id) or changes_made

	# Save changes if any references were updated
	if changes_made:
		save_data_to_file(data.items)
		save_data_to_file(data.mobs)


# map_id is a map json file, like "field_grass_basic_00.json"
func load_map_by_id(map_id: String) -> Dictionary:
	var file_to_load = data.maps.dataPath + map_id
	var mapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(file_to_load)
	return mapdata
