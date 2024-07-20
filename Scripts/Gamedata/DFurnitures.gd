class_name DFurnitures
extends RefCounted

# There's a D in front of the class name to indicate this class only handles furniture data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of furnitures. You can access it trough Gamedata.furnitures


var dataPath: String = "./Mods/Core/Furniture/Furniture.json"
var furnituredict: Dictionary = {}


func _init():
	load_furnitures_from_disk()


# Load all furnituredata from disk into memory
func load_furnitures_from_disk() -> void:
	var furniturelist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for furnitureitem in furniturelist:
		var furniture: DFurniture = DFurniture.new(furnitureitem)
		furnituredict[furniture.id] = furniture


func get_furnitures() -> Dictionary:
	return furnituredict


func duplicate_furniture_to_disk(furnitureid: String, newfurnitureid: String) -> void:
	var furnituredata: Dictionary = furnituredict[furnitureid].get_data().duplicate(true)
	furnituredata.id = newfurnitureid
	var newfurniture: DFurniture = DFurniture.new(furnituredata)
	furnituredict[newfurnitureid] = newfurniture
	save_data_to_disk()


func add_new_furniture(newdata: Dictionary) -> void:
	var newfurniture: DFurniture = DFurniture.new(newdata)
	furnituredict[newfurniture.id] = newfurniture
	save_data_to_disk()


func save_data_to_disk():
	var furniture_data_json = JSON.stringify(furnituredict, "\t")
	Helper.json_helper.write_json_file(dataPath, furniture_data_json)
	

func delete_furniture(furnitureid: String) -> void:
	furnituredict[furnitureid].delete()
	furnituredict.erase(furnitureid)


func by_id(furnitureid: String) -> DFurniture:
	return furnituredict[furnitureid]


# Removes the reference from the selected furniture
func remove_reference_from_furniture(furnitureid: String, module: String, type: String, refid: String):
	var myfurniture: DFurniture = furnituredict[furnitureid]
	myfurniture.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# furnitureid: The id of the furniture to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference_to_furniture(furnitureid: String, module: String, type: String, refid: String):
	var myfurniture: DFurniture = furnituredict[furnitureid]
	myfurniture.add_reference(module, type, refid)
