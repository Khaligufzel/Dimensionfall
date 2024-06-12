extends Node

#This autoload singleton loads all game data required to run the game
#It can be accessed by using Gamedata.property
var data: Dictionary = {}


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
	"skills": {"dataPath": "./Mods/Core/Skills/Skills.json", "spritePath": "./Mods/Core/Skills/"}
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
	update_item_protoset_json_data("res://ItemProtosets.tres",JSON.stringify(data.items.data,"\t"))
	data.maps.data = Helper.json_helper.file_names_in_dir(data.maps.dataPath, ["json"])
	data.tacticalmaps.data = Helper.json_helper.file_names_in_dir(\
	data.tacticalmaps.dataPath, ["json"])


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


#This loads all the sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	for dict in data.keys():
		if data[dict].has("spritePath"):
			var loaded_sprites: Dictionary = {} # Materials used to represent mobs
			var spritesDir: String = data[dict].spritePath
			var png_files: Array = Helper.json_helper.file_names_in_dir(spritesDir, ["png"])
			for png_file in png_files:
				# Load the .png file as a texture
				var texture := load(spritesDir + png_file) 
				# Add the material to the dictionary
				loaded_sprites[png_file] = texture
			data[dict].sprites = loaded_sprites


# Updated function to add a sprite to a specific dictionary
func add_sprite_to_dictionary(contentData: Dictionary, file_name: String, texture: Texture):
	if texture:
		contentData.sprites[file_name] = texture
		Helper.signal_broker.data_sprites_changed.emit(contentData, file_name)
		print("Sprite added:", file_name)
	else:
		print("Failed to add sprite:", file_name)


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
		Helper.json_helper.write_json_file(contentData.dataPath,JSON.stringify(contentData.data,"\t"))
		on_data_changed(contentData,item_to_duplicate,{})
	else:
		print_debug("There should be code here for when a file in the gets duplicated")


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
	var save_result = Helper.json_helper.write_json_file(new_file_path, JSON.stringify(orig_content,"\t"))
	if save_result == OK:
		print_debug("File duplicated successfully: " + new_file_path)
		# Add the new ID to the data array if it's datapath references a folder.
		var datapath: String = contentData.dataPath
		if contentData.data is Array and datapath.ends_with("/"):
			contentData.data.append(new_id + ".json")
			if datapath.ends_with("/Maps/"): # Update references to this duplicated map
				on_mapdata_changed(new_file_path,orig_content,{"levels":[]})
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
	if !contentData.has("data"):
		return
	if contentData.dataPath.ends_with(".json"):
		if get_array_index_by_id(contentData,id) != -1:
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


func save_data_to_file(contentData: Dictionary):
	var datapath: String = contentData.dataPath
	if datapath.ends_with(".json"):
		Helper.json_helper.write_json_file(datapath,JSON.stringify(contentData.data,"\t"))


# Takes contentdata and an id and returns the json that belongs to an id
# For example, contentData can be Gamedata.data.tiles
# and id can be "plain_grass" and it will return the json data for plain_grass
func get_data_by_id(contentData: Dictionary, id: String) -> Dictionary:
	var idnr: int = get_array_index_by_id(contentData,id)
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


# This functino is called when an editor has changed data
# The contenteditor (that initializes the individual editors)
# connects the changed_data signal to this function
# and binds the appropriate data array so it can be saved in this function
func on_data_changed(contentData: Dictionary, newEntityData: Dictionary, oldEntityData: Dictionary):
	if contentData == Gamedata.data.itemgroups:
		on_itemgroup_changed(newEntityData, oldEntityData)
	if contentData == Gamedata.data.mobs:
		on_mob_changed(newEntityData, oldEntityData)
	if contentData == Gamedata.data.furniture:
		on_furniture_changed(newEntityData, oldEntityData)
	if contentData == Gamedata.data.items:
		on_item_changed(newEntityData, oldEntityData)
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


# Function to filter items by type
func get_items_by_type(item_type: String) -> Array:
	var filtered_items = []
	
	# Check if the items data exists and is an array
	if Gamedata.data.has("items") and Gamedata.data.items.has("data") and typeof(Gamedata.data.items.data) == TYPE_ARRAY:
		# Iterate through each item in the items data
		for item in Gamedata.data.items.data:
			# Check if the item is a dictionary and has the specified type
			if item is Dictionary and item.has(item_type):
				# Add the item to the filtered items list
				filtered_items.append(item)

	return filtered_items


