class_name DMobs
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mobs. You can access it trough Gamedata.mods.by_id("Core").mobs


var dataPath: String = "./Mods/Core/Mobs/Mobs.json"
var filePath: String = "./Mods/Core/Mobs/Mobs.json"
var spritePath: String = "./Mods/Core/Mobs/"
var mobdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Mobs/"
	filePath = "./Mods/" + mod_id + "/Mobs/Mobs.json"
	spritePath = "./Mods/" + mod_id + "/Mobs/"
	load_sprites()
	load_mobs_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all mobdata from disk into memory
func load_mobs_from_disk() -> void:
	var moblist: Array = Helper.json_helper.load_json_array_file(filePath)
	for mymob in moblist:
		var mob: DMob = DMob.new(mymob, self)
		if mob.spriteid:
			mob.sprite = sprites[mob.spriteid]
		mobdict[mob.id] = mob


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_mobs_to_disk()


# Saves all mobs to disk
func save_mobs_to_disk() -> void:
	var save_data: Array = []
	for mob in mobdict.values():
		save_data.append(mob.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return mobdict


# Duplicate the mob to disk. A new mod id may be provided to save the duplicate to.
# mobid: The mob to duplicate.
# newmobid: The id of the new duplicate (can be the same as mobid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(mobid: String, newmobid: String, new_mod_id: String) -> void:
	# Duplicate the mob data and set the new id
	var mobdata: Dictionary = by_id(mobid).get_data().duplicate(true)
	mobdata.id = newmobid

	# Determine the new parent based on the new_mod_id
	var newparent: DMobs = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).mobs

	# Instantiate and append the new DMob instance
	var newmob: DMob = DMob.new(mobdata, newparent)
	if mobdata.has("sprite"):
		newmob.sprite = newparent.sprite_by_file(mobdata["sprite"])
	newparent.append_new(newmob)


# Add a new mob to the dictionary and save it to disk.
func add_new(newid: String) -> void:
	append_new(DMob.new({"id": newid}, self))


# Append a new mob to the dictionary and save it to disk.
func append_new(newmob: DMob) -> void:
	mobdict[newmob.id] = newmob
	save_mobs_to_disk()



func delete_by_id(mobid: String) -> void:
	mobdict[mobid].delete()
	mobdict.erase(mobid)
	save_mobs_to_disk()


func by_id(mobid: String) -> DMob:
	return mobdict[mobid]


func has_id(mobid: String) -> bool:
	return mobdict.has(mobid)


# Returns the sprite of the mob
# mobid: The id of the mob to return the sprite of
func sprite_by_id(mobid: String) -> Texture:
	return mobdict[mobid].sprite

# Returns the sprite of the mob
# spritefile: The file of the sprite to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]
