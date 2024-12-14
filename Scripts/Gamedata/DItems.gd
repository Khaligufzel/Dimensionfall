class_name DItems
extends RefCounted

# There's a D in front of the class name to indicate this class only handles item data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of items. You can access it trough Gamedata.mods.by_id("Core").items


var dataPath: String = "./Mods/Core/Items/"
var filePath: String = "./Mods/Core/Items/Items.json"
var spritePath: String = "./Mods/Core/Items/"
var itemdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Items/"
	filePath = "./Mods/" + mod_id + "/Items/Items.json"
	spritePath = "./Mods/" + mod_id + "/Items/"
	load_sprites()
	load_items_from_disk()


# Load all itemdata from disk into memory
func load_items_from_disk() -> void:
	var itemlist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myitem in itemlist:
		var item: DItem = DItem.new(myitem, self)
		if myitem.has("sprite"):
			item.sprite = sprites[item.spriteid]
		itemdict[item.id] = item


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_items_to_disk()


# Saves all items to disk
func save_items_to_disk() -> void:
	var save_data: Array = []
	for item in itemdict.values():
		save_data.append(item.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))
	update_item_protoset_json_data("res://ItemProtosets.tres", JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return itemdict


# Duplicate the item to disk. A new mod id may be provided to save the duplicate to.
# itemid: The item to duplicate.
# newitemid: The id of the new duplicate (can be the same as itemid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(itemid: String, newitemid: String, new_mod_id: String) -> void:
	# Duplicate the item data and set the new id
	var itemdata: Dictionary = by_id(itemid).get_data().duplicate(true)
	itemdata.id = newitemid

	# Determine the new parent based on the new_mod_id
	var newparent: DItems = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).items

	# Instantiate and append the new DItem instance
	var newitem: DItem = DItem.new(itemdata, newparent)
	newparent.append_new(newitem)


func add_new(newid: String) -> void:
	append_new(DItem.new({"id":newid}, self))


func append_new(newitem: DItem) -> void:
	itemdict[newitem.id] = newitem
	save_items_to_disk()


func delete_by_id(itemid: String) -> void:
	itemdict[itemid].delete()
	itemdict.erase(itemid)
	save_items_to_disk()


func by_id(itemid: String) -> DItem:
	return itemdict[itemid]


func has_id(itemid: String) -> bool:
	return itemdict.has(itemid)


# Returns the sprite of the item
# itemid: The id of the item to return the sprite of
func sprite_by_id(itemid: String) -> Texture:
	return itemdict[itemid].sprite

# Returns the sprite of the item
# itemid: The id of the item to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# This will update the given resource file with the provided json data
# It is intended to save item data from json to the res://ItemProtosets.tres file
# So we can use the item json data in-game
func update_item_protoset_json_data(tres_path: String, new_json_data: String) -> void:
	# Load the ItemProtoset resource
	var item_protoset = load(tres_path) as ItemProtoset
	if not item_protoset:
		print_debug("Failed to load ItemProtoset resource from:", tres_path)
		return

	# Update the json_data property
	item_protoset.json_data = new_json_data

	# Save the resource back to the .tres file
	var save_result = ResourceSaver.save(item_protoset, tres_path)
	if save_result != OK:
		print_debug("Failed to save updated ItemProtoset resource to:", tres_path)
	else:
		print_debug("ItemProtoset resource updated and saved successfully to:", tres_path)


# Filters items by type. Returns a list of items of that type
# item_type: Any of craft, magazine, ranged, melee, food, wearable
func get_items_by_type(item_type: String) -> Array[DItem]:
	var filtered_items: Array[DItem] = []
	for item in itemdict.values():
		if not item.get(item_type) == null:
			filtered_items.append(item)
	return filtered_items


# Removes the reference from the selected itemgroup
func remove_reference(itemid: String):
	references.erase(itemid)
	Gamedata.mods.save_references(self)


# Removes a specific item from all crafting recipes across all items.
# item_id: The ID of the item to be removed from the required resources of all crafting recipes.
func remove_item_from_all_recipes(item_id: String) -> void:
	for item in itemdict.values():
		if item.craft:
			item.craft.remove_item_from_recipes(item_id)
	save_items_to_disk()


# Removes a specific playerattribute across all items.
# playerattribute_id: The ID of the playerattribute to be removed
func remove_playerattribute_from_all_items(playerattribute_id: String) -> void:
	for item: DItem in itemdict.values():
		item.remove_playerattribute(playerattribute_id)
	save_items_to_disk()


# Removes a specific wearableslot across all items.
# wearableslot_id: The ID of the wearableslot to be removed
func remove_wearableslot_from_all_items(wearableslot_id: String) -> void:
	for item: DItem in itemdict.values():
		item.remove_wearableslot(wearableslot_id)
	save_items_to_disk()


# Removes a specific skill across all items.
# wearableslot_id: The ID of the skill to be removed
func remove_skill_from_all_items(skill_id: String) -> void:
	for item: DItem in itemdict.values():
		item.remove_skill(skill_id)
	save_items_to_disk()