# An itemgroup has been changed. Update items that were added or removed from the list.
# olddata and newdata are dictionaries that include "items" keys pointing to arrays of dictionaries.
func on_itemgroup_changed(newdata: Dictionary, olddata: Dictionary):
	var changes_made = false
	# Initialize empty arrays
	var oldlist = []
	var newlist = []

	# Fill oldlist with IDs from olddata
	for item in olddata.get("items", []):
		oldlist.append(item["id"])

	# Fill newlist with IDs from newdata
	for item in newdata.get("items", []):
		newlist.append(item["id"])

	var itemgroup: String = newdata.id
	# Remove itemgroup from items in the old list that are not in the new list
	if oldlist:
		for item_id in oldlist:
			if item_id not in newlist:
				# Call remove_reference to remove the itemgroup from this item
				changes_made = remove_reference(Gamedata.data.items, "core", "itemgroups", \
				item_id, itemgroup) or changes_made

	# Add itemgroup to items in the new list that were not in the old list
	if newlist:
		for item_id in newlist:
			if item_id not in oldlist:
				# Call add_reference to add the itemgroup to this item
				changes_made = add_reference(Gamedata.data.items, "core", "itemgroups", \
				item_id, itemgroup) or changes_made

	# Save changes if any items were updated
	if changes_made:
		save_data_to_file(Gamedata.data.items)


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
					# Clean up if necessary
					if refs.size() == 0:
						entitydata["references"][module].erase(type)
					if entitydata["references"][module].is_empty():
						entitydata["references"].erase(module)
					if entitydata["references"].is_empty():
						entitydata.erase("references")

	return changes_made


# Some kind of entity is deleted. We will remove all references to this entity
func remove_references_of_deleted_id(contentData: Dictionary, id: String):
	if contentData == Gamedata.data.itemgroups:
		on_itemgroup_deleted(id)
	if contentData == Gamedata.data.items:
		on_item_deleted(id)
	if contentData == Gamedata.data.furniture:
		on_furniture_deleted(id)
	if contentData == Gamedata.data.maps:
		on_map_deleted(id)
	if contentData == Gamedata.data.tacticalmaps:
		on_tacticalmap_deleted(id)
	if contentData == Gamedata.data.mobs:
		on_mob_deleted(id)
	if contentData == Gamedata.data.tiles:
		on_tile_deleted(id)
	if contentData == Gamedata.data.skills:
		on_skill_deleted(id)
	if contentData == Gamedata.data.wearableslots:
		on_wearableslot_deleted(id)


# Erases a nested property from a given dictionary based on a dot-separated path
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


# Retrieves the value of a nested property from a given dictionary based on a dot-separated path
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
	changes_made = remove_reference(Gamedata.data.itemgroups, "core", "mobs", \
	old_loot_group, mob_id) or changes_made

	# This furniture will be added to the new itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	changes_made = add_reference(Gamedata.data.itemgroups, "core", "mobs", \
	new_loot_group, mob_id) or changes_made
	
	# Save changes if any modifications were made
	if changes_made:
		if old_loot_group != "":
			save_data_to_file(Gamedata.data.itemgroups)
		if new_loot_group != "" and new_loot_group != old_loot_group:
			save_data_to_file(Gamedata.data.itemgroups)


# Handles changes to furniture and updates relevant references if necessary.
# Handles changes to furniture and updates relevant references if necessary.
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
	changes_made = update_group_reference(old_container_group, new_container_group, furniture_id, "furniture") or changes_made

	# Handle destruction group changes
	changes_made = update_group_reference(old_destruction_group, new_destruction_group, furniture_id, "furniture") or changes_made

	# Handle disassembly group changes
	changes_made = update_group_reference(old_disassembly_group, new_disassembly_group, furniture_id, "furniture") or changes_made

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Furniture reference updates saved successfully.")
		save_data_to_file(Gamedata.data.itemgroups)


