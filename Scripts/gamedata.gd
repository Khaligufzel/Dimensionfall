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

# Dictionary keys for game data categories
const DATA_CATEGORIES = {
	"overmaptiles": {"spritePath": "./Mods/Core/OvermapTiles/"},
	"tacticalmaps": {"dataPath": "./Mods/Core/TacticalMaps/"},
	"wearableslots": {"dataPath": "./Mods/Core/Wearableslots/Wearableslots.json", "spritePath": "./Mods/Core/Wearableslots/"},
	"stats": {"dataPath": "./Mods/Core/Stats/Stats.json", "spritePath": "./Mods/Core/Stats/"},
	"skills": {"dataPath": "./Mods/Core/Skills/Skills.json", "spritePath": "./Mods/Core/Skills/"},
	"quests": {"dataPath": "./Mods/Core/Quests/Quests.json", "spritePath": "./Mods/Core/Items/"}
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
# For example, contentData can be Gamedata.data.skills
# and id can be "plain_grass" and it will return the json data for plain_grass
func get_data_by_id(contentData: Dictionary, id: String) -> Dictionary:
	var idnr: int = get_array_index_by_id(contentData, id)
	if idnr < 0:
		return {}
	return contentData.data[idnr]


# Takes contentData and an id and returns the sprite associated with the id
# For example, contentData can be Gamedata.data.skills
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
	if contentData == data.quests:
		on_quest_changed(newEntityData, oldEntityData)
	save_data_to_file(contentData)


# Adds a reference to an entity
# data = any data group, like Gamedata.data.quests
# type = the type of reference, for example "item"
# onid = where to add the reference to
# refid = The reference to add on the fromid
# Example usage: var changes_made = add_reference(Gamedata.data.quests, "core", 
# "item", quest_id, item_id)
# This example will add the specified item from the quest's references
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
# data = any data group, like Gamedata.data.quests
# type = the type of reference, for example item
# fromid = where to remove the reference from
# refid = The reference to remove from the fromid
# Example usage: var changes_made = remove_reference(Gamedata.data.quests, "core", 
# "item", quest_id, item_id)
# This example will remove the specified item from the quest's references
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
	if contentData == data.tacticalmaps:
		on_tacticalmap_deleted(id)
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


# A wearableslot is being deleted from the data
# We have to remove it from everything that references it
func on_wearableslot_deleted(wearableslot_id: String):
	var changes_made = false
	var wearableslot_data = get_data_by_id(data.wearableslots, wearableslot_id)
	if wearableslot_data.is_empty():
		print_debug("Item with ID", wearableslot_data, "not found.")
		return
	
	# This callable will remove this slot from items that reference this slot.
	var myfunc: Callable = func (item_id):
		var item_data: DItem = items.by_id(item_id)
		item_data.wearable = null
		changes_made = true
	# Pass the callable to every item in the wearableslot's references
	# It will call myfunc on every item in wearableslot_data.references.core.items
	execute_callable_on_references_of_type(wearableslot_data, "core", "items", myfunc)
	
	# Save changes to the data file if any changes were made
	if changes_made:
		items.save_items_to_disk()
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
		var ditem: DItem = items.by_id(item_id)
		changes_made["value"] = ditem.remove_skill(skill_id)

	# Pass the callable to every item in the skill's references
	# It will call myfunc on every item in skill_data.references.core.items
	execute_callable_on_references_of_type(skill_data, "core", "items", remove_skill_from_item)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		items.save_items_to_disk()
	else:
		print_debug("No changes needed for skill", skill_id)

# Handles quest deletion
func on_quest_deleted(quest_id: String):
	var quest_data = get_data_by_id(data.quests, quest_id)

	if quest_data.is_empty():
		print_debug("quest with ID", quest_id, "not found.")
		return
	var stepitems: Array = Helper.json_helper.get_unique_values(quest_data, "steps.item")
	for item_id in stepitems:
		items.remove_reference(item_id, "core", "quests", quest_id)
	var stepmobs: Array = Helper.json_helper.get_unique_values(quest_data, "steps.mob")
	for mob_id in stepmobs:
		mobs.remove_reference(mob_id, "core", "quests", quest_id)
	var steprewards: Array = Helper.json_helper.get_unique_values(quest_data, "rewards.item_id")
	for item_id in steprewards: # Remove the reference to this quest from the reward item
		items.remove_reference(item_id, "core", "quests", quest_id)


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

	# Remove references for old items and rewards
	for old_item in old_items_merged:
		if old_item not in new_items_merged:
			items.remove_reference(old_item, "core", "quests", quest_id)

	# Add references for new items and rewards
	for new_item in new_items_merged:
		items.add_reference(new_item, "core", "quests", quest_id)

	# Remove references for old mobs
	for old_mob in old_quest_mobs:
		if old_mob not in new_quest_mobs:
			mobs.remove_reference(old_mob, "core", "quests", quest_id)

	# Add references for new mobs
	for new_mob in new_quest_mobs:
		mobs.add_reference(new_mob, "core", "quests", quest_id)


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
