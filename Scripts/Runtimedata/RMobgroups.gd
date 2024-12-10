class_name RMobgroups
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime mob group data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of mob groups. You can access it through Runtime.mods.by_id("Core").mobgroups

# Paths for mob group data and sprites
var mobgroupdict: Dictionary = {}  # Holds runtime mob group instances
var sprites: Dictionary = {}  # Holds mob group sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DMobgroups
	for mod_id in mod_ids:
		var dmobgroups: DMobgroups = Gamedata.mods.by_id(mod_id).mobgroups

		# Loop through each DMobgroup in the mod
		for dmobgroup_id: String in dmobgroups.get_all().keys():
			var dmobgroup: DMobgroup = dmobgroups.by_id(dmobgroup_id)

			# Check if the mob group exists in mobgroupdict
			var rmobgroup: RMobgroup
			if not mobgroupdict.has(dmobgroup_id):
				# If it doesn't exist, create a new RMobgroup
				rmobgroup = add_new(dmobgroup_id)
			else:
				# If it exists, get the existing RMobgroup
				rmobgroup = mobgroupdict[dmobgroup_id]

			# Overwrite the RMobgroup properties with the DMobgroup properties
			rmobgroup.overwrite_from_dmobgroup(dmobgroup)

# Returns the dictionary containing all mob groups
func get_all() -> Dictionary:
	return mobgroupdict

# Adds a new mob group with a given ID
func add_new(newid: String) -> RMobgroup:
	var newmobgroup: RMobgroup = RMobgroup.new(self, newid)
	mobgroupdict[newmobgroup.id] = newmobgroup
	return newmobgroup

# Deletes a mob group by its ID
func delete_by_id(mobgroupid: String) -> void:
	mobgroupdict[mobgroupid].delete()
	mobgroupdict.erase(mobgroupid)

# Returns a mob group by its ID
func by_id(mobgroupid: String) -> RMobgroup:
	return mobgroupdict[mobgroupid]

# Checks if a mob group exists by its ID
func has_id(mobgroupid: String) -> bool:
	return mobgroupdict.has(mobgroupid)

# Returns the sprite of the mob group
func sprite_by_id(mobgroupid: String) -> Texture:
	return mobgroupdict[mobgroupid].sprite

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