# Helper function to update group references if they have changed.
func update_group_reference(old_group: String, new_group: String, entity_id: String, group_type: String) -> bool:
	if old_group == new_group:
		return false  # No change detected, exit early

	var changes_made = false

	# Remove from old group if necessary
	if old_group != "":
		changes_made = remove_reference(Gamedata.data.itemgroups, "core", group_type, old_group, entity_id) or changes_made

	# Add to new group if necessary
	if new_group != "":
		changes_made = add_reference(Gamedata.data.itemgroups, "core", group_type, new_group, entity_id) or changes_made

	return changes_made


# Some furniture is being deleted from the data
# We have to remove it from everything that references it
func on_furniture_deleted(furniture_id: String):
	var changes_made = false
	var furniture_data = get_data_by_id(Gamedata.data.furniture, furniture_id)

	if furniture_data.is_empty():
		print_debug("Item with ID", furniture_data, "not found.")
		return

	var itemgroup: String = get_property_by_path(Gamedata.data.furniture, "Function.container.itemgroup", furniture_id)
	changes_made = remove_reference(Gamedata.data.itemgroups, "core", "furniture", itemgroup, furniture_id) or changes_made

	var destruction_group: String = ""
	if furniture_data.has("destruction") and furniture_data["destruction"].has("group"):
		destruction_group = furniture_data["destruction"]["group"]
	changes_made = remove_reference(Gamedata.data.itemgroups, "core", "furniture", destruction_group, furniture_id) or changes_made

	var disassembly_group: String = ""
	if furniture_data.has("disassembly") and furniture_data["disassembly"].has("group"):
		disassembly_group = furniture_data["disassembly"]["group"]
	changes_made = remove_reference(Gamedata.data.itemgroups, "core", "furniture", disassembly_group, furniture_id) or changes_made

	var maps = Helper.json_helper.get_nested_data(furniture_data, "references.core.maps")
	for map_id in maps:
		remove_entity_from_map(map_id, "furniture", furniture_id)

	if changes_made:
		save_data_to_file(Gamedata.data.itemgroups)
	else:
		print_debug("No changes needed for item", furniture_id)

# Some mob is being deleted from the data
# We have to remove it from everything that references it
func on_mob_deleted(mob_id: String):
	var changes_made = false
	var mob_data = get_data_by_id(Gamedata.data.mobs, mob_id)
	if mob_data.is_empty():
		print_debug("Item with ID", mob_data, "not found.")
		return

	# Remove the reference to this mob from the loot_group
	var loot_group: String = mob_data.get("loot_group")
	changes_made = remove_reference(Gamedata.data.itemgroups, "core", "mobs", \
	loot_group, mob_id) or changes_made
	
	# Check if the mob has references to maps and remove it from those maps
	var maps = Helper.json_helper.get_nested_data(mob_data,"references.core.maps")
	for map_id in maps:
		remove_entity_from_map(map_id, "mob", mob_id)

	# Save changes to the data file if any changes were made
	if changes_made:
		save_data_to_file(Gamedata.data.itemgroups)
	else:
		print_debug("No changes needed for item", mob_id)


# Some mob is being deleted from the data
# We have to remove it from everything that references it
func on_tile_deleted(tile_id: String):
	var tile_data = get_data_by_id(Gamedata.data.tiles, tile_id)
	if tile_data.is_empty():
		print_debug("Item with ID", tile_data, "not found.")
		return

	# Check if the tile has references to maps and remove it from those maps
	var modules = tile_data.get("references", [])
	for mod in modules:
		var maps = Helper.json_helper.get_nested_data(tile_data,"references."+mod+".maps")
		for map_id in maps:
			remove_entity_from_map(map_id, "tile", tile_id)


