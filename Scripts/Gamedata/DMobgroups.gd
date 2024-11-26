class_name DMobgroups
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob group data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mob groups. You can access it through Gamedata.mobgroups

var dataPath: String = "./Mods/Core/Mobgroups/Mobgroups.json"
var spritePath: String = "./Mods/Core/Mobs/"
var mobgroupdict: Dictionary = {}
var sprites: Dictionary = {}

func _init():
	load_sprites()
	load_mobgroups_from_disk()

# Load all mob group data from disk into memory
func load_mobgroups_from_disk() -> void:
	var mobgrouplist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for mymobgroup in mobgrouplist:
		var mobgroup: DMobgroup = DMobgroup.new(mymobgroup)
		if mobgroup.spriteid:
			mobgroup.sprite = sprites[mobgroup.spriteid]
		mobgroupdict[mobgroup.id] = mobgroup

# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the material to the dictionary
		sprites[png_file] = texture

func on_data_changed():
	save_mobgroups_to_disk()

# Saves all mob groups to disk
func save_mobgroups_to_disk() -> void:
	var save_data: Array = []
	for mobgroup in mobgroupdict.values():
		save_data.append(mobgroup.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))

func get_all() -> Dictionary:
	return mobgroupdict

func duplicate_to_disk(mobgroupid: String, newmobgroupid: String) -> void:
	var mobgroupdata: Dictionary = by_id(mobgroupid).get_data().duplicate(true)
	# A duplicated mob group is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	mobgroupdata.erase("references")
	mobgroupdata.id = newmobgroupid
	var newmobgroup: DMobgroup = DMobgroup.new(mobgroupdata)
	mobgroupdict[newmobgroupid] = newmobgroup
	save_mobgroups_to_disk()

func add_new(newid: String) -> void:
	var newmobgroup: DMobgroup = DMobgroup.new({"id": newid})
	mobgroupdict[newmobgroup.id] = newmobgroup
	save_mobgroups_to_disk()

func delete_by_id(mobgroupid: String) -> void:
	mobgroupdict[mobgroupid].delete()
	mobgroupdict.erase(mobgroupid)
	save_mobgroups_to_disk()

func by_id(mobgroupid: String) -> DMobgroup:
	return mobgroupdict[mobgroupid]

func has_id(mobgroupid: String) -> bool:
	return mobgroupdict.has(mobgroupid)

# Returns the sprite of the mob group
# mobgroupid: The id of the mob group to return the sprite of
func sprite_by_id(mobgroupid: String) -> Texture:
	return mobgroupdict[mobgroupid].sprite

# Returns the sprite of the mob group
# spritefile: The file of the sprite to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]

# Removes the reference from the selected mob group
func remove_reference(mobgroupid: String, module: String, type: String, refid: String):
	var mymobgroup: DMobgroup = mobgroupdict[mobgroupid]
	mymobgroup.remove_reference(module, type, refid)

# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# mobgroupid: The id of the mob group to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(mobgroupid: String, module: String, type: String, refid: String):
	var mymobgroup: DMobgroup = mobgroupdict[mobgroupid]
	mymobgroup.add_reference(module, type, refid)
