class_name DSkills
extends RefCounted

# There's a D in front of the class name to indicate this class only handles skills data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of skills. You can access it through Gamedata.skills

# Paths for skills data and sprites
var dataPath: String = "./Mods/Core/Skills/Skills.json"
var spritePath: String = "./Mods/Core/Skills/"
var skilldict: Dictionary = {}
var sprites: Dictionary = {}

# Constructor
func _init():
	load_sprites()
	load_skills_from_disk()

# Load all skills data from disk into memory
func load_skills_from_disk() -> void:
	var skillslist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for myskill in skillslist:
		var skill: DSkill = DSkill.new(myskill)
		skill.sprite = sprites[skill.spriteid]
		skilldict[skill.id] = skill

# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the texture to the dictionary
		sprites[png_file] = texture

# Called when data changes and needs to be saved
func on_data_changed():
	save_skills_to_disk()

# Saves all skills to disk
func save_skills_to_disk() -> void:
	var save_data: Array = []
	for skill in skilldict.values():
		save_data.append(skill.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))

# Returns the dictionary containing all skills
func get_skills() -> Dictionary:
	return skilldict

# Duplicates a skill and saves it to disk with a new ID
func duplicate_skill_to_disk(skillid: String, newskillid: String) -> void:
	var skilldata: Dictionary = skilldict[skillid].get_data().duplicate(true)
	skilldata["id"] = newskillid
	var newskill: DSkill = DSkill.new(skilldata)
	skilldict[newskillid] = newskill
	save_skills_to_disk()

# Adds a new skill with a given ID
func add_new_skill(newid: String) -> void:
	var newskill: DSkill = DSkill.new({"id": newid})
	skilldict[newskill.id] = newskill
	save_skills_to_disk()

# Deletes a skill by its ID and saves changes to disk
func delete_skill(skillid: String) -> void:
	skilldict[skillid].delete()
	skilldict.erase(skillid)
	save_skills_to_disk()

# Returns a skill by its ID
func by_id(skillid: String) -> DSkill:
	return skilldict[skillid]

# Checks if a skill exists by its ID
func has_id(skillid: String) -> bool:
	return skilldict.has(skillid)

# Returns the sprite of the skill
func sprite_by_id(skillid: String) -> Texture:
	return skilldict[skillid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]

# Removes a reference from the selected skill
func remove_reference(skillid: String, module: String, type: String, refid: String):
	var myskill: DSkill = skilldict[skillid]
	myskill.remove_reference(module, type, refid)

# Adds a reference to the references list in the skill
func add_reference(skillid: String, module: String, type: String, refid: String):
	var myskill: DSkill = skilldict[skillid]
	myskill.add_reference(module, type, refid)

# Helper function to update references if they have changed
func update_reference(old: String, new: String, type: String, refid: String) -> void:
	if old == new:
		return  # No change detected, exit early

	# Remove from old group if necessary
	if old != "":
		remove_reference(old, "core", type, refid)
	if new != "":
		add_reference(new, "core", type, refid)