# An itemgroup is being deleted from the data
# We have to loop over all the items in the itemgroup
# We can get the items by calling get_data_by_id(contentData, id) 
# and getting the items property, which will return an array of item id's
# For each item, we have to get the item's data, and delete the itemgroup from the item's itemgroups property if it is present
func on_itemgroup_deleted(itemgroup_id: String):
	var changes_made = false
	var itemgroup_data = get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)

	if itemgroup_data.is_empty():
		print_debug("Itemgroup with ID", itemgroup_id, "not found.")
		return

	# This callable will remove this itemgroup from every furniture that references this itemgroup.
	var myfunc: Callable = func (furn_id):
		var furniture_data = Gamedata.get_data_by_id(Gamedata.data.furniture, furn_id)
		var container_group = furniture_data.get("Function", {}).get("container", {}).get("itemgroup", "")
		var disassembly_group = furniture_data.get("disassembly", {}).get("group", "")
		var destruction_group = furniture_data.get("destruction", {}).get("group", "")

		if container_group == itemgroup_id:
			if erase_property_by_path(Gamedata.data.furniture, furn_id, "Function.container.itemgroup"):
				changes_made = true

		if disassembly_group == itemgroup_id:
			if erase_property_by_path(Gamedata.data.furniture, furn_id, "disassembly.group"):
				changes_made = true

		if destruction_group == itemgroup_id:
			if erase_property_by_path(Gamedata.data.furniture, furn_id, "destruction.group"):
				changes_made = true

	# Pass the callable to every furniture in the itemgroup's references
	# It will call myfunc on every furniture in itemgroup_data.references.core.furniture
	execute_callable_on_references_of_type(itemgroup_data, "core", "furniture", myfunc)

	# The itemgroup data contains a list of item IDs in an 'items' attribute
	# Loop over all the items in the list and remove the reference to this itemgroup
	if "items" in itemgroup_data:
		var items = itemgroup_data["items"]
		for item in items:
			# Use remove_reference to handle deletion of itemgroup references
			changes_made = remove_reference(Gamedata.data.items, "core", "itemgroups", \
			item.id, itemgroup_id) or changes_made

	# Save changes to the data file if any changes were made
	if changes_made:
		save_data_to_file(Gamedata.data.items)
		save_data_to_file(Gamedata.data.furniture)
		print_debug("Itemgroup", itemgroup_id, "has been successfully deleted from all items.")
	else:
		print_debug("No changes needed for itemgroup", itemgroup_id)


# A map is being deleted. Remove all references to this map
func on_map_deleted(map_id: String):
	var changes_made = false
	var fileToLoad = Gamedata.data.maps.dataPath + map_id + ".json"
	var mapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(fileToLoad)
	if not mapdata.has("levels"):
		print("Map data does not contain 'levels'.")
		return

	# This callable will remove this map from every tacticalmap that references this itemgroup.
	var myfunc: Callable = func (tmap_id):
		var tfile = Gamedata.data.tacticalmaps.dataPath + tmap_id
		var tmapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(tfile)
		# Check if the "chunks" key exists and is an array
		if tmapdata.has("chunks") and tmapdata["chunks"] is Array:
			# Iterate through the chunks array
			for i in range(tmapdata["chunks"].size()):
				var chunk = tmapdata["chunks"][i]
				# If the chunk has the target id, remove it from the array
				if chunk.has("id") and chunk["id"] == map_id + ".json":
					tmapdata["chunks"].remove_at(i)
			var map_data_json = JSON.stringify(tmapdata.duplicate(), "\t")
			Helper.json_helper.write_json_file(tfile, map_data_json)
	
	# Pass the callable to every furniture in the itemgroup's references
	# It will call myfunc on every furniture in itemgroup_data.references.core.furniture
	execute_callable_on_references_of_type(mapdata, "core", "tacticalmaps", myfunc)
	
	for level_index in range(mapdata["levels"].size()):
		var old_level = mapdata["levels"][level_index] if mapdata["levels"].size() > level_index else []
			# Entire level was removed
		for old_entity in old_level:
			if old_entity.has("mob"):
				changes_made = remove_reference(Gamedata.data.mobs, "core", "maps", \
				old_entity["mob"]["id"], map_id) or changes_made
			if old_entity.has("furniture"):
				changes_made = remove_reference(Gamedata.data.furniture, "core", "maps", \
				old_entity["furniture"]["id"], map_id) or changes_made
			if old_entity.has("id"):
				changes_made = remove_reference(Gamedata.data.tiles, "core", "maps", \
				old_entity["id"], map_id) or changes_made

	if changes_made:
		# References have been added to tiles, furniture and/or mobs
		# We could track changes individually so we only save what has actually changed.
		save_data_to_file(Gamedata.data.tiles)
		save_data_to_file(Gamedata.data.furniture)
		save_data_to_file(Gamedata.data.mobs)


