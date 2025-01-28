class_name DTiles
extends RefCounted

# There's a D in front of the class name to indicate this class only handles tile data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of tiles. You can access it trough Gamedata.mods.by_id("Core").tiles


var dataPath: String = "./Mods/Core/Tiles/"
var filePath: String = "./Mods/Core/Tiles/Tiles.json"
var spritePath: String = "./Mods/Core/Tiles/"
var tiledict: Dictionary = {}
var sprites: Dictionary = {}
var references: Dictionary = {}
var mod_id: String = "Core"


# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Tiles/"
	filePath = "./Mods/" + mod_id + "/Tiles/Tiles.json"
	spritePath = "./Mods/" + mod_id + "/Tiles/"
	load_sprites()
	load_tiles_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all tiledata from disk into memory
func load_tiles_from_disk() -> void:
	var tilelist: Array = Helper.json_helper.load_json_array_file(filePath)
	for mytile in tilelist:
		var tile: DTile = DTile.new(mytile, self)
		if tile.spriteid:
			tile.sprite = sprites[tile.spriteid]
		tiledict[tile.id] = tile


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_tiles_to_disk()


# Saves all tiles to disk
func save_tiles_to_disk() -> void:
	var save_data: Array = []
	for tile in tiledict.values():
		save_data.append(tile.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return tiledict


# Duplicate the tile to disk. A new mod id may be provided to save the duplicate to.
# tileid: The tile to duplicate.
# newtileid: The id of the new duplicate (can be the same as tileid if new_mod_id equals mod_id).
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id.
func duplicate_to_disk(tileid: String, newtileid: String, new_mod_id: String) -> void:
	# Duplicate the tile data and set the new id
	var tiledata: Dictionary = by_id(tileid).get_data().duplicate(true)
	tiledata.id = newtileid

	# Determine the new parent based on the new_mod_id
	var newparent: DTiles = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).tiles

	# Instantiate and append the new DTile instance
	var newtile: DTile = DTile.new(tiledata, newparent)
	if tiledata.has("sprite"):
		newtile.sprite = newparent.sprite_by_file(tiledata["sprite"])
	newparent.append_new(newtile)


# Add a new tile to the dictionary and save it to disk.
func add_new(newid: String) -> void:
	append_new(DTile.new({"id": newid}, self))


# Append a new tile to the dictionary and save it to disk.
func append_new(newtile: DTile) -> void:
	tiledict[newtile.id] = newtile
	save_tiles_to_disk()



func delete_by_id(tileid: String) -> void:
	tiledict[tileid].delete()
	tiledict.erase(tileid)
	save_tiles_to_disk()


func by_id(tileid: String) -> DTile:
	return tiledict[tileid]


func has_id(tileid: String) -> bool:
	return tiledict.has(tileid)


# Returns the sprite of the tile
# tileid: The id of the tile to return the sprite of
func sprite_by_id(tileid: String) -> Texture:
	return tiledict[tileid].sprite

# Returns the sprite of the tile
# tileid: The id of the tile to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]
