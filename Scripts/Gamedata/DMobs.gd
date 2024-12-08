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

# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Mobs/"
	filePath = "./Mods/" + mod_id + "/Mobs/Mobs.json"
	spritePath = "./Mods/" + mod_id + "/Mobs/"
	load_sprites()
	load_mobs_from_disk()


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


func duplicate_to_disk(mobid: String, newmobid: String) -> void:
	var mobdata: Dictionary = by_id(mobid).get_data().duplicate(true)
	# A duplicated mob is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	mobdata.erase("references")
	mobdata.id = newmobid
	var newmob: DMob = DMob.new(mobdata, self)
	mobdict[newmobid] = newmob
	save_mobs_to_disk()


func add_new(newid: String) -> void:
	var newmob: DMob = DMob.new({"id":newid}, self)
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


# Removes the reference from the selected mob
func remove_reference(mobid: String, module: String, type: String, refid: String):
	var mymob: DMob = mobdict[mobid]
	mymob.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# mobid: The id of the mob to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(mobid: String, module: String, type: String, refid: String):
	var mymob: DMob = mobdict[mobid]
	mymob.add_reference(module, type, refid)