# A map is being deleted. Remove all references to this map
func on_tacticalmap_deleted(tacticalmap_id: String):
	var file = Gamedata.data.tacticalmaps.dataPath + tacticalmap_id + ".json"
	var tacticalmapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(file)
	if not tacticalmapdata.has("chunks"):
		print("Tacticalmap data does not contain 'chunks'.")
		return

	for i in range(tacticalmapdata["chunks"].size()):
		var chunk = tacticalmapdata["chunks"][i]
		# If the chunk has the target id, remove the reference from the map
		if chunk.has("id"):
			var chunkid = chunk["id"]
			remove_reference(Gamedata.data.maps, "core", "tacticalmaps", \
				chunk["id"], tacticalmap_id + ".json")


# Function to collect unique entities from each level in newdata and olddata
func collect_unique_entities(newdata: Dictionary, olddata: Dictionary) -> Dictionary:
	var new_entities = {
		"mobs": [],
		"furniture": [],
		"tiles": []
	}
	var old_entities = {
		"mobs": [],
		"furniture": [],
		"tiles": []
	}

	# Collect entities from newdata
	for level in newdata.get("levels", []):
		add_entities_to_set(level, new_entities)

	# Collect entities from olddata
	for level in olddata.get("levels", []):
		add_entities_to_set(level, old_entities)
	
	return {"new_entities": new_entities, "old_entities": old_entities}


# Helper function to add entities to the respective sets
func add_entities_to_set(level: Array, entity_set: Dictionary):
	for entity in level:
		if entity.has("mob") and not entity_set["mobs"].has(entity["mob"]["id"]):
			entity_set["mobs"].append(entity["mob"]["id"])
		if entity.has("furniture") and not entity_set["furniture"].has(entity["furniture"]["id"]):
			entity_set["furniture"].append(entity["furniture"]["id"])
		if entity.has("id") and not entity_set["tiles"].has(entity["id"]):
			entity_set["tiles"].append(entity["id"])


# Function to update map entity references when a map's data changes
func on_mapdata_changed(map_id: String, newdata: Dictionary, olddata: Dictionary):
	# Collect unique entities from both new and old data
	var entities = collect_unique_entities(newdata, olddata)
	var new_entities = entities["new_entities"]
	var old_entities = entities["old_entities"]
	map_id = map_id.get_file().replace(".json", "")

	# Add references for new entities
	for entity_type in new_entities.keys():
		for entity_id in new_entities[entity_type]:
			if not old_entities[entity_type].has(entity_id):
				add_reference(Gamedata.data[entity_type], "core", "maps", entity_id, map_id)

	# Remove references for entities not present in new data
	for entity_type in old_entities.keys():
		for entity_id in old_entities[entity_type]:
			if not new_entities[entity_type].has(entity_id):
				remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, map_id)

	# Save changes to the data files if there were any updates
	if new_entities["mobs"].size() > 0 or old_entities["mobs"].size() > 0:
		save_data_to_file(Gamedata.data.mobs)
	if new_entities["furniture"].size() > 0 or old_entities["furniture"].size() > 0:
		save_data_to_file(Gamedata.data.furniture)
	if new_entities["tiles"].size() > 0 or old_entities["tiles"].size() > 0:
		save_data_to_file(Gamedata.data.tiles)


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
		add_reference(Gamedata.data.maps, "core", "tacticalmaps", id, tacticalmap_id)

	# Remove references for IDs not present in new data
	for id in unique_old_ids:
		if id not in unique_new_ids:
			remove_reference(Gamedata.data.maps, "core", "tacticalmaps", id, tacticalmap_id)


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
		changes_made = add_reference(Gamedata.data.wearableslots, "core", "items", new_slot, item_id) or changes_made
	
	if old_slot and old_slot != new_slot:
		# Remove the reference from the old slot if it has been changed or removed
		changes_made = remove_reference(Gamedata.data.wearableslots, "core", "items", old_slot, item_id) or changes_made

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
			changes_made = remove_reference(Gamedata.data.items, "core", "items", res_id, item_id) or changes_made

	# Add references for new resources, nothing happens if they are already present
	for res_id in new_resource_ids:
		changes_made = add_reference(Gamedata.data.items, "core", "items", res_id, item_id) or changes_made


	# Collect unique skill IDs from old and new recipes
	var old_skill_ids: Dictionary = {}
	var new_skill_ids: Dictionary = {}

	# Collect skill IDs from old recipes
	for recipe in olddata.get("Craft", []):
		if recipe.has("skill_requirement"):
			var old_skill_req_id = recipe["skill_requirement"].get("id", "")
			if old_skill_req_id != "":
				old_skill_ids[old_skill_req_id] = true
		if recipe.has("skill_progression"):
			var old_skill_prog_id = recipe["skill_progression"].get("id", "")
			if old_skill_prog_id != "":
				old_skill_ids[old_skill_prog_id] = true

	# Collect skill IDs from new recipes
	for recipe in newdata.get("Craft", []):
		if recipe.has("skill_requirement"):
			var new_skill_req_id = recipe["skill_requirement"].get("id", "")
			if new_skill_req_id != "":
				new_skill_ids[new_skill_req_id] = true
		if recipe.has("skill_progression"):
			var new_skill_prog_id = recipe["skill_progression"].get("id", "")
			if new_skill_prog_id != "":
				new_skill_ids[new_skill_prog_id] = true

	# Remove old skill references that are not in the new list
	for old_skill_id in old_skill_ids.keys():
		if not new_skill_ids.has(old_skill_id):
			changes_made = remove_reference(Gamedata.data.skills, "core", "items", old_skill_id, item_id) or changes_made

	# Add new skill references
	for new_skill_id in new_skill_ids.keys():
		changes_made = add_reference(Gamedata.data.skills, "core", "items", new_skill_id, item_id) or changes_made

	# Save changes if any modifications were made
	if changes_made:
		save_data_to_file(Gamedata.data.items)
		save_data_to_file(Gamedata.data.wearableslots)
		save_data_to_file(Gamedata.data.skills)
		print_debug("Item changes saved successfully.")
	else:
		print_debug("No changes were made to item.")

