class_name DMobfactions
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob faction data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mob factions. You can access it through Gamedata.mobfactions

var dataPath: String = "./Mods/Core/Mobfaction/Mobfactions.json"
var spritePath: String = "./Mods/Core/Items/"
var mobfactiondict: Dictionary = {}
var sprites: Dictionary = {}

func _init():
	load_mobfactions_from_disk()
	load_sprites()
	
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
	var mobfactionlist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for mymobfaction in mobfactionlist:
		var mobfaction: DMobfaction = DMobfaction.new(mymobfaction)
		mobfactiondict[mobfaction.id] = mobfaction

func on_data_changed():
	save_mobfactions_to_disk()

# Saves all mob factions to disk
func save_mobfactions_to_disk() -> void:
	var save_data: Array = []
	for mobfaction in mobfactiondict.values():
		save_data.append(mobfaction.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))

func get_all() -> Dictionary:
	return mobfactiondict

func duplicate_to_disk(mobfactionid: String, newmobfactionid: String) -> void:
	var mobfactiondata: Dictionary = by_id(mobfactionid).get_data().duplicate(true)
	# A duplicated mob faction is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	mobfactiondata.erase("references")
	mobfactiondata["id"] = newmobfactionid
	var newmobfaction: DMobfaction = DMobfaction.new(mobfactiondata)
	mobfactiondict[newmobfactionid] = newmobfaction
	save_mobfactions_to_disk()

# Adds a new faction with a given ID
func add_new(newid: String) -> void:
	var newmobfaction: DMobfaction = DMobfaction.new({"id": newid})
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
