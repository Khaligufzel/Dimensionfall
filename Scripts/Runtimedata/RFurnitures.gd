class_name RFurnitures
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime furniture data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of furniture. You can access it through Runtime.mods.by_id("Core").furnitures

# Properties for runtime furniture data and sprites
var furnituredict: Dictionary = {}  # Holds runtime furniture instances
var sprites: Dictionary = {}  # Holds furniture sprites
var shader_materials: Dictionary = {}  # Cache for shader materials by furniture ID
var shape_materials: Dictionary = {}  # Cache for shape materials by furniture ID
var standard_materials: Dictionary = {}  # Cache for standard materials by furniture ID
var under_construction_material: ShaderMaterial

# Constructor
func _init(mod_list: Array[DMod]) -> void:
	# Loop through each mod
	for mod in mod_list:
		var dfurnitures: DFurnitures = mod.furnitures

		# Loop through each DFurniture in the mod
		for dfurniture_id: String in dfurnitures.get_all().keys():
			var dfurniture: DFurniture = dfurnitures.by_id(dfurniture_id)

			# Check if the furniture exists in furnituredict
			var rfurniture: RFurniture
			if not furnituredict.has(dfurniture_id):
				# If it doesn't exist, create a new RFurniture
				rfurniture = add_new(dfurniture_id)
			else:
				# If it exists, get the existing RFurniture
				rfurniture = furnituredict[dfurniture_id]

			# Overwrite the RFurniture properties with the DFurniture properties
			rfurniture.overwrite_from_dfurniture(dfurniture)
	under_construction_material = create_under_construction_material()

# Adds a new runtime furniture with a given ID
func add_new(newid: String) -> RFurniture:
	var new_furniture: RFurniture = RFurniture.new(self, newid)
	furnituredict[new_furniture.id] = new_furniture
	return new_furniture

# Deletes a furniture by its ID
func delete_by_id(furnitureid: String) -> void:
	furnituredict[furnitureid].delete()
	furnituredict.erase(furnitureid)

# Returns a runtime furniture by its ID
func by_id(furnitureid: String) -> RFurniture:
	return furnituredict[furnitureid]

# Checks if a furniture exists by its ID
func has_id(furnitureid: String) -> bool:
	return furnituredict.has(furnitureid)

# Returns the sprite of the furniture
func sprite_by_id(furnitureid: String) -> Texture:
	return furnituredict[furnitureid].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites.get(spritefile, null)

# Loads sprites and assigns them to the proper dictionary
func load_sprites(sprite_path: String) -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(sprite_path, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(sprite_path + png_file)
		# Add the texture to the dictionary
		sprites[png_file] = texture

# New function to get or create a ShaderMaterial for a furniture ID
func get_shader_material_by_id(furniture_id: String) -> ShaderMaterial:
	if shader_materials.has(furniture_id):
		return shader_materials[furniture_id]
	else:
		# Create a new ShaderMaterial
		var shader_material: ShaderMaterial = create_furniture_shader_material(furniture_id)
		shader_materials[furniture_id] = shader_material
		return shader_material

# Helper function to create a ShaderMaterial for the furniture
func create_furniture_shader_material(furniture_id: String) -> ShaderMaterial:
	var rfurniture: RFurniture = by_id(furniture_id)
	var albedo_texture: Texture = rfurniture.sprite
	var shader_material = ShaderMaterial.new()
	shader_material.shader = Gamedata.hide_above_player_shader  # Use the shared shader

	# Assign the texture to the material
	shader_material.set_shader_parameter("texture_albedo", albedo_texture)

	return shader_material

# New function to get or create a visual instance material for a furniture ID
func get_shape_material_by_id(furniture_id: String) -> ShaderMaterial:
	if shape_materials.has(furniture_id):
		return shape_materials[furniture_id]
	else:
		var material: ShaderMaterial = create_shape_material(furniture_id)
		shape_materials[furniture_id] = material
		return material

# Helper function to create a ShaderMaterial for the support shape
func create_shape_material(furniture_id: String) -> ShaderMaterial:
	var rfurniture: RFurniture = by_id(furniture_id)
	if rfurniture.moveable:  # Only static furniture has a support shape
		return null
	var color = Color.html(rfurniture.support_shape.color)
	var material: ShaderMaterial = ShaderMaterial.new()

	if rfurniture.support_shape.transparent:
		material.shader = Gamedata.hide_above_player_shader
		material.set_shader_parameter("object_color", color)
		material.set_shader_parameter("alpha", 0.5)
	else:
		material.shader = Gamedata.hide_above_player_shadow
		material.set_shader_parameter("object_color", color)
		material.set_shader_parameter("alpha", 1.0)

	return material

# Handle the game ended signal to clear shader materials
func _on_game_ended():
	shader_materials.clear()
	shape_materials.clear()


func is_moveable(id: String) -> bool:
	return by_id(id).moveable


# Returns a list of all RFurniture instances that have construction items
func get_constructable_furnitures() -> Array[RFurniture]:
	var constructable_furnitures: Array[RFurniture] = []
	
	for furniture in furnituredict.values():
		# Check if the furniture has construction items
		if not furniture.get_construction_items().is_empty():
			constructable_furnitures.append(furniture)
	
	return constructable_furnitures


# Helper function to create a ShaderMaterial for furniture under construction
func create_under_construction_material() -> ShaderMaterial:
	# Create a new ShaderMaterial
	var material: ShaderMaterial = ShaderMaterial.new()
	
	# Assign the hide_above_player_shader
	material.shader = Gamedata.hide_above_player_shader
	
	# Set shader parameters
	material.set_shader_parameter("object_color", Color(0.5, 0.7, 1.0))  # Light blue tint to indicate construction
	material.set_shader_parameter("alpha", 0.7)  # Semi-transparent to distinguish under-construction state
	
	return material


# New function to get or create a StandardMaterial3D for a furniture ID
func get_standard_material_by_id(furniture_id: String) -> StandardMaterial3D:
	if standard_materials.has(furniture_id):  # Reuse the dictionary for storing StandardMaterial3D
		return standard_materials[furniture_id]
	else:
		var material: StandardMaterial3D = create_standard_material(furniture_id)
		standard_materials[furniture_id] = material
		return material

# Helper function to create a StandardMaterial3D for a furniture ID
func create_standard_material(furniture_id: String) -> StandardMaterial3D:
	var rfurniture: RFurniture = by_id(furniture_id)
	var albedo_texture: Texture = rfurniture.sprite
	
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = albedo_texture  # Set the furniture sprite
	material.flags_transparent = true

	return material