# An item is being deleted from the data
# We have to remove it from everything that references it
func on_item_deleted(item_id: String):
	var changes_made = false
	var item_data = get_data_by_id(Gamedata.data.items, item_id)
	
	if item_data.is_empty():
		print_debug("Item with ID", item_id, "not found.")
		return
	
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (itemgroup_id):
		var itemlist: Array = get_property_by_path(Gamedata.data.itemgroups, "items", itemgroup_id)
		for i in range(itemlist.size()):
			if itemlist[i].has("id") and itemlist[i]["id"] == item_id:
				itemlist.remove_at(i)
				changes_made = true
				break  # Exit loop after removal to avoid index issues
	# Pass the callable to every itemgroup in the item's references
	# It will call myfunc on every itemgroup in item_data.references.core.itemgroups
	execute_callable_on_references_of_type(item_data, "core", "itemgroups", myfunc)
	
	# This callable will handle the removal of this item from all crafting recipes in other items
	var remove_from_item: Callable = func(other_item_id: String):
		var other_item_data = get_data_by_id(Gamedata.data.items, other_item_id)
		if other_item_data and other_item_data.has("Craft"):
			for recipe in other_item_data["Craft"]:
				var resources = recipe.get("required_resources", [])
				for i in range(len(resources) - 1, -1, -1):
					if resources[i].get("id") == item_id:
						resources.remove_at(i)
						changes_made = true

	# Pass the callable to every item in the item's references
	# It will call remove_from_item on every item in item_data.references.core.items
	execute_callable_on_references_of_type(item_data, "core", "items", remove_from_item)
	
	# For each recipe and for each item in each recipe, remove the reference to this item
	# Collect unique skill IDs from the item's recipes
	var skill_ids: Dictionary = {}

	if item_data.has("Craft"):
		for recipe in item_data["Craft"]:
			var resources = recipe.get("required_resources", [])
			for resource in resources:
				if resource.has("id"):
					changes_made = remove_reference(Gamedata.data.items, "core", \
					"items", resource["id"], item_id) or changes_made
			if recipe.has("skill_requirement"):
				var skill_req_id = recipe["skill_requirement"].get("id", "")
				if skill_req_id != "":
					skill_ids[skill_req_id] = true
			if recipe.has("skill_progression"):
				var skill_prog_id = recipe["skill_progression"].get("id", "")
				if skill_prog_id != "":
					skill_ids[skill_prog_id] = true

	# Remove the reference of this item from each skill
	for skill_id in skill_ids.keys():
		changes_made = remove_reference(Gamedata.data.skills, "core", "items", skill_id, item_id) or changes_made

	# Save changes to the data file if any changes were made
	if changes_made:
		save_data_to_file(Gamedata.data.itemgroups)
		save_data_to_file(Gamedata.data.items)
		save_data_to_file(Gamedata.data.skills)
	else:
		print_debug("No changes needed for item", item_id)



