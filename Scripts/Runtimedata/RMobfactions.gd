class_name RMobfactions
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime mob faction data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of mob factions. You can access it through Runtime.mods.by_id("Core").mobfactions

# Paths for mob faction data and sprites
var mobfactiondict: Dictionary = {}  # Holds runtime mob faction instances
var sprites: Dictionary = {}  # Holds mob faction sprites

# Constructor
func _init(mod_list: Array[DMod]) -> void:
	# Loop through each mod
	for mod in mod_list:
		var dmobfactions: DMobfactions = mod.mobfactions

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

# Returns an array of all mobfaction IDs in the mobfactiondict
func get_all_mobfaction_ids() -> Array[String]:
	return mobfactiondict.keys()

# Returns an array of all mobfactions in the mobfactiondict
func get_all_mobfactions() -> Array:
	return mobfactiondict.values()
