class_name DFurnitures
extends RefCounted

# There's a D in front of the class name to indicate this class only handles furniture data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of furnitures. You can access it trough Gamedata.furnitures


var dataPath: String = "./Mods/Core/Furniture/Furniture.json"
var spritePath: String = "./Mods/Core/Furniture/"
var furnituredict: Dictionary = {}
var sprites: Dictionary = {}
var shader_materials: Dictionary = {}  # Cache for shader materials by furniture ID
var shape_materials: Dictionary = {}  # Cache for shape materials by furniture ID

func _init():
	load_sprites()
	load_furnitures_from_disk()
	Helper.signal_broker.game_ended.connect(_on_game_ended)


func load_furnitures_from_disk() -> void:
	var furniturelist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for furnitureitem in furniturelist:
		var furniture: DFurniture = DFurniture.new(furnitureitem)
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
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return furnituredict


func duplicate_to_disk(furnitureid: String, newfurnitureid: String) -> void:
	var furnituredata: Dictionary = by_id(furnitureid).get_data().duplicate(true)
	# A duplicated furniture is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	furnituredata.erase("references")
	furnituredata.id = newfurnitureid
	var newfurniture: DFurniture = DFurniture.new(furnituredata)
	furnituredict[newfurnitureid] = newfurniture
	save_furnitures_to_disk()


func add_new(newid: String) -> void:
	var newfurniture: DFurniture = DFurniture.new({"id":newid})
	furnituredict[newfurniture.id] = newfurniture
	save_furnitures_to_disk()


func delete_by_id(furnitureid: String) -> void:
	furnituredict[furnitureid].delete()
	furnituredict.erase(furnitureid)
	save_furnitures_to_disk()


func by_id(furnitureid: String) -> DFurniture:
	return furnituredict[furnitureid]


# Returns the sprite of the furniture
# furnitureid: The id of the furniture to return the sprite of
func sprite_by_id(furnitureid: String) -> Texture:
	return furnituredict[furnitureid].sprite

# Returns the sprite of the furniture
# furnitureid: The id of the furniture to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


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


func is_moveable(id: String) -> bool:
	return by_id(id).moveable


# New function to get or create a ShaderMaterial for a furniture ID
func get_shader_material_by_id(furniture_id: String) -> ShaderMaterial:
	# Check if the material already exists
	if shader_materials.has(furniture_id):
		return shader_materials[furniture_id]
	else:
		# Create a new ShaderMaterial
		var shader_material: ShaderMaterial = create_furniture_shader_material(furniture_id)
		# Store it in the dictionary
		shader_materials[furniture_id] = shader_material
		return shader_material


# Helper function to create a ShaderMaterial for the furniture
func create_furniture_shader_material(furniture_id: String) -> ShaderMaterial:
	# Create a new ShaderMaterial
	var dfurniture: DFurniture = by_id(furniture_id)
	var albedo_texture: Texture = dfurniture.sprite
	var shader_material = ShaderMaterial.new()
	shader_material.shader = Gamedata.hide_above_player_shader  # Use the shared shader

	# Assign the texture to the material
	shader_material.set_shader_parameter("texture_albedo", albedo_texture)

	return shader_material


# New function to get or create a visual instance material for a furniture ID
func get_shape_material_by_id(furniture_id: String) -> ShaderMaterial:
	# Check if the material already exists
	if shape_materials.has(furniture_id):
		return shape_materials[furniture_id]
	else:
		# Create a new ShaderMaterial
		var material: ShaderMaterial = create_shape_material(furniture_id)
		# Store it in the dictionary
		shape_materials[furniture_id] = material
		return material


# Helper function to create a ShaderMaterial for the support shape
func create_shape_material(furniture_id: String) -> ShaderMaterial:
	var dfurniture: DFurniture = by_id(furniture_id)
	if dfurniture.moveable: # Only static furniture has a support shape
		return null
	var color = Color.html(dfurniture.support_shape.color)
	var material: ShaderMaterial = ShaderMaterial.new()

	# Determine the shader and parameters based on transparency
	if dfurniture.support_shape.transparent:
		material.shader = Gamedata.hide_above_player_shader  # Assign the shader
		material.set_shader_parameter("object_color", color)
		material.set_shader_parameter("alpha", 0.5)
	else:
		material.shader = Gamedata.hide_above_player_shadow  # Assign the shadow shader
		material.set_shader_parameter("object_color", color)
		material.set_shader_parameter("alpha", 1.0)

	return material


# Handle the game ended signal. We need to clear the shader materials because they
# need to be re-created on game start since some of them may have changed in between.
func _on_game_ended():
	# Clear the dictionary
	shader_materials.clear()
