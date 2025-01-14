class_name DPlayerAttributes
extends RefCounted

# There's a D in front of the class name to indicate this class only handles player attribute
# data, nothing more. This script is intended to be used inside the GameData autoload singleton
# This script handles the list of playerattributes. You can access it trough Gamedata.mods.by_id("Core").playerattributes


var dataPath: String = "./Mods/Core/PlayerAttributes/"
var filePath: String = "./Mods/Core/PlayerAttributes/PlayerAttributes.json"
var spritePath: String = "./Mods/Core/PlayerAttributes/"
var playerattributedict: Dictionary = {}
var sprites: Dictionary = {}
var hardcoded: Array = ["player_inventory"]
var references: Dictionary = {}
var mod_id: String = "Core"


# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/PlayerAttributes/"
	filePath = "./Mods/" + mod_id + "/PlayerAttributes/PlayerAttributes.json"
	spritePath = "./Mods/" + mod_id + "/PlayerAttributes/"
	
	load_sprites()
	load_playerattributes_from_disk()
	load_references()

# Load all playerattributedata from disk into memory
func load_playerattributes_from_disk() -> void:
	var playerattributelist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myattribute in playerattributelist:
		var playerattribute: DPlayerAttribute = DPlayerAttribute.new(myattribute, self)
		if sprites.has(playerattribute.spriteid):
			playerattribute.sprite = sprites[playerattribute.spriteid]
		playerattributedict[playerattribute.id] = playerattribute


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
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_playerattributes_to_disk()


# Saves all playerattributes to disk
func save_playerattributes_to_disk() -> void:
	var save_data: Array = []
	for playerattribute in playerattributedict.values():
		save_data.append(playerattribute.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return playerattributedict


# Duplicate the player attribute to disk. A new mod id may be provided to save the duplicate to.
# playerattributeid: The player attribute to duplicate.
# newplayerattributeid: The id of the new duplicate (can be the same as playerattributeid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(playerattributeid: String, newplayerattributeid: String, new_mod_id: String) -> void:
	# Duplicate the player attribute data and set the new id
	var playerattributedata: Dictionary = by_id(playerattributeid).get_data().duplicate(true)
	playerattributedata.id = newplayerattributeid

	# Determine the new parent based on the new_mod_id
	var newparent: DPlayerAttributes = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).playerattributes

	# Instantiate and append the new DPlayerAttribute instance
	var newplayerattribute: DPlayerAttribute = DPlayerAttribute.new(playerattributedata, newparent)
	newparent.append_new(newplayerattribute)


# Add a new player attribute to the dictionary and save it to disk.
func add_new(newid: String) -> void:
	append_new(DPlayerAttribute.new({"id": newid}, self))


# Append a new player attribute to the dictionary and save it to disk.
func append_new(newplayerattribute: DPlayerAttribute) -> void:
	playerattributedict[newplayerattribute.id] = newplayerattribute
	save_playerattributes_to_disk()



func delete_by_id(playerattributeid: String) -> void:
	playerattributedict[playerattributeid].delete()
	playerattributedict.erase(playerattributeid)
	save_playerattributes_to_disk()


func by_id(playerattributeid: String) -> DPlayerAttribute:
	return playerattributedict[playerattributeid]


func has_id(playerattributeid: String) -> bool:
	return playerattributedict.has(playerattributeid)


# Returns the sprite of the playerattribute
# playerattributeid: The id of the playerattribute to return the sprite of
func sprite_by_id(playerattributeid: String) -> Texture:
	return playerattributedict[playerattributeid].sprite

# Returns the sprite of the playerattribute
# playerattributeid: The id of the playerattribute to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Removes the reference from the selected itemgroup
func remove_reference(playerattributeid: String):
	references.erase(playerattributeid)
	Gamedata.mods.save_references(self)
