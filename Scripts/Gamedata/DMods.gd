class_name DMods
extends RefCounted

# This script handles the list of mods. You can access it through Gamedata.mods

# All loaded mods
var mod_dict: Dictionary = {}

# Constructor
# Initialize with a mod_id to dynamically set the dataPath
func _init() -> void:
	load_mods_from_disk()


### ------------------------- Loading Mods --------------------------

# Loads all mods from the `./Mods` directory and populates `mod_dict`
func load_mods_from_disk() -> void:
	mod_dict.clear()
	var mod_states: Dictionary = _get_mod_states_as_dict()
	var folders: Array = Helper.json_helper.folder_names_in_dir("./Mods")

	for folder_name: String in folders:
		var modinfo_path = "./Mods/" + folder_name + "/modinfo.json"
		if FileAccess.file_exists(modinfo_path):
			_load_mod_from_folder(modinfo_path, mod_states)
		else:
			print_debug("No modinfo.json found in folder: " + folder_name)

# Converts the mod states list into a dictionary for quick lookup
func _get_mod_states_as_dict() -> Dictionary:
	var enabled_states: Dictionary = {}
	for state in get_mod_list_states():
		enabled_states[state["id"]] = state["enabled"]
	return enabled_states

# Loads a single mod from a folder, validating its modinfo file
func _load_mod_from_folder(modinfo_path: String, enabled_states: Dictionary) -> void:
	var modinfo = Helper.json_helper.load_json_dictionary_file(modinfo_path)
	if modinfo.has("id"):
		var mod_id: String = modinfo["id"]
		var mod: DMod = DMod.new(modinfo, self)
		mod.is_enabled = enabled_states.get(mod_id, true)  # Default to enabled
		mod_dict[mod_id] = mod
	else:
		print_debug("Invalid modinfo.json in path: " + modinfo_path)


# Returns the dictionary containing all mods
func get_all() -> Dictionary:
	return mod_dict

### ----------------------- Mod State Management -----------------------

# Adds a new mod and writes it to `user://mods_state.cfg` as enabled
func add_new(new_id: String, mod_info: Dictionary) -> void:
	mod_info["id"] = new_id
	var new_mod = DMod.new(mod_info, self)
	mod_dict[new_mod.id] = new_mod
	_write_mod_to_state_file(new_id, true)

# Writes a new mod to `user://mods_state.cfg` with its enabled state
func _write_mod_to_state_file(mod_id: String, is_enabled: bool) -> void:
	var config_path = "user://mods_state.cfg"
	var config = ConfigFile.new()
	var mod_states = []

	if FileAccess.file_exists(config_path) and config.load(config_path) == OK:
		mod_states = config.get_value("mods", "states", [])
	else:
		print_debug("Creating new mods_state.cfg file.")

	mod_states.append({"id": mod_id, "enabled": is_enabled})
	config.set_value("mods", "states", mod_states)

	if config.save(config_path) != OK:
		print_debug("Failed to save updated mod states to mods_state.cfg.")
	else:
		print_debug("New mod added to mods_state.cfg: ", mod_id)


# Deletes a mod by its ID and removes it from the `user://mods_state.cfg` file
func delete_by_id(mod_id: String) -> void:
	# Remove the mod from the dictionary
	mod_dict.erase(mod_id)

	# Load the existing mod states
	var config_path = "user://mods_state.cfg"
	var config = ConfigFile.new()
	var mod_states: Array = []

	if FileAccess.file_exists(config_path) and config.load(config_path) == OK:
		mod_states = config.get_value("mods", "states", [])
	else:
		print_debug("Could not load mods_state.cfg for deletion.")
		return

	# Filter out the mod being deleted from the mod states
	mod_states = mod_states.filter(func(mod_state): return mod_state["id"] != mod_id)

	# Save the updated mod states back to the file
	config.set_value("mods", "states", mod_states)
	if config.save(config_path) != OK:
		print_debug("Failed to save updated mod states to mods_state.cfg after deleting mod: ", mod_id)
	else:
		print_debug("Mod successfully deleted from mods_state.cfg: ", mod_id)


# Returns a mod by its ID
func by_id(modid: String) -> DMod:
	return mod_dict.get(modid, null)

# Checks if a mod exists by its ID
func has_id(modid: String) -> bool:
	return mod_dict.has(modid)

