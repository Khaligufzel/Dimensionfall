class_name DSkills
extends RefCounted

# There's a D in front of the class name to indicate this class only handles skills data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of skills. You can access it through Gamedata.mods.by_id("Core").skills

# Paths for skills data and sprites
var dataPath: String = "./Mods/Core/Skills/"
var filePath: String = "./Mods/Core/Skills/Skills.json"
var spritePath: String = "./Mods/Core/Skills/"
var skilldict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}


# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Skills/"
	filePath = "./Mods/" + mod_id + "/Skills/Skills.json"
	spritePath = "./Mods/" + mod_id + "/Skills/"
	
	# Load stats and sprites
	load_sprites()
	load_skills_from_disk()
	load_references()


# Load all skills data from disk into memory
func load_skills_from_disk() -> void:
	var skillslist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myskill in skillslist:
		var skill: DSkill = DSkill.new(myskill, self)
		skill.sprite = sprites[skill.spriteid]
		skilldict[skill.id] = skill


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


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
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))

# Returns the dictionary containing all skills
func get_all() -> Dictionary:
	return skilldict

# Duplicates a skill and saves it to disk with a new ID
func duplicate_to_disk(skillid: String, newskillid: String) -> void:
	var skilldata: Dictionary = by_id(skillid).get_data().duplicate(true)
	# A duplicated quest is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	skilldata.erase("references")
	skilldata["id"] = newskillid
	var newskill: DSkill = DSkill.new(skilldata, self)
	skilldict[newskillid] = newskill
	save_skills_to_disk()

# Adds a new skill with a given ID
func add_new(newid: String) -> void:
	var newskill: DSkill = DSkill.new({"id": newid}, self)
	skilldict[newskill.id] = newskill
	save_skills_to_disk()

# Deletes a skill by its ID and saves changes to disk
func delete_by_id(skillid: String) -> void:
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
