class_name RPlayerAttributes
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime player attribute data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of player attributes. You can access it through Runtime.mods.by_id("Core").playerattributes

# Paths for player attribute data and sprites
var playerattributedict: Dictionary = {}  # Holds runtime player attribute instances
var sprites: Dictionary = {}  # Holds player attribute sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DPlayerAttributes
	for mod_id in mod_ids:
		var dplayerattributes: DPlayerAttributes = Gamedata.mods.by_id(mod_id).playerattributes

		# Loop through each DPlayerAttribute in the mod
		for dplayerattribute_id: String in dplayerattributes.get_all().keys():
			var dplayerattribute: DPlayerAttribute = dplayerattributes.by_id(dplayerattribute_id)

			# Check if the player attribute exists in playerattributedict
			var rplayerattribute: RPlayerAttribute
			if not playerattributedict.has(dplayerattribute_id):
				# If it doesn't exist, create a new RPlayerAttribute
				rplayerattribute = add_new(dplayerattribute_id)
			else:
				# If it exists, get the existing RPlayerAttribute
				rplayerattribute = playerattributedict[dplayerattribute_id]

			# Overwrite the RPlayerAttribute properties with the DPlayerAttribute properties
			rplayerattribute.overwrite_from_dplayerattribute(dplayerattribute)

# Returns the dictionary containing all player attributes
func get_all() -> Dictionary:
	return playerattributedict

# Adds a new player attribute with a given ID
func add_new(newid: String) -> RPlayerAttribute:
	var newplayerattribute: RPlayerAttribute = RPlayerAttribute.new(self, newid)
	playerattributedict[newplayerattribute.id] = newplayerattribute
	return newplayerattribute

# Deletes a player attribute by its ID
func delete_by_id(playerattributeid: String) -> void:
	playerattributedict[playerattributeid].delete()
	playerattributedict.erase(playerattributeid)

# Returns a player attribute by its ID
func by_id(playerattributeid: String) -> RPlayerAttribute:
	return playerattributedict[playerattributeid]

# Checks if a player attribute exists by its ID
func has_id(playerattributeid: String) -> bool:
	return playerattributedict.has(playerattributeid)

# Returns the sprite of the player attribute
func sprite_by_id(playerattributeid: String) -> Texture:
	return playerattributedict[playerattributeid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)
