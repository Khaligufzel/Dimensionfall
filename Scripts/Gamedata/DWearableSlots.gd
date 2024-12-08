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

# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
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


func duplicate_to_disk(wearableslotid: String, newwearableslotid: String) -> void:
	var wearableslotdata: Dictionary = by_id(wearableslotid).get_data().duplicate(true)
	# A duplicated wearableslot is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	wearableslotdata.erase("references")
	wearableslotdata.id = newwearableslotid
	var newwearableslot: DWearableSlot = DWearableSlot.new(wearableslotdata, self)
	wearableslotdict[newwearableslotid] = newwearableslot
	save_wearableslots_to_disk()


func add_new(newid: String) -> void:
	var newwearableslot: DWearableSlot = DWearableSlot.new({"id":newid}, self)
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


# Removes the reference from the selected wearableslot
func remove_reference(wearableslotid: String, module: String, type: String, refid: String):
	var mywearableslot: DWearableSlot = wearableslotdict[wearableslotid]
	mywearableslot.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# wearableslotid: The id of the wearableslot to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(wearableslotid: String, module: String, type: String, refid: String):
	var mywearableslot: DWearableSlot = wearableslotdict[wearableslotid]
	mywearableslot.add_reference(module, type, refid)


# Helper function to update references if they have changed.
# old: an entity id that is present in the old data
# new: an entity id that is present in the new data
# refid: The entity that's referenced in old and/or new
# type: The type of entity that will be referenced
# Example usage: update_reference(old_wearableslot, new_wearableslot, "furniture", furniture_id)
# This example will remove furniture_id from the old_wearableslot's references and
# add the furniture_id to the new_wearableslot's refrences
func update_reference(old: String, new: String, type: String, refid: String) -> void:
	if old == new:
		return  # No change detected, exit early

	# Remove from old group if necessary
	if old != "":
		remove_reference(old, "core", type, refid)
	if new != "":
		add_reference(new, "core", type, refid)
