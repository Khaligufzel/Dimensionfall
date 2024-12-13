class_name RMobfactions
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime mob faction data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of mob factions. You can access it through Runtime.mods.by_id("Core").mobfactions

# Paths for mob faction data and sprites
var mobfactiondict: Dictionary = {}  # Holds runtime mob faction instances
var sprites: Dictionary = {}  # Holds mob faction sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DMobfactions
	for mod_id in mod_ids:
		var dmobfactions: DMobfactions = Gamedata.mods.by_id(mod_id).mobfactions

		# Loop through each DMobfaction in the mod
		for dmobfaction_id: String in dmobfactions.get_all().keys():
			var dmobfaction: DMobfaction = dmobfactions.by_id(dmobfaction_id)

			# Check if the mob faction exists in mobfactiondict
			var rmobfaction: RMobfaction
			if not mobfactiondict.has(dmobfaction_id):
				# If it doesn't exist, create a new RMobfaction
				rmobfaction = add_new(dmobfaction_id)
			else:
				# If it exists, get the existing RMobfaction
				rmobfaction = mobfactiondict[dmobfaction_id]

			# Overwrite the RMobfaction properties with the DMobfaction properties
			rmobfaction.overwrite_from_dmobfaction(dmobfaction)

# Adds a new runtime mob faction with a given ID
func add_new(newid: String) -> RMobfaction:
	var new_mobfaction: RMobfaction = RMobfaction.new(self, newid)
	mobfactiondict[new_mobfaction.id] = new_mobfaction
	return new_mobfaction

# Deletes a mob faction by its ID
func delete_by_id(mobfactionid: String) -> void:
	mobfactiondict[mobfactionid].delete()
	mobfactiondict.erase(mobfactionid)

# Returns a runtime mob faction by its ID
func by_id(mobfactionid: String) -> RMobfaction:
	return mobfactiondict[mobfactionid]

# Checks if a mob faction exists by its ID
func has_id(mobfactionid: String) -> bool:
	return mobfactiondict.has(mobfactionid)

# Returns the sprite of the mob faction by its ID
func sprite_by_id(mobfactionid: String) -> Texture:
	return mobfactiondict[mobfactionid].sprite
