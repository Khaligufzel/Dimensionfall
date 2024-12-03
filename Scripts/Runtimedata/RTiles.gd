class_name RTiles
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime tile data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of tiles. You can access it through Runtime.mods.by_id("Core").tiles

# Paths for tiles data and sprites
var tiledict: Dictionary = {}
var sprites: Dictionary = {}

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DTiles
	for mod_id in mod_ids:
		var dtiles: DTiles = Gamedata.mods.by_id(mod_id).tiles

		# Loop through each DTile in the mod
		for dtile_id: String in dtiles.get_all().keys():
			var dtile: DTile = dtiles.by_id(dtile_id)

			# Check if the tile exists in tiledict
			var rtile: RTile
			if not tiledict.has(dtile_id):
				# If it doesn't exist, create a new RTile
				rtile = add_new(dtile_id)
			else:
				# If it exists, get the existing RTile
				rtile = tiledict[dtile_id]

			# Overwrite the RTile properties with the DTile properties
			rtile.overwrite_from_dtile(dtile)

# Returns the dictionary containing all tiles
func get_all() -> Dictionary:
	return tiledict

# Adds a new tile with a given ID
func add_new(newid: String) -> RTile:
	var newtile: RTile = RTile.new(self, newid)
	tiledict[newtile.id] = newtile
	return newtile

# Deletes a tile by its ID
func delete_by_id(tileid: String) -> void:
	tiledict[tileid].delete()
	tiledict.erase(tileid)

# Returns a tile by its ID
func by_id(tileid: String) -> RTile:
	return tiledict[tileid]

# Checks if a tile exists by its ID
func has_id(tileid: String) -> bool:
	return tiledict.has(tileid)

# Returns the sprite of the tile
func sprite_by_id(tileid: String) -> Texture:
	return tiledict[tileid].sprite

# Returns the sprite of the tile by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)
