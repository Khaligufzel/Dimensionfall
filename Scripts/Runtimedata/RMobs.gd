class_name RMobs
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime mob data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of mobs. You can access it through Runtime.mods.by_id("Core").mobs

# Paths for mob data and sprites
var mobdict: Dictionary = {}  # Holds runtime mob instances
var sprites: Dictionary = {}  # Holds mob sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DMobs
	for mod_id in mod_ids:
		var dmobs: DMobs = Gamedata.mods.by_id(mod_id).mobs

		# Loop through each DMob in the mod
		for dmob_id: String in dmobs.get_all().keys():
			var dmob: DMob = dmobs.by_id(dmob_id)

			# Check if the mob exists in mobdict
			var rmob: RMob
			if not mobdict.has(dmob_id):
				# If it doesn't exist, create a new RMob
				rmob = add_new(dmob_id)
			else:
				# If it exists, get the existing RMob
				rmob = mobdict[dmob_id]

			# Overwrite the RMob properties with the DMob properties
			rmob.overwrite_from_dmob(dmob)

# Returns the dictionary containing all mobs
func get_all() -> Dictionary:
	return mobdict

# Adds a new mob with a given ID
func add_new(newid: String) -> RMob:
	var newmob: RMob = RMob.new(self, newid)
	mobdict[newmob.id] = newmob
	return newmob

# Deletes a mob by its ID
func delete_by_id(mobid: String) -> void:
	mobdict[mobid].delete()
	mobdict.erase(mobid)

# Returns a mob by its ID
func by_id(mobid: String) -> RMob:
	return mobdict[mobid]

# Checks if a mob exists by its ID
func has_id(mobid: String) -> bool:
	return mobdict.has(mobid)

# Returns the sprite of the mob
func sprite_by_id(mobid: String) -> Texture:
	return mobdict[mobid].sprite

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
