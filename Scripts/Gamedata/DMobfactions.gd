class_name DMobfactions
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob faction data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mob factions. You can access it through Gamedata.mods.by_id("Core").mobfactions

var dataPath: String = "./Mods/Core/Mobfaction/"
var filePath: String = "./Mods/Core/Mobfaction/Mobfactions.json"
var spritePath: String = "./Mods/Core/Items/"
var mobfactiondict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Mobfaction/"
	filePath = "./Mods/" + mod_id + "/Mobfaction/Mobfactions.json"
	spritePath = "./Mods/" + mod_id + "/Items/"
	load_mobfactions_from_disk()
	load_sprites()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist
	
# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the texture to the dictionary
		sprites[png_file] = texture

# Returns the sprite of the mobfactionid
# mobid: The id of the mobfactionid to return the sprite of
func sprite_by_id(mobfactionid: String) -> Texture:
	return mobfactiondict[mobfactionid].sprite

# Load all mob faction data from disk into memory
func load_mobfactions_from_disk() -> void:
	var mobfactionlist: Array = Helper.json_helper.load_json_array_file(filePath)
	for mymobfaction in mobfactionlist:
		var mobfaction: DMobfaction = DMobfaction.new(mymobfaction, self)
		mobfactiondict[mobfaction.id] = mobfaction

func on_data_changed():
	save_mobfactions_to_disk()

# Saves all mob factions to disk
func save_mobfactions_to_disk() -> void:
	var save_data: Array = []
	for mobfaction in mobfactiondict.values():
		save_data.append(mobfaction.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))

func get_all() -> Dictionary:
	return mobfactiondict

# Duplicate the mobfaction to disk. A new mod id may be provided to save the duplicate to.
# mobfactionid: The mobfaction to duplicate.
# newmobfactionid: The id of the new duplicate (can be the same as mobfactionid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(mobfactionid: String, newmobfactionid: String, new_mod_id: String) -> void:
	# Duplicate the mobfaction data and set the new id
	var mobfactiondata: Dictionary = by_id(mobfactionid).get_data().duplicate(true)
	mobfactiondata["id"] = newmobfactionid

	# Determine the new parent based on the new_mod_id
	var newparent: DMobfactions = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).mobfactions

	# Instantiate and append the new DMobfaction instance
	var newmobfaction: DMobfaction = DMobfaction.new(mobfactiondata, newparent)
	newparent.append_new(newmobfaction)


# Add a new mobfaction with a given ID.
func add_new(newid: String) -> void:
	append_new(DMobfaction.new({"id": newid}, self))


# Append a new mobfaction to the dictionary and save it to disk.
func append_new(newmobfaction: DMobfaction) -> void:
	mobfactiondict[newmobfaction.id] = newmobfaction
	save_mobfactions_to_disk()


# Deletes a faction by its ID and saves changes to disk
func delete_by_id(mobfactionid: String) -> void:
	mobfactiondict[mobfactionid].delete()
	mobfactiondict.erase(mobfactionid)
	save_mobfactions_to_disk()

# Returns a faction by its ID
func by_id(mobfactionid: String) -> DMobfaction:
	return mobfactiondict[mobfactionid]

# Checks if a faction exists by its ID
func has_id(mobfactionid: String) -> bool:
	return mobfactiondict.has(mobfactionid)

# Removes all steps where the mob property matches the given mob_id
func remove_mob_from_faction(faction_id: String, mob_id: String) -> void:
	by_id(faction_id).remove_relations_by_mob(mob_id)


# Removes all steps where the mobgroup property matches the given mob_id
func remove_mobgroup_from_faction(faction_id: String, mobgroup_id: String) -> void:
	by_id(faction_id).remove_factions_by_mobgroup(mobgroup_id)


# Removes the reference from the selected mobfaction
func remove_reference(mobfactionid: String):
	references.erase(mobfactionid)
	Gamedata.mods.save_references(self)
