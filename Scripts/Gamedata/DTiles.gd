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


# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
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


func duplicate_to_disk(tileid: String, newtileid: String) -> void:
	var tiledata: Dictionary = by_id(tileid).get_data().duplicate(true)
	# A duplicated tile is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	tiledata.erase("references")
	tiledata.id = newtileid
	var newtile: DTile = DTile.new(tiledata, self)
	tiledict[newtileid] = newtile
	save_tiles_to_disk()


func add_new(newid: String) -> void:
	var newtile: DTile = DTile.new({"id":newid}, self)
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
