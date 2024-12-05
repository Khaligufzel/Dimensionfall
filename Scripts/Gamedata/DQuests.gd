class_name DQuests
extends RefCounted

# There's a D in front of the class name to indicate this class only handles quests data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of quests. You can access it through Gamedata.mods.by_id("Core").quests

# Paths for quests data and sprites
var dataPath: String = "./Mods/Core/Quests/"
var filePath: String = "./Mods/Core/Quests/Quests.json"
var spritePath: String = "./Mods/Core/Items/"
var questdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}


# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Quests/"
	filePath = "./Mods/" + mod_id + "/Quests/Quests.json"
	spritePath = "./Mods/" + mod_id + "/Items/"
	
	# Load stats and sprites
	load_sprites()
	load_quests_from_disk()
	load_references()

# Load all quests data from disk into memory
func load_quests_from_disk() -> void:
	var questslist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myquest in questslist:
		var quest: DQuest = DQuest.new(myquest, self)
		quest.sprite = sprites[quest.spriteid]
		questdict[quest.id] = quest

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
	save_quests_to_disk()

# Saves all quests to disk
func save_quests_to_disk() -> void:
	var save_data: Array = []
	for quest in questdict.values():
		save_data.append(quest.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))

# Returns the dictionary containing all quests
func get_all() -> Dictionary:
	return questdict

# Duplicates a quest and saves it to disk with a new ID
func duplicate_to_disk(questid: String, newquestid: String) -> void:
	var questdata: Dictionary = by_id(questid).get_data().duplicate(true)
	# A duplicated quest is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	questdata.erase("references")
	questdata["id"] = newquestid
	var newquest: DQuest = DQuest.new(questdata, self)
	questdict[newquestid] = newquest
	save_quests_to_disk()

# Adds a new quest with a given ID
func add_new(newid: String) -> void:
	var newquest: DQuest = DQuest.new({"id": newid}, self)
	questdict[newquest.id] = newquest
	save_quests_to_disk()

# Deletes a quest by its ID and saves changes to disk
func delete_by_id(questid: String) -> void:
	questdict[questid].delete()
	questdict.erase(questid)
	save_quests_to_disk()

# Returns a quest by its ID
func by_id(questid: String) -> DQuest:
	return questdict[questid]

# Checks if a quest exists by its ID
func has_id(questid: String) -> bool:
	return questdict.has(questid)

# Returns the sprite of the quest
func sprite_by_id(questid: String) -> Texture:
	return questdict[questid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Removes all steps where the mob property matches the given mob_id
func remove_mob_from_quest(quest_id: String, mob_id: String) -> void:
	by_id(quest_id).remove_steps_by_mob(mob_id)


# Removes all steps where the mobgroup property matches the given mob_id
func remove_mobgroup_from_quest(quest_id: String, mobgroup_id: String) -> void:
	by_id(quest_id).remove_steps_by_mobgroup(mobgroup_id)

# Removes all steps and rewards where the item property matches the given item_id
func remove_item_from_quest(quest_id: String, item_id: String) -> void:
	by_id(quest_id).remove_steps_by_item(item_id)
	by_id(quest_id).remove_rewards_by_item(item_id)


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist
