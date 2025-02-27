class_name DAttacks
extends RefCounted

# There's a D in front of the class name to indicate this class only handles attacks data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of attacs. You can access it through Gamedata.mods.by_id("Core").attacks

# Paths for attacks data and sprites
var dataPath: String = "./Mods/Core/Attacks/"
var filePath: String = "./Mods/Core/Attacks/Attacks.json"
var spritePath: String = "./Mods/Core/Attacks/"
var attackdict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Attacks/"
	filePath = "./Mods/" + mod_id + "/Attacks/Attacks.json"
	spritePath = "./Mods/" + mod_id + "/Attacks/"
	
	# Load attacks and sprites
	load_sprites()
	load_attacks_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all attacks data from disk into memory
func load_attacks_from_disk() -> void:
	var attackslist: Array = Helper.json_helper.load_json_array_file(filePath)
	for myattack in attackslist:
		var attack: DAttack = DAttack.new(myattack, self)
		if attack.spriteid:
			attack.sprite = sprites[attack.spriteid]
		attackdict[attack.id] = attack

# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file)
		# Add the material to the dictionary
		sprites[png_file] = texture

# Called when data changes and needs to be saved
func on_data_changed():
	save_attacks_to_disk()

# Saves all attacks to disk
func save_attacks_to_disk() -> void:
	var save_data: Array = []
	for attack in attackdict.values():
		save_data.append(attack.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))

# Returns the dictionary containing all attacks
func get_all() -> Dictionary:
	return attackdict


# Duplicate the attack to disk. A new mod id may be provided to save the duplicate to.
# attackid: The attack to duplicate.
# newstatid: The id of the new duplicate (can be the same as attackid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(attackid: String, newstatid: String, new_mod_id: String) -> void:
	# Duplicate the attack data and set the new id
	var attackdata: Dictionary = by_id(attackid).get_data().duplicate(true)
	attackdata["id"] = newstatid

	# Determine the new parent based on the new_mod_id
	var newparent: DAttacks = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).attacks

	# Instantiate and append the new DAttack instance
	var newattack: DAttack = DAttack.new(attackdata, newparent)
	if attackdata.has("sprite"):
		newattack.sprite = newparent.sprite_by_file(attackdata["sprite"])
	newparent.append_new(newattack)


# Add a new attack with a given ID.
func add_new(newid: String) -> void:
	append_new(DAttack.new({"id": newid}, self))


# Append a new attack to the dictionary and save it to disk.
func append_new(newattack: DAttack) -> void:
	attackdict[newattack.id] = newattack
	save_attacks_to_disk()


# Deletes a attack by its ID and saves changes to disk
func delete_by_id(attackid: String) -> void:
	attackdict[attackid].delete()
	attackdict.erase(attackid)
	save_attacks_to_disk()

# Returns a attack by its ID
func by_id(attackid: String) -> DAttack:
	return attackdict[attackid]

# Checks if a attack exists by its ID
func has_id(attackid: String) -> bool:
	return attackdict.has(attackid)

# Returns the sprite of the attack
func sprite_by_id(attackid: String) -> Texture:
	return attackdict[attackid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]
