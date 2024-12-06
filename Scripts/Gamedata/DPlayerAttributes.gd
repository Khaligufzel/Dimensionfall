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


# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/PlayerAttributes/"
	filePath = "./Mods/" + mod_id + "/PlayerAttributes/PlayerAttributes.json"
	spritePath = "./Mods/" + mod_id + "/PlayerAttributes/"
	
	load_sprites()
	load_playerattributes_from_disk()


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


func duplicate_to_disk(playerattributeid: String, newplayerattributeid: String) -> void:
	var playerattributedata: Dictionary = by_id(playerattributeid).get_data().duplicate(true)
	# A duplicated playerattribute is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	playerattributedata.erase("references")
	playerattributedata.id = newplayerattributeid
	var newplayerattribute: DPlayerAttribute = DPlayerAttribute.new(playerattributedata, self)
	playerattributedict[newplayerattributeid] = newplayerattribute
	save_playerattributes_to_disk()


func add_new(newid: String) -> void:
	var newplayerattribute: DPlayerAttribute = DPlayerAttribute.new({"id":newid}, self)
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


# Removes the reference from the selected playerattribute
func remove_reference(playerattributeid: String, module: String, type: String, refid: String):
	var myplayerattribute: DPlayerAttribute = playerattributedict[playerattributeid]
	myplayerattribute.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# playerattributeid: The id of the playerattribute to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(playerattributeid: String, module: String, type: String, refid: String):
	var myplayerattribute: DPlayerAttribute = playerattributedict[playerattributeid]
	myplayerattribute.add_reference(module, type, refid)
