class_name DItemgroups
extends RefCounted

# There's a D in front of the class name to indicate this class only handles itemgroup data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of itemgroups. You can access it trough Gamedata.mods.by_id("Core").itemgroups


var dataPath: String = "./Mods/Core/Itemgroups/"
var filePath: String = "./Mods/Core/Itemgroups/Itemgroups.json"
var spritePath: String = "./Mods/Core/Items/"
var itemgroupdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Itemgroups/"
	filePath = "./Mods/" + mod_id + "/Itemgroups/Itemgroups.json"
	spritePath = "./Mods/" + mod_id + "/Items/"
	load_sprites()
	load_itemgroups_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all itemgroupdata from disk into memory
func load_itemgroups_from_disk() -> void:
	var itemgrouplist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myitemgroup in itemgrouplist:
		var itemgroup: DItemgroup = DItemgroup.new(myitemgroup, self)
		itemgroup.sprite = sprites[itemgroup.spriteid]
		itemgroupdict[itemgroup.id] = itemgroup


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_itemgroups_to_disk()


# Saves all itemgroups to disk
func save_itemgroups_to_disk() -> void:
	var save_data: Array = []
	for itemgroup in itemgroupdict.values():
		save_data.append(itemgroup.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return itemgroupdict


# Duplicate the itemgroup to disk. A new mod id may be provided to save the duplicate to.
# itemgroupid: The itemgroup to duplicate.
# newitemgroupid: The id of the new duplicate (can be the same as itemgroupid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(itemgroupid: String, newitemgroupid: String, new_mod_id: String) -> void:
	# Duplicate the itemgroup data and set the new id
	var itemgroupdata: Dictionary = by_id(itemgroupid).get_data().duplicate(true)
	itemgroupdata.id = newitemgroupid

	# Determine the new parent based on the new_mod_id
	var newparent: DItemgroups = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).itemgroups

	# Instantiate and append the new DItemgroup instance
	var newitemgroup: DItemgroup = DItemgroup.new(itemgroupdata, newparent)
	if itemgroupdata.has("sprite"):
		newitemgroup.sprite = newparent.sprite_by_file(itemgroupdata["sprite"])
	newparent.append_new(newitemgroup)


# Add a new itemgroup to the dictionary and save it to disk.
func add_new(newid: String) -> void:
	append_new(DItemgroup.new({"id": newid}, self))


# Append a new itemgroup to the dictionary and save it to disk.
func append_new(newitemgroup: DItemgroup) -> void:
	itemgroupdict[newitemgroup.id] = newitemgroup
	save_itemgroups_to_disk()


func delete_by_id(itemgroupid: String) -> void:
	itemgroupdict[itemgroupid].delete()
	itemgroupdict.erase(itemgroupid)
	save_itemgroups_to_disk()


func by_id(itemgroupid: String) -> DItemgroup:
	return itemgroupdict[itemgroupid]


func has_id(itemgroupid: String) -> bool:
	return itemgroupdict.has(itemgroupid)


# Returns the sprite of the itemgroup
# itemgroupid: The id of the itemgroup to return the sprite of
func sprite_by_id(itemgroupid: String) -> Texture:
	return itemgroupdict[itemgroupid].sprite

# Returns the sprite of the itemgroup
# itemgroupid: The id of the itemgroup to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Removes the reference from the selected itemgroup
func remove_reference(itemgroupid: String):
	references.erase(itemgroupid)
	Gamedata.mods.save_references(self)


# Remove the provided item from all itemgroups
# This will erase it from the items list in the itemgroup
func remove_item_from_all_itemgroups(item_id: String):
	for itemgroup: DItemgroup in itemgroupdict.values():
		itemgroup.remove_item_by_id(item_id)
