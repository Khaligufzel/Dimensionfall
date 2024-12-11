class_name RItems
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime item data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of items. You can access it through Runtime.mods.by_id("Core").items

# Runtime data for items and their sprites
var itemdict: Dictionary = {}  # Holds runtime item instances
var sprites: Dictionary = {}  # Holds item sprites
var shader_materials: Dictionary = {}  # Cache for shader materials by item ID

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DItems
	for mod_id in mod_ids:
		var ditems: DItems = Gamedata.mods.by_id(mod_id).items

		# Loop through each DItem in the mod
		for ditem_id: String in ditems.get_all().keys():
			var ditem: DItem = ditems.by_id(ditem_id)

			# Check if the item exists in itemdict
			var ritem: RItem
			if not itemdict.has(ditem_id):
				# If it doesn't exist, create a new RItem
				ritem = add_new(ditem_id)
			else:
				# If it exists, get the existing RItem
				ritem = itemdict[ditem_id]

			# Overwrite the RItem properties with the DItem properties
			ritem.overwrite_from_ditem(ditem)

# Adds a new runtime item with a given ID
func add_new(newid: String) -> RItem:
	var new_item: RItem = RItem.new(self, newid)
	itemdict[new_item.id] = new_item
	return new_item

# Deletes an item by its ID
func delete_by_id(itemid: String) -> void:
	itemdict[itemid].delete()
	itemdict.erase(itemid)

# Returns a runtime item by its ID
func by_id(itemid: String) -> RItem:
	return itemdict[itemid]

# Checks if an item exists by its ID
func has_id(itemid: String) -> bool:
	return itemdict.has(itemid)

# Returns the sprite of the item
func sprite_by_id(itemid: String) -> Texture:
	return itemdict[itemid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)

# Loads sprites and assigns them to the proper dictionary
func load_sprites(sprite_path: String) -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(sprite_path, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(sprite_path + png_file)
		# Add the texture to the dictionary
		sprites[png_file] = texture
