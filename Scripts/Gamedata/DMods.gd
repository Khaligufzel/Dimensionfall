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