# Function to retrieve content by its type and ID across all mods
# The returned value may be a DMap, DItem, DMobgroup or anything
# contentType: A DMod.ContentType
func get_content_by_id(contentType: DMod.ContentType, id: String) -> RefCounted:
	# Loop over all mods in the mod_dict
	for mod: DMod in mod_dict.values():
		# Get the content instance of the specified type for the current mod
		var content_instance: RefCounted = mod.get_data_of_type(contentType)
		if content_instance:
			# Check if the content instance has the requested ID
			if content_instance.has_id(id):
				# Return the matching content
				return content_instance.by_id(id)
	# If no matching content is found, return null
	return null


# Function to retrieve all content instances with a specific ID across all mods
# The returned value may be an array of DMap, DItem, DMobgroup or anything
# If more then one is returned, that means that this id is contained within more then one mod
# We will expect two of them to be duplicates of eachother.
func get_all_content_by_id(contentType: DMod.ContentType, id: String) -> Array[RefCounted]:
	var results: Array[RefCounted] = []
	
	# Loop over all mods in the mod_dict
	for mod in mod_dict.values():
		# Get the content instance of the specified type for the current mod
		var content_instance: RefCounted = mod.get_data_of_type(contentType)
		if content_instance:
			# Check if the content instance has the requested ID
			if content_instance.has_id(id):
				# Append the matching content to the results array
				results.append(content_instance.by_id(id))
	
	# Return the array of matching content instances
	return results


# Function to add a reference to all content instances with a specific ID across all mods
# contentType: The type of entity that we add the reference to
# id: The id of the entity that we add the reference to
# ref_type: The type of the entity that we reference
# ref_id: The id of the entity that we reference
# Example references data:
#	"references": {
#		"field_grass_basic_00": {
#			"overmapareas": [
#				"city"
#			],
#			"tacticalmaps": [
#				"rockyhill"
#			]
#		}
#	}
func add_reference(contentType: DMod.ContentType, id: String, ref_type: DMod.ContentType, ref_id: String) -> void:
	# Loop over all mods in the mod_dict
	for mod: DMod in mod_dict.values():
		# Get the content instance of the specified type for the current mod
		var content_instance: RefCounted = mod.get_data_of_type(contentType)
		if content_instance:
			# Check if the content instance has the requested ID
			if content_instance.has_id(id):
				add_reference_to_content_instance(content_instance, id, ref_type, ref_id)


# Function to remove a reference from all content instances with a specific ID across all mods
# contentType: The type of entity that we remove the reference from
# id: The id of the entity that we remove the reference from
# ref_type: The type of the entity that we remove as a reference
# ref_id: The id of the entity that we remove as a reference
func remove_reference(contentType: DMod.ContentType, id: String, ref_type: DMod.ContentType, ref_id: String) -> void:
	# Loop over all mods in the mod_dict
	for mod: DMod in mod_dict.values():
		# Get the content instance of the specified type for the current mod
		var content_instance: RefCounted = mod.get_data_of_type(contentType)
		if content_instance:
			# Check if the content instance has the requested ID
			if content_instance.has_id(id):
				remove_reference_from_content_instance(content_instance, id, ref_type, ref_id)


# Add a reference to the references dictionary
# content_instance: A RefCounted containing intities, for example DTiles, DMaps, DMobgroups
func add_reference_to_content_instance(content_instance: RefCounted, id: String, type: DMod.ContentType, refid: String) -> void:
	if not content_instance.has_id(id):
		print_debug("Cannot add reference: ID '" + id + "' does not exist.")
		return
	
	var mytype: String = DMod.get_content_type_string(type) # Example: "mobgroups" or "tiles"
	var myreferences: Dictionary = content_instance.references
	if not myreferences.has(id):
		myreferences[id] = {}
	if not myreferences[id].has(mytype):
		myreferences[id][mytype] = []
	if not refid in myreferences[id][mytype]:
		myreferences[id][mytype].append(refid)
		save_references(content_instance)


# Remove a reference from the references dictionary
func remove_reference_from_content_instance(content_instance: RefCounted, id: String, type: DMod.ContentType, refid: String) -> void:
	var mytype: String = DMod.get_content_type_string(type)
	var myreferences: Dictionary = content_instance.references
	if myreferences.has(id) and myreferences[id].has(mytype):
		myreferences[id][mytype].erase(refid)
		# Clean up empty entries
		if myreferences[id][mytype].is_empty():
			myreferences[id].erase(mytype)
		if myreferences[id].is_empty():
			myreferences.erase(id)
		save_references(content_instance)


# Save references to references.json
func save_references(content_instance: RefCounted) -> void:
	var myreferences: Dictionary = content_instance.references
	var reference_json = JSON.stringify(myreferences, "\t")
	Helper.json_helper.write_json_file(content_instance.dataPath + "references.json", reference_json)


