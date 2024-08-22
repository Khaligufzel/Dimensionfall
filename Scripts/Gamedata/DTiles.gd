class_name DTiles
extends RefCounted

# There's a D in front of the class name to indicate this class only handles tile data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of tiles. You can access it trough Gamedata.tiles


var dataPath: String = "./Mods/Core/Tiles/Tiles.json"
var spritePath: String = "./Mods/Core/Tiles/"
var tiledict: Dictionary = {}
var sprites: Dictionary = {}


func _init():
	load_sprites()
	load_tiles_from_disk()


# Load all tiledata from disk into memory
func load_tiles_from_disk() -> void:
	var tilelist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for mytile in tilelist:
		var tile: DTile = DTile.new(mytile)
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
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))


func get_tiles() -> Dictionary:
	return tiledict


func duplicate_tile_to_disk(tileid: String, newtileid: String) -> void:
	var tiledata: Dictionary = tiledict[tileid].get_data().duplicate(true)
	tiledata.id = newtileid
	var newtile: DTile = DTile.new(tiledata)
	tiledict[newtileid] = newtile
	save_tiles_to_disk()


func add_new_tile(newid: String) -> void:
	var newtile: DTile = DTile.new({"id":newid})
	tiledict[newtile.id] = newtile
	save_tiles_to_disk()


func delete_tile(tileid: String) -> void:
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


# Removes the reference from the selected tile
func remove_reference_from_tile(tileid: String, module: String, type: String, refid: String):
	var mytile: DTile = tiledict[tileid]
	mytile.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# tileid: The id of the tile to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference_to_tile(tileid: String, module: String, type: String, refid: String):
	var mytile: DTile = tiledict[tileid]
	mytile.add_reference(module, type, refid)
