class_name DMobgroups
extends RefCounted

# There's a D in front of the class name to indicate this class only handles mob group data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of mob groups. You can access it through Gamedata.mods.by_id("Core").mobgroups

var dataPath: String = "./Mods/Core/Mobgroups/"
var filePath: String = "./Mods/Core/Mobgroups/Mobgroups.json"
var spritePath: String = "./Mods/Core/Mobs/"
var mobgroupdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Mobgroups/"
	filePath = "./Mods/" + mod_id + "/Mobgroups/Mobgroups.json"
	spritePath = "./Mods/" + mod_id + "/Mobs/"
	load_sprites()
	load_mobgroups_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all mob group data from disk into memory
func load_mobgroups_from_disk() -> void:
	var mobgrouplist: Array = Helper.json_helper.load_json_array_file(filePath)
	for mymobgroup in mobgrouplist:
		var mobgroup: DMobgroup = DMobgroup.new(mymobgroup, self)
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
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))

func get_all() -> Dictionary:
	return mobgroupdict

# Duplicate the mobgroup to disk. A new mod id may be provided to save the duplicate to.
# mobgroupid: The mobgroup to duplicate.
# newmobgroupid: The id of the new duplicate (can be the same as mobgroupid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(mobgroupid: String, newmobgroupid: String, new_mod_id: String) -> void:
	# Duplicate the mobgroup data and set the new id
	var mobgroupdata: Dictionary = by_id(mobgroupid).get_data().duplicate(true)
	mobgroupdata["id"] = newmobgroupid

	# Determine the new parent based on the new_mod_id
	var newparent: DMobgroups = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).mobgroups

	# Instantiate and append the new DMobgroup instance
	var newmobgroup: DMobgroup = DMobgroup.new(mobgroupdata, newparent)
	if mobgroupdata.has("sprite"):
		newmobgroup.sprite = newparent.sprite_by_file(mobgroupdata["sprite"])
	newparent.append_new(newmobgroup)


# Add a new mobgroup with a given ID.
func add_new(newid: String) -> void:
	append_new(DMobgroup.new({"id": newid}, self))


# Append a new mobgroup to the dictionary and save it to disk.
func append_new(newmobgroup: DMobgroup) -> void:
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


# Removes the entity from the mobgroups provided in the mobgroups array
# mob_id: the id of the entity
# mobgroups: An array of mobgroup id's (Strings)
func remove_entity_from_selected_mobgroups(mob_id: String, mobgroups: Array):
	for mob in mobgroups:
		if has_id(mob_id):
			mobgroupdict[mob].remove_mob_by_id(mob_id)


# Removes the reference from the selected mobgroup
func remove_reference(mobgroupid: String):
	references.erase(mobgroupid)
	Gamedata.mods.save_references(self)
