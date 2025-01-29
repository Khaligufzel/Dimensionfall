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
var mod_id: String = "Core"

# Add a mod_id parameter to dynamically initialize paths
func _init(new_mod_id: String) -> void:
	mod_id = new_mod_id
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
		if furniture.spriteid and sprites.has(furniture.spriteid):
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


# Duplicate the furniture to disk. A new mod id may be provided to save the duplicate to
# furnitureid: The furniture to duplicate
# newfurnitureid: The id of the new duplicate (can be the same as furnitureid if new_mod_id equals mod_id)
# new_mod_id: The id of the mod that the duplicate will be entered into. May differ from mod_id
func duplicate_to_disk(furnitureid: String, newfurnitureid: String, new_mod_id: String) -> void:
	# Duplicate the furniture data and set the new id
	var furnituredata: Dictionary = by_id(furnitureid).get_data().duplicate(true)
	furnituredata.id = newfurnitureid
	# Determine the new parent based on the new_mod_id
	var newparent: DFurnitures = self if new_mod_id == mod_id else Gamedata.mods.by_id(new_mod_id).furnitures
	# Instantiate and append the new DFurniture instance
	var newfurniture: DFurniture = DFurniture.new(furnituredata, newparent)
	if furnituredata.has("sprite"):
		newfurniture.sprite = newparent.sprite_by_file(furnituredata["sprite"])
	newparent.append_new(newfurniture)


func add_new(newid: String) -> void:
	append_new(DFurniture.new({"id":newid}, self))


func append_new(newfurniture: DFurniture) -> void:
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
	return sprites[spritefile] if sprites.has(spritefile) else null


func is_moveable(id: String) -> bool:
	return by_id(id).moveable


# Remove the provided itemgroup from all furniture
# This will erase it from destruction_group, disassembly_group and container_group
func remove_itemgroup_from_all_furniture(itemgroup_id: String):
	for furniture in furnituredict.values():
		furniture.remove_itemgroup(itemgroup_id)


# Remove the provided item from all furniture
# This will erase it from crating.items
func remove_item_from_all_furniture(item_id: String):
	for furniture in furnituredict.values():
		furniture.remove_item(item_id)


# Removes the reference of the selected furniture
func remove_reference(furniture_id: String):
	references.erase(furniture_id)
	Gamedata.mods.save_references(self)

# Remove the provided furniture_id from all furniture's consumption.transform_into
func remove_furniture_from_all_furniture(furniture_id: String):
	for furniture in furnituredict.values():
		furniture.remove_furniture(furniture_id)
