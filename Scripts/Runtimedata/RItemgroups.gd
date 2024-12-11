class_name RItemgroups
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime item group data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of item groups. You can access it through Runtime.mods.by_id("Core").itemgroups

# Paths for item group data and sprites
var itemgroupdict: Dictionary = {}  # Holds runtime item group instances
var sprites: Dictionary = {}  # Holds item group sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DItemgroups
	for mod_id in mod_ids:
		var ditemgroups: DItemgroups = Gamedata.mods.by_id(mod_id).itemgroups

		# Loop through each DItemgroup in the mod
		for ditemgroup_id: String in ditemgroups.get_all().keys():
			var ditemgroup: DItemgroup = ditemgroups.by_id(ditemgroup_id)

			# Check if the item group exists in itemgroupdict
			var ritemgroup: RItemgroup
			if not itemgroupdict.has(ditemgroup_id):
				# If it doesn't exist, create a new RItemgroup
				ritemgroup = add_new(ditemgroup_id)
			else:
				# If it exists, get the existing RItemgroup
				ritemgroup = itemgroupdict[ditemgroup_id]

			# Overwrite the RItemgroup properties with the DItemgroup properties
			ritemgroup.overwrite_from_ditemgroup(ditemgroup)

# Adds a new runtime item group with a given ID
func add_new(newid: String) -> RItemgroup:
	var new_itemgroup: RItemgroup = RItemgroup.new(self, newid)
	itemgroupdict[new_itemgroup.id] = new_itemgroup
	return new_itemgroup

# Deletes an item group by its ID
func delete_by_id(itemgroupid: String) -> void:
	itemgroupdict[itemgroupid].delete()
	itemgroupdict.erase(itemgroupid)

# Returns a runtime item group by its ID
func by_id(itemgroupid: String) -> RItemgroup:
	return itemgroupdict[itemgroupid]

# Checks if an item group exists by its ID
func has_id(itemgroupid: String) -> bool:
	return itemgroupdict.has(itemgroupid)

# Returns the sprite of the item group
func sprite_by_id(itemgroupid: String) -> Texture:
	return itemgroupdict[itemgroupid].sprite

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
