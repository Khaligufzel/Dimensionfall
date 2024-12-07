class_name DMods
extends RefCounted

# This script handles the list of mods. You can access it through Gamedata.mods

# All loaded mods
var moddict: Dictionary = {}

# Constructor
# Initialize with a mod_id to dynamically set the dataPath
func _init() -> void:
	load_mods_from_disk()


# Function to load all mods from the ./Mods directory and populate the moddict dictionary
func load_mods_from_disk() -> void:
	# Clear the moddict dictionary
	moddict.clear()

	# Get the list of folders in the Mods directory using the helper function
	var folders = Helper.json_helper.folder_names_in_dir("./Mods")
	
	# Iterate through each folder
	for folder_name in folders:
		var modinfo_path = "./Mods/" + folder_name + "/modinfo.json"

		# Load the modinfo.json file if it exists
		if FileAccess.file_exists(modinfo_path):
			var modinfo = Helper.json_helper.load_json_dictionary_file(modinfo_path)

			# Validate modinfo data and add it to the moddict dictionary
			if modinfo.has("id"):
				# Initialize mod dictionary for this mod_id
				# Create a new DMods instance for this mod and associate it with the mod_id
				moddict[modinfo["id"]] = DMod.new(modinfo, self)
			else:
				print_debug("Invalid modinfo.json in folder: " + folder_name)
		else:
			print_debug("No modinfo.json found in folder: " + folder_name)


# Returns the dictionary containing all mods
func get_all() -> Dictionary:
	return moddict

# Adds a new mod with a given ID
func add_new(newid: String, modinfo: Dictionary) -> void:
	modinfo["id"] = newid
	var newmod: DMod = DMod.new(modinfo, self)
	moddict[newmod.id] = newmod

# Deletes a mod by its ID and saves changes to disk
func delete_by_id(modid: String) -> void:
	moddict.erase(modid)

# Returns a mod by its ID
func by_id(modid: String) -> DMod:
	return moddict.get(modid, null)

# Checks if a mod exists by its ID
func has_id(modid: String) -> bool:
	return moddict.has(modid)

# Returns an array of all mod IDs (keys in the moddict dictionary)
func get_all_mod_ids() -> Array:
	return moddict.keys()

# Returns an array of all mod IDs (keys in the moddict dictionary)
func get_all_mods() -> Array:
	return moddict.values()

# Function to retrieve content by its type and ID across all mods
# The returned value may be a DMap, DItem, DMobgroup or anything
# contentType: A DMod.ContentType
func get_content_by_id(contentType: DMod.ContentType, id: String) -> RefCounted:
	# Loop over all mods in the moddict
	for mod: DMod in moddict.values():
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
	
	# Loop over all mods in the moddict
	for mod in moddict.values():
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
	# Loop over all mods in the moddict
	for mod: DMod in moddict.values():
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
	# Loop over all mods in the moddict
	for mod: DMod in moddict.values():
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
