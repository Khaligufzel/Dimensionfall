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
var mod_id: String = "Core"


# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
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
		if sprites.has(quest.spriteid):
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
# Duplicate the quest to disk. A new mod id may be provided to save the duplicate to.
# questid: The quest to duplicate.
# newquestid: The id of the new duplicate (can be the same as questid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(questid: String, newquestid: String, new_mod_id: String) -> void:
	# Duplicate the quest data and set the new id
	var questdata: Dictionary = by_id(questid).get_data().duplicate(true)
	questdata["id"] = newquestid

	# Determine the new parent based on the new_mod_id
	var newparent: DQuests = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).quests

	# Instantiate and append the new DQuest instance
	var newquest: DQuest = DQuest.new(questdata, newparent)
	newparent.append_new(newquest)


# Add a new quest with a given ID.
func add_new(newid: String) -> void:
	append_new(DQuest.new({"id": newid}, self))


# Append a new quest to the dictionary and save it to disk.
func append_new(newquest: DQuest) -> void:
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


# Removes a specific mobgroup from all quests.
# mobgroup_id: The ID of the mobgroup to be removed from the objectives or requirements of all quests.
func remove_mobgroup_from_all_quests(mobgroup_id: String) -> void:
	for quest: String in questdict.keys():
		remove_mobgroup_from_quest(quest, mobgroup_id)


# Removes all steps and rewards where the item property matches the given item_id
func remove_item_from_quest(quest_id: String, item_id: String) -> void:
	by_id(quest_id).remove_steps_by_item(item_id)
	by_id(quest_id).remove_rewards_by_item(item_id)


# Removes a specific item from all quests.
# item_id: The ID of the item to be removed from the objectives or requirements of all quests.
func remove_item_from_all_quests(item_id: String) -> void:
	for quest: String in questdict.keys():
		remove_item_from_quest(quest, item_id)


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Removes the reference from the selected itemgroup
func remove_reference(questid: String):
	references.erase(questid)
	Gamedata.mods.save_references(self)