# Loads mod states from `user://mods_state.cfg` and returns them as a list. 
# If the file is not found or invalid, returns an empty array.
# mod_states example: 
#[
#    { "id": "Core", "enabled": true },
#    { "id": "mod_1", "enabled": false },
#    { "id": "mod_2", "enabled": true }
#]
func get_mod_list_states() -> Array:
	var config = ConfigFile.new()
	var path = "user://mods_state.cfg"

	if config.load(path) == OK:
		return config.get_value("mods", "states", [])
	else:
		print_debug("Failed to load mod states from: ", path)
		return []


# Returns an array of IDs for all enabled mods
func get_enabled_mod_ids() -> Array:
	var enabled_mods: Array = []
	for mod_id in mod_dict.keys():
		if mod_dict[mod_id].is_enabled:
			enabled_mods.append(mod_id)
	return enabled_mods


# ------------------------------------------------------------------
# Returns a list of DMod instances in the order defined by mod states.
# The "Core" mod is always loaded first, even if disabled.
func get_mods_in_state_order(only_enabled: bool) -> Array[DMod]:
	var ordered_mods: Array[DMod] = []
	var mod_states = get_mod_list_states()  # Retrieve the saved mod states

	# Add "Core" first if it exists
	if mod_dict.has("Core"):
		ordered_mods.append(mod_dict["Core"])

	# Add other mods in the state order
	for state in mod_states:
		var mod_id = state["id"]
		if mod_id != "Core" and mod_dict.has(mod_id):
			var mod_instance = mod_dict[mod_id]
			if not only_enabled or mod_instance.is_enabled:
				ordered_mods.append(mod_instance)

	return ordered_mods


# Returns an array of strings representing all folder names in the ./Mods/ directory
func get_mod_folder_names() -> Array[String]:
	var folder_names: Array[String] = []
	var mods_path = "res://Mods/"  # Path to the Mods folder
	
	# Open the directory and get folder names
	var dir = DirAccess.open(mods_path)
	if dir:
		dir.list_dir_begin()  # Begin iterating through the directory
		var folder_name = dir.get_next()
		while folder_name != "":
			# Skip non-folder entries and special entries (e.g., ".", "..")
			if dir.current_is_dir() and not folder_name.begins_with("."):
				folder_names.append(folder_name)
			folder_name = dir.get_next()
		dir.list_dir_end()  # End iteration
	else:
		print_debug("Failed to open Mods directory: ", mods_path)
	
	return folder_names



# Writes the default mod states to the user://mods_state.cfg file.
# If the file does not exist, it retrieves mod folder names from get_mod_folder_names,
# enabling "Core" and "Dimensionfall", and disabling all other mods.
func write_default_mods_state() -> void:
	var config_path = "user://mods_state.cfg"

	# Check if the mods_state.cfg file exists
	if not FileAccess.file_exists(config_path):
		var config = ConfigFile.new()
		var path = "user://mods_state.cfg"

		# Get the list of mod folder names
		var mod_folders = get_mod_folder_names()

		# Initialize the default mod states
		var default_mods_state: Array[Dictionary] = []

		for mod_name in mod_folders:
			# Enable "Core" and "Dimensionfall", disable all other mods
			var is_enabled = (mod_name == "Core" or mod_name == "Dimensionfall")
			default_mods_state.append({
				"id": mod_name,
				"enabled": is_enabled
			})

		# Write the default mod states to the config file
		config.set_value("mods", "states", default_mods_state)

		# Save the file
		var err = config.save(path)
		if err == OK:
			print_debug("Default mod states written to mods_state.cfg.")
		else:
			print_debug("Failed to write default mod states to mods_state.cfg. Error code: ", err)

# ------------------------------------------------------------------
# Adds a new mod to the dictionary and initializes it with the given data.
func add_new_mod(mod_id: String, mod_info: Dictionary) -> void:
	mod_info["id"] = mod_id
	mod_dict[mod_id] = DMod.new(mod_info, self)

# ------------------------------------------------------------------
# Removes a mod from the dictionary by its ID.
func delete_mod_by_id(mod_id: String) -> void:
	mod_dict.erase(mod_id)

# ------------------------------------------------------------------
# Checks if a mod exists in the dictionary by its ID.
func has_mod(mod_id: String) -> bool:
	return mod_dict.has(mod_id)

# ------------------------------------------------------------------
# Retrieves all mod IDs as an array of strings.
func get_all_mod_ids() -> Array:
	return mod_dict.keys()

# ------------------------------------------------------------------
# Retrieves all loaded mods as an array of DMod instances.
func get_all_mods() -> Array[DMod]:
	return mod_dict.values()
