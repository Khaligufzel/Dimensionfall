class_name DItems
extends RefCounted

# There's a D in front of the class name to indicate this class only handles item data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of items. You can access it trough Gamedata.mods.by_id("Core").items


var data_path: String = "./Mods/Core/Items/"
var file_path: String = "./Mods/Core/Items/Items.json"
var sprite_path: String = "./Mods/Core/Items/"
var items: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Initialize paths and load all data
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update data_path and sprite_path using the provided mod_id
	data_path = "./Mods/" + mod_id + "/Items/"
	file_path = "./Mods/" + mod_id + "/Items/Items.json"
	sprite_path = "./Mods/" + mod_id + "/Items/"
	load_sprites()
	load_items_from_disk()
	load_references()


# -----------------------
# Data Loading Functions
# -----------------------
# Load item references from "references.json"
func load_references() -> void:
	var path = data_path + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist

# Load all item data from disk and populate `items`
func load_items_from_disk() -> void:
	var item_list: Array = Helper.json_helper.load_json_array_file(file_path)
	for item_data: Dictionary in item_list:
		var item = DItem.new(item_data, self)
		if item_data.has("sprite"):
			item.sprite = sprites.get(item.spriteid, null)
		items[item.id] = item

# Load all PNG files in the sprite directory into `sprites`
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(sprite_path, ["png"])
	for png_file in png_files:
		sprites[png_file] = load(sprite_path + png_file)

# -----------------------
# Data Saving Functions
# -----------------------
# Save all items back to disk
func save_items_to_disk() -> void:
	var save_data: Array = []
	for item: DItem in items.values():
		save_data.append(item.get_data())
	Helper.json_helper.write_json_file(file_path, JSON.stringify(save_data, "\t"))

# Called when data is modified
func on_data_changed() -> void:
	save_items_to_disk()

# -----------------------
# Item Management
# -----------------------
# Get all items as a dictionary
func get_all() -> Dictionary:
	return items

# Add a new item by ID
func add_new(item_id: String) -> void:
	var new_item = DItem.new({"id": item_id}, self)
	_append_new_item(new_item)

# Append a new item to the dictionary and save
func _append_new_item(new_item: DItem) -> void:
	items[new_item.id] = new_item
	save_items_to_disk()

# Delete an item by ID
func delete_by_id(item_id: String) -> void:
	if items.has(item_id):
		items[item_id].delete()
		items.erase(item_id)
		save_items_to_disk()

# Get an item by ID
func by_id(item_id: String) -> DItem:
	return items.get(item_id)

# Check if an item ID exists
func has_id(item_id: String) -> bool:
	return items.has(item_id)

# -----------------------
# Sprite Management
# -----------------------
# Get the sprite texture for an item by ID
func sprite_by_id(item_id: String) -> Texture:
	return items.get(item_id).sprite

# Get the sprite texture by file name
func sprite_by_file(file_name: String) -> Texture:
	return sprites.get(file_name)

# -----------------------
# Filtering and References
# -----------------------
# Get all items of a specific type
func get_items_by_type(item_type: String) -> Array[DItem]:
	var filtered_items: Array[DItem] = []
	for item in items.values():
		if not item.get(item_type) == null:
			filtered_items.append(item)
	return filtered_items


# Remove a reference for an item
func remove_reference(item_id: String) -> void:
	references.erase(item_id)
	Gamedata.mods.save_references(self)

# Get all references for a specific item ID
# The return value might look like this:
#{
#	"itemgroups": [
#		"refridgerator",
#		"starting_items"
#	]
#}
func get_references_by_id(item_id: String) -> Dictionary:
	return references.get(item_id, {})

# -----------------------
# Duplication Functions
# -----------------------
# Duplicate an item to another mod or ID
func duplicate_to_disk(item_id: String, new_item_id: String, new_mod_id: String) -> void:
	var original_item = by_id(item_id)
	if original_item:
		var duplicated_data = original_item.get_data().duplicate(true)
		duplicated_data.id = new_item_id
		var target_items = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).items
		var new_item = DItem.new(duplicated_data, target_items)
		target_items._append_new_item(new_item)

# -----------------------
# Bulk Editing
# -----------------------
# Remove an item from all crafting recipes
func remove_item_from_all_recipes(item_id: String) -> void:
	for item in items.values():
		if item.craft:
			item.craft.remove_item_from_recipes(item_id)
	save_items_to_disk()

# Remove a player attribute across all items
func remove_playerattribute_from_all_items(attribute_id: String) -> void:
	for item in items.values():
		item.remove_playerattribute(attribute_id)
	save_items_to_disk()

# Remove a wearable slot across all items
func remove_wearableslot_from_all_items(slot_id: String) -> void:
	for item in items.values():
		item.remove_wearableslot(slot_id)
	save_items_to_disk()

# Remove a skill across all items
func remove_skill_from_all_items(skill_id: String) -> void:
	for item in items.values():
		item.remove_skill(skill_id)
	save_items_to_disk()
