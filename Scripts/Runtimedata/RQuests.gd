class_name RQuests
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime quest data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of quests. You can access it through Runtime.mods.by_id("Core").quests

# Paths for quests data and sprites
var questdict: Dictionary = {}  # Holds runtime quest instances
var sprites: Dictionary = {}   # Holds quest sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DQuests
	for mod_id in mod_ids:
		var dquests: DQuests = Gamedata.mods.by_id(mod_id).quests

		# Loop through each DQuest in the mod
		for dquest_id: String in dquests.get_all().keys():
			var dquest: DQuest = dquests.by_id(dquest_id)

			# Check if the quest exists in questdict
			var rquest: RQuest
			if not questdict.has(dquest_id):
				# If it doesn't exist, create a new RQuest
				rquest = add_new(dquest_id)
			else:
				# If it exists, get the existing RQuest
				rquest = questdict[dquest_id]

			# Overwrite the RQuest properties with the DQuest properties
			rquest.overwrite_from_dquest(dquest)

# Returns the dictionary containing all quests
func get_all() -> Dictionary:
	return questdict

# Adds a new quest with a given ID
func add_new(newid: String) -> RQuest:
	var newquest: RQuest = RQuest.new(self, newid)
	questdict[newquest.id] = newquest
	return newquest

# Deletes a quest by its ID
func delete_by_id(questid: String) -> void:
	questdict[questid].delete()
	questdict.erase(questid)

# Returns a quest by its ID
func by_id(questid: String) -> RQuest:
	return questdict[questid]

# Checks if a quest exists by its ID
func has_id(questid: String) -> bool:
	return questdict.has(questid)

# Returns the sprite of the quest
func sprite_by_id(questid: String) -> Texture:
	return questdict[questid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)
