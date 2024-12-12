class_name DFurnitures
extends RefCounted

# There's a D in front of the class name to indicate this class only handles furniture data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of furnitures. You can access it trough Gamedata.mods.by_id("Core").furnitures


var dataPath: String = "./Mods/Core/Furniture/Furniture.json"
var filePath: String = "./Mods/Core/Furniture/Furniture.json"
var spritePath: String = "./Mods/Core/Furniture/"
var furnituredict: Dictionary = {}
var sprites: Dictionary = {}
var shader_materials: Dictionary = {}  # Cache for shader materials by furniture ID
var shape_materials: Dictionary = {}  # Cache for shape materials by furniture ID
var references: Dictionary = {}

# Add a mod_id parameter to dynamically initialize paths
func _init(mod_id: String) -> void:
	# Update dataPath and spritePath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/Furniture/"
	filePath = "./Mods/" + mod_id + "/Furniture/Furniture.json"
	spritePath = "./Mods/" + mod_id + "/Furniture/"
	load_sprites()
	load_furnitures_from_disk()
	load_references()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


func load_furnitures_from_disk() -> void:
	var furniturelist: Array = Helper.json_helper.load_json_array_file(filePath)
	for furnitureitem in furniturelist:
		var furniture: DFurniture = DFurniture.new(furnitureitem, self)
		if furniture.spriteid:
			furniture.sprite = sprites[furniture.spriteid]
		furnituredict[furniture.id] = furniture


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_furnitures_to_disk()

# Saves all furnitures to disk
func save_furnitures_to_disk() -> void:
	var save_data: Array = []
	for furniture in furnituredict.values():
		save_data.append(furniture.get_data())
	Helper.json_helper.write_json_file(filePath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return furnituredict


func duplicate_to_disk(furnitureid: String, newfurnitureid: String) -> void:
	var furnituredata: Dictionary = by_id(furnitureid).get_data().duplicate(true)
	# A duplicated furniture is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	furnituredata.erase("references")
	furnituredata.id = newfurnitureid
	var newfurniture: DFurniture = DFurniture.new(furnituredata, self)
	furnituredict[newfurnitureid] = newfurniture
	save_furnitures_to_disk()


func add_new(newid: String) -> void:
	var newfurniture: DFurniture = DFurniture.new({"id":newid}, self)
	furnituredict[newfurniture.id] = newfurniture
	save_furnitures_to_disk()


func delete_by_id(furnitureid: String) -> void:
	furnituredict[furnitureid].delete()
	furnituredict.erase(furnitureid)
	save_furnitures_to_disk()


func by_id(furnitureid: String) -> DFurniture:
	return furnituredict[furnitureid]


func has_id(furnitureid: String) -> bool:
	return furnituredict.has(furnitureid)

# Returns the sprite of the furniture
# furnitureid: The id of the furniture to return the sprite of
func sprite_by_id(furnitureid: String) -> Texture:
	return furnituredict[furnitureid].sprite

# Returns the sprite of the furniture
# furnitureid: The id of the furniture to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


func is_moveable(id: String) -> bool:
	return by_id(id).moveable


# Remove the provided itemgroup from all furniture
# This will erase it from destruction_group, disassembly_group and container_group
func remove_itemgroup_from_all_furniture(itemgroup_id: String):
	for furniture in furnituredict.values():
		furniture.remove_itemgroup(itemgroup_id)
