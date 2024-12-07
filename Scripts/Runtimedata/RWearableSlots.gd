class_name RWearableSlots
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime wearable slot data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of wearable slots. You can access it through Runtime.mods.by_id("Core").wearableslots

# Paths for wearable slot data and sprites
var wearableslotdict: Dictionary = {}  # Holds runtime wearable slot instances
var sprites: Dictionary = {}  # Holds wearable slot sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DWearableSlots
	for mod_id in mod_ids:
		var dwearableslots: DWearableSlots = Gamedata.mods.by_id(mod_id).wearableslots

		# Loop through each DWearableSlot in the mod
		for dwearableslot_id: String in dwearableslots.get_all().keys():
			var dwearableslot: DWearableSlot = dwearableslots.by_id(dwearableslot_id)

			# Check if the wearable slot exists in wearableslotdict
			var rwearableslot: RWearableSlot
			if not wearableslotdict.has(dwearableslot_id):
				# If it doesn't exist, create a new RWearableSlot
				rwearableslot = add_new(dwearableslot_id)
			else:
				# If it exists, get the existing RWearableSlot
				rwearableslot = wearableslotdict[dwearableslot_id]

			# Overwrite the RWearableSlot properties with the DWearableSlot properties
			rwearableslot.overwrite_from_dwearableslot(dwearableslot)

# Returns the dictionary containing all wearable slots
func get_all() -> Dictionary:
	return wearableslotdict

# Adds a new wearable slot with a given ID
func add_new(newid: String) -> RWearableSlot:
	var newwearableslot: RWearableSlot = RWearableSlot.new(self, newid)
	wearableslotdict[newwearableslot.id] = newwearableslot
	return newwearableslot

# Deletes a wearable slot by its ID
func delete_by_id(wearableslotid: String) -> void:
	wearableslotdict[wearableslotid].delete()
	wearableslotdict.erase(wearableslotid)

# Returns a wearable slot by its ID
func by_id(wearableslotid: String) -> RWearableSlot:
	return wearableslotdict[wearableslotid]

# Checks if a wearable slot exists by its ID
func has_id(wearableslotid: String) -> bool:
	return wearableslotdict.has(wearableslotid)

# Returns the sprite of the wearable slot
func sprite_by_id(wearableslotid: String) -> Texture:
	return wearableslotdict[wearableslotid].sprite

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
