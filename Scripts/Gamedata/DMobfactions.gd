class_name DMobfactions
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob group data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mob groups. You can access it through Gamedata.mobgroups

var dataPath: String = "./Mods/Core/Mobfaction/Mobfactions.json"
var spritePath: String = "./Mods/Core/Mobs/"
var mobfactiondict: Dictionary = {}
var sprites: Dictionary = {}

func _init():
	load_sprites()
	load_mobfactions_from_disk()

# Load all mob group data from disk into memory
func load_mobfactions_from_disk() -> void:
	var mobfactionlist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for mymobfaction in mobfactionlist:
		var mobfaction: DMobfaction = DMobfaction.new(mymobfaction)
		if mobfaction.spriteid:
			mobfaction.sprite = sprites[mobfaction.spriteid]
		mobfactiondict[mobfaction.id] = mobfaction

# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the material to the dictionary
		sprites[png_file] = texture

func on_data_changed():
	save_mobfactions_to_disk()

# Saves all mob groups to disk
func save_mobfactions_to_disk() -> void:
	var save_data: Array = []
	for mobfaction in mobfactiondict.values():
		save_data.append(mobfaction.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))

func get_all() -> Dictionary:
	return mobfactiondict

func duplicate_to_disk(mobfactionid: String, newmobfactionid: String) -> void:
	var mobfactiondata: Dictionary = by_id(mobfactionid).get_data().duplicate(true)
	# A duplicated mob group is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	mobfactiondata.erase("references")
	mobfactiondata.id = newmobfactionid
	var newmobfaction: DMobfaction = DMobfaction.new(mobfactiondata)
	mobfactiondict[newmobfactionid] = newmobfaction
	save_mobfactions_to_disk()

func add_new(newid: String) -> void:
	var newmobfaction: DMobfaction = DMobfaction.new({"id": newid})
	mobfactiondict[newmobfaction.id] = newmobfaction
	save_mobfactions_to_disk()

func delete_by_id(mobfactionid: String) -> void:
	mobfactiondict[mobfactionid].delete()
	mobfactiondict.erase(mobfactionid)
	save_mobfactions_to_disk()

func by_id(mobfactionid: String) -> DMobfaction:
	return mobfactiondict[mobfactionid]

func has_id(mobfactionid: String) -> bool:
	return mobfactiondict.has(mobfactionid)

# Returns the sprite of the mob group
# mobgroupid: The id of the mob group to return the sprite of
func sprite_by_id(mobfactionid: String) -> Texture:
	return mobfactiondict[mobfactionid].sprite

# Returns the sprite of the mob group
# spritefile: The file of the sprite to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]

# Removes the reference from the selected mob group
func remove_reference(mobfactionid: String, module: String, type: String, refid: String):
	var mymobfaction: DMobfaction = mobfactiondict[mobfactionid]
	mymobfaction.remove_reference(module, type, refid)

# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# mobgroupid: The id of the mob group to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(mobfactionid: String, module: String, type: String, refid: String):
	var mymobfaction: DMobfaction = mobfactiondict[mobfactionid]
	mymobfaction.add_reference(module, type, refid)
