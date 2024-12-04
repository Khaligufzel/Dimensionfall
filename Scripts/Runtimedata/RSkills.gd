class_name RSkills
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime skills data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of skills. You can access it through Runtime.mods.by_id("Core").skills

# Paths for skills data and sprites
var skilldict: Dictionary = {}  # Holds runtime skill instances
var sprites: Dictionary = {}   # Holds skill sprites

# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DSkills
	for mod_id in mod_ids:
		var dskills: DSkills = Gamedata.mods.by_id(mod_id).skills

		# Loop through each DSkill in the mod
		for dskill_id: String in dskills.get_all().keys():
			var dskill: DSkill = dskills.by_id(dskill_id)

			# Check if the skill exists in skilldict
			var rskill: RSkill
			if not skilldict.has(dskill_id):
				# If it doesn't exist, create a new RSkill
				rskill = add_new(dskill_id)
			else:
				# If it exists, get the existing RSkill
				rskill = skilldict[dskill_id]

			# Overwrite the RSkill properties with the DSkill properties
			rskill.overwrite_from_dskill(dskill)

# Returns the dictionary containing all skills
func get_all() -> Dictionary:
	return skilldict

# Adds a new skill with a given ID
func add_new(newid: String) -> RSkill:
	var newskill: RSkill = RSkill.new(self, newid)
	skilldict[newskill.id] = newskill
	return newskill

# Deletes a skill by its ID
func delete_by_id(skillid: String) -> void:
	skilldict[skillid].delete()
	skilldict.erase(skillid)

# Returns a skill by its ID
func by_id(skillid: String) -> RSkill:
	return skilldict[skillid]

# Checks if a skill exists by its ID
func has_id(skillid: String) -> bool:
	return skilldict.has(skillid)

# Returns the sprite of the skill
func sprite_by_id(skillid: String) -> Texture:
	return skilldict[skillid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)
