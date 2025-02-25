class_name RAttacks
extends RefCounted

# There's a R in front of the class name to indicate this class only handles runtime attacks data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of attacks. You can access it through Runtime.mods.by_id("Core").attacks

# Paths for attacks data and sprites
var attackdict: Dictionary = {}
var sprites: Dictionary = {}

# Constructor
func _init(mod_list: Array[DMod]) -> void:
	# Loop through each mod to get its DAttacks
	for mod in mod_list:
		var rattacks: DAttacks = mod.attacks

		# Loop through each DAttack in the mod
		for dstat_id: String in rattacks.get_all().keys():
			var dattack: DAttack = rattacks.by_id(dstat_id)

			# Check if the stat exists in attackdict
			var rattack: RAttack
			if not attackdict.has(dstat_id):
				# If it doesn't exist, create a new RAttack
				rattack = add_new(dstat_id)
			else:
				# If it exists, get the existing RAttack
				rattack = attackdict[dstat_id]

			# Overwrite the RAttack properties with the DAttack properties
			rattack.overwrite_from_dattack(dattack)


# Returns the dictionary containing all attacks
func get_all() -> Dictionary:
	return attackdict


# Adds a new stat with a given ID
func add_new(newid: String) -> RAttack:
	var newattack: RAttack = RAttack.new(self, newid)
	attackdict[newattack.id] = newattack
	return newattack

# Deletes a stat by its ID and saves changes to disk
func delete_by_id(statid: String) -> void:
	attackdict[statid].delete()
	attackdict.erase(statid)

# Returns a stat by its ID
func by_id(statid: String) -> RAttack:
	return attackdict[statid]

# Checks if a stat exists by its ID
func has_id(statid: String) -> bool:
	return attackdict.has(statid)

# Returns the sprite of the stat
func sprite_by_id(statid: String) -> Texture:
	return attackdict[statid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]
