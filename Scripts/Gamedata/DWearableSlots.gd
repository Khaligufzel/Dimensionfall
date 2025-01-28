class_name DWearableSlots
extends RefCounted

# There's a D in front of the class name to indicate this class only handles wearableslot data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of wearableslots. You can access it trough Gamedata.mods.by_id("Core").wearableslots


var dataPath: String = "./Mods/Core/Wearableslots/"
var filePath: String = "./Mods/Core/Wearableslots/Wearableslots.json"
var spritePath: String = "./Mods/Core/Wearableslots/"
var wearableslotdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Wearableslots/"
	filePath = "./Mods/" + mod_id + "/Wearableslots/Wearableslots.json"
	spritePath = "./Mods/" + mod_id + "/Wearableslots/"
	load_sprites()
	load_wearableslots_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all wearableslotdata from disk into memory
func load_wearableslots_from_disk() -> void:
	var wearableslotlist: Array = Helper.json_helper.load_json_array_file(filePath)
	for mywearableslot in wearableslotlist:
		var wearableslot: DWearableSlot = DWearableSlot.new(mywearableslot, self)
		wearableslot.sprite = sprites[wearableslot.spriteid]
		wearableslotdict[wearableslot.id] = wearableslot


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_wearableslots_to_disk()


# Saves all wearableslots to disk
func save_wearableslots_to_disk() -> void:
	var save_data: Array = []
	for wearableslot in wearableslotdict.values():
		save_data.append(wearableslot.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return wearableslotdict


# Duplicate the wearable slot to disk. A new mod id may be provided to save the duplicate to.
# wearableslotid: The wearable slot to duplicate.
# newwearableslotid: The id of the new duplicate (can be the same as wearableslotid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(wearableslotid: String, newwearableslotid: String, new_mod_id: String) -> void:
	# Duplicate the wearable slot data and set the new id
	var wearableslotdata: Dictionary = by_id(wearableslotid).get_data().duplicate(true)
	wearableslotdata.id = newwearableslotid

	# Determine the new parent based on the new_mod_id
	var newparent: DWearableSlots = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).wearableslots

	# Instantiate and append the new DWearableSlot instance
	var newwearableslot: DWearableSlot = DWearableSlot.new(wearableslotdata, newparent)
	if wearableslotdata.has("sprite"):
		newwearableslot.sprite = newparent.sprite_by_file(wearableslotdata["sprite"])
	newparent.append_new(newwearableslot)


# Add a new wearable slot to the dictionary and save it to disk.
func add_new(newid: String) -> void:
	append_new(DWearableSlot.new({"id": newid}, self))


# Append a new wearable slot to the dictionary and save it to disk.
func append_new(newwearableslot: DWearableSlot) -> void:
	wearableslotdict[newwearableslot.id] = newwearableslot
	save_wearableslots_to_disk()


func delete_by_id(wearableslotid: String) -> void:
	wearableslotdict[wearableslotid].delete()
	wearableslotdict.erase(wearableslotid)
	save_wearableslots_to_disk()


func by_id(wearableslotid: String) -> DWearableSlot:
	return wearableslotdict[wearableslotid]


func has_id(wearableslotid: String) -> bool:
	return wearableslotdict.has(wearableslotid)


# Returns the sprite of the wearableslot
# wearableslotid: The id of the wearableslot to return the sprite of
func sprite_by_id(wearableslotid: String) -> Texture:
	return wearableslotdict[wearableslotid].sprite

# Returns the sprite of the wearableslot
# wearableslotid: The id of the wearableslot to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Removes the reference of the selected wearableslot
func remove_reference(wearableslot_id: String):
	references.erase(wearableslot_id)
	Gamedata.mods.save_references(self)


# Remove the provided item from all wearableslot
# This will erase it from starting_item
func remove_item_from_all_wearableslot(item_id: String):
	for wearableslot in wearableslotdict.values():
		wearableslot.remove_item(item_id)
