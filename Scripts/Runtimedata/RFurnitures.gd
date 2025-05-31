class_name RFurnitures
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime furniture data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of furniture. You can access it through Runtime.mods.by_id("Core").furnitures

# Properties for runtime furniture data and sprites
var furnituredict: Dictionary = {}  # Holds runtime furniture instances
var sprites: Dictionary = {}  # Holds furniture sprites
var shape_materials: Dictionary = {}  # Cache for shape materials by furniture ID
var standard_materials: Dictionary = {}  # Cache for standard materials by furniture ID
var under_construction_material: StandardMaterial3D

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


# ✅ Updated function to return StandardMaterial3D instead of ShaderMaterial
func get_shape_material_by_id(furniture_id: String) -> StandardMaterial3D:
	if shape_materials.has(furniture_id):
		return shape_materials[furniture_id]
	else:
		var material: StandardMaterial3D = create_shape_material(furniture_id)
		shape_materials[furniture_id] = material
		return material

# ✅ Updated helper function to create a StandardMaterial3D for the support shape
func create_shape_material(furniture_id: String) -> StandardMaterial3D:
	var rfurniture: RFurniture = by_id(furniture_id)
	if rfurniture.moveable:  # Only static furniture has a support shape
		return null
	
	var color = Color.html(rfurniture.support_shape.color)
	var material: StandardMaterial3D = StandardMaterial3D.new()

	if rfurniture.support_shape.transparent:
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.5
	else:
		material.albedo_color = color
	return material


# Handle the game ended signal to clear shader materials
func _on_game_ended():
	shape_materials.clear()
	standard_materials.clear()


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


# ✅ Helper function to create a StandardMaterial3D for furniture under construction
func create_under_construction_material() -> StandardMaterial3D:
	# Create a new StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	
	# Set base color to light blue tint to indicate construction
	material.albedo_color = Color(0.5, 0.7, 1.0) 
	
	# Set transparency (use alpha blending mode)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.7
	
	# Optionally adjust other material properties for better visual distinction
	material.flags_unshaded = true
	material.flags_use_point_size = false
	
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
