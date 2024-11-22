class_name DItemgroups
extends RefCounted

# There's a D in front of the class name to indicate this class only handles itemgroup data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of itemgroups. You can access it trough Gamedata.itemgroups


var dataPath: String = "./Mods/Core/Itemgroups/Itemgroups.json"
var spritePath: String = "./Mods/Core/Items/"
var itemgroupdict: Dictionary = {}
var sprites: Dictionary = {}


func _init():
	load_sprites()
	load_itemgroups_from_disk()


# Load all itemgroupdata from disk into memory
func load_itemgroups_from_disk() -> void:
	var itemgrouplist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for myitemgroup in itemgrouplist:
		var itemgroup: DItemgroup = DItemgroup.new(myitemgroup)
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
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return itemgroupdict


func duplicate_to_disk(itemgroupid: String, newitemgroupid: String) -> void:
	var itemgroupdata: Dictionary = by_id(itemgroupid).get_data().duplicate(true)
	# A duplicated itemgroup is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	itemgroupdata.erase("references")
	itemgroupdata.id = newitemgroupid
	var newitemgroup: DItemgroup = DItemgroup.new(itemgroupdata)
	itemgroupdict[newitemgroupid] = newitemgroup
	save_itemgroups_to_disk()


func add_new(newid: String) -> void:
	var newitemgroup: DItemgroup = DItemgroup.new({"id":newid})
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
func remove_reference(itemgroupid: String, module: String, type: String, refid: String):
	if itemgroupid == "" or not itemgroupdict.has(itemgroupid):
		return
	var myitemgroup: DItemgroup = itemgroupdict[itemgroupid]
	myitemgroup.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# itemgroupid: The id of the itemgroup to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(itemgroupid: String, module: String, type: String, refid: String):
	var myitemgroup: DItemgroup = itemgroupdict[itemgroupid]
	myitemgroup.add_reference(module, type, refid)


# Helper function to update references if they have changed.
# old: an entity id that is present in the old data
# new: an entity id that is present in the new data
# refid: The entity that's referenced in old and/or new
# type: The type of entity that will be referenced
# Example usage: update_reference(old_itemgroup, new_itemgroup, "furniture", furniture_id)
# This example will remove furniture_id from the old_itemgroup's references and
# add the furniture_id to the new_itemgroup's refrences
func update_reference(old: String, new: String, type: String, refid: String) -> void:
	if old == new:
		return  # No change detected, exit early

	# Remove from old group if necessary
	if old != "":
		remove_reference(old, "core", type, refid)
	if new != "":
		add_reference(new, "core", type, refid)
