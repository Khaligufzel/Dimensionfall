class_name RStats
extends RefCounted

# There's a R in front of the class name to indicate this class only handles runtime stats data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of stats. You can access it through Runtime.mods.by_id("Core").stats

# Paths for stats data and sprites
var statdict: Dictionary = {}
var sprites: Dictionary = {}

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DStats
	for mod_id in mod_ids:
		var dstats: DStats = Gamedata.mods.by_id(mod_id).stats

		# Loop through each DStat in the mod
		for dstat_id: String in dstats.get_all().keys():
			var dstat: DStat = dstats.by_id(dstat_id)

			# Check if the stat exists in statdict
			var rstat: RStat
			if not statdict.has(dstat_id):
				# If it doesn't exist, create a new RStat
				rstat = add_new(dstat_id)
			else:
				# If it exists, get the existing RStat
				rstat = statdict[dstat_id]

			# Overwrite the RStat properties with the DStat properties
			rstat.overwrite_from_dstat(dstat)


# Returns the dictionary containing all stats
func get_all() -> Dictionary:
	return statdict


# Adds a new stat with a given ID
func add_new(newid: String) -> RStat:
	var newstat: RStat = RStat.new(self, newid)
	statdict[newstat.id] = newstat
	return newstat

# Deletes a stat by its ID and saves changes to disk
func delete_by_id(statid: String) -> void:
	statdict[statid].delete()
	statdict.erase(statid)

# Returns a stat by its ID
func by_id(statid: String) -> RStat:
	return statdict[statid]

# Checks if a stat exists by its ID
func has_id(statid: String) -> bool:
	return statdict.has(statid)

# Returns the sprite of the stat
func sprite_by_id(statid: String) -> Texture:
	return statdict[statid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]