# A wearableslot is being deleted from the data
# We have to remove it from everything that references it
func on_wearableslot_deleted(wearableslot_id: String):
	var changes_made = false
	var wearableslot_data = get_data_by_id(Gamedata.data.wearableslots, wearableslot_id)
	
	if wearableslot_data.is_empty():
		print_debug("Item with ID", wearableslot_data, "not found.")
		return
	
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (item_id):
		var item_data: Dictionary = get_data_by_id(Gamedata.data.items, item_id)
		item_data.erase("Wearable")
		changes_made = true
	# Pass the callable to every item in the wearableslot's references
	# It will call myfunc on every item in wearableslot_data.references.core.items
	execute_callable_on_references_of_type(wearableslot_data, "core", "items", myfunc)
	
	# Save changes to the data file if any changes were made
	if changes_made:
		save_data_to_file(Gamedata.data.items)
	else:
		print_debug("No changes needed for item", wearableslot_id)


# Removes all instances of the provided entity from the provided map
# map_id is the id of one of the maps. It will be loaded from json to manipulate it.
# entity_type can be "tile", "furniture" or "mob"
# entity_id is the id of the tile, furniture or mob
func remove_entity_from_map(map_id: String, entity_type: String, entity_id: String) -> void:
	var fileToLoad = Gamedata.data.maps.dataPath + map_id + ".json"
	var mapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(fileToLoad)
	if not mapdata.has("levels"):
		print("Map data does not contain 'levels'.")
		return

	var levels = mapdata["levels"]
	# Translate the type to the actual key that we need
	if entity_type == "tile":
		entity_type = "id"

	# Iterate over each level in the map
	for level_index in range(levels.size()):
		var level = levels[level_index]

		# Iterate through each entity in the level
		for entity_index in range(level.size()):
			var entity = level[entity_index]

			match entity_type:
				"id":
					# Check if the entity's 'id' matches and replace the entire 
					# entity with an empty object
					if entity.get("id", "") == entity_id:
						level[entity_index] = {}  # Replacing entity with an empty object
				"furniture":
					# Check if the entity has 'furniture' and the 'id' within it matches
					if entity.has("furniture") and entity["furniture"].get("id", "") == entity_id:
						entity.erase("furniture")  # Removing the furniture object from the entity
				"mob":
					# Check if the entity has 'mob' and the 'id' within it matches
					if entity.has("mob") and entity["mob"].get("id", "") == entity_id:
						entity.erase("mob")  # Removing the mob object from the entity

		# Update the level in the mapdata after modifications
		levels[level_index] = level

	# Update the mapdata levels after processing all
	mapdata["levels"] = levels
	print_debug("Entity removal operations completed for all levels.")
	var map_data_json = JSON.stringify(mapdata.duplicate(), "\t")
	Helper.json_helper.write_json_file(fileToLoad, map_data_json)

# A skill is being deleted from the data
# We have to remove it from everything that references it
func on_skill_deleted(skill_id: String):
	var changes_made = { "value": false }  # Using a Dictionary to hold the change status
	var skill_data = get_data_by_id(Gamedata.data.skills, skill_id)

	if skill_data.is_empty():
		print_debug("Skill with ID", skill_id, "not found.")
		return

	# This callable will remove the skill references from items that reference this skill.
	var myfunc: Callable = func (item_id):
		var item_data: Dictionary = get_data_by_id(Gamedata.data.items, item_id)
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

	# Pass the callable to every item in the skill's references
	# It will call myfunc on every item in skill_data.references.core.items
	execute_callable_on_references_of_type(skill_data, "core", "items", myfunc)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		save_data_to_file(Gamedata.data.items)
	else:
		print_debug("No changes needed for skill", skill_id)
