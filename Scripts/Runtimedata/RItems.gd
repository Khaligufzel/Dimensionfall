class_name RItems
extends RefCounted

# There's an R in front of the class name to indicate this class only handles runtime item data
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of items. You can access it through Runtime.mods.by_id("Core").items

# Runtime data for items and their sprites
var itemdict: Dictionary = {}  # Holds runtime item instances
var sprites: Dictionary = {}  # Holds item sprites
var shader_materials: Dictionary = {}  # Cache for shader materials by item ID

# Constructor
func _init(mod_list: Array[DMod]) -> void:
	# Loop through each mod
	for mod in mod_list:
		var ditems: DItems = mod.items

		# Loop through each DItem in the mod
		for ditem_id: String in ditems.get_all().keys():
			var ditem: DItem = ditems.by_id(ditem_id)

			# Check if the item exists in itemdict
			var ritem: RItem
			if not itemdict.has(ditem_id):
				# If it doesn't exist, create a new RItem
				ritem = add_new(ditem_id)
			else:
				# If it exists, get the existing RItem
				ritem = itemdict[ditem_id]

			# Overwrite the RItem properties with the DItem properties
			ritem.overwrite_from_ditem(ditem)
	save_items_protoset()

# Adds a new runtime item with a given ID
func add_new(newid: String) -> RItem:
	var new_item: RItem = RItem.new(self, newid)
	itemdict[new_item.id] = new_item
	return new_item

# Deletes an item by its ID
func delete_by_id(itemid: String) -> void:
	itemdict[itemid].delete()
	itemdict.erase(itemid)

# Returns a runtime item by its ID
func by_id(itemid: String) -> RItem:
	return itemdict[itemid]

# Checks if an item exists by its ID
func has_id(itemid: String) -> bool:
	return itemdict.has(itemid)

# Returns the sprite of the item
func sprite_by_id(itemid: String) -> Texture:
	return itemdict[itemid].sprite

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


# Filters items by type. Returns a list of items of that type
# item_type: Any of craft, magazine, ranged, melee, food, wearable
func get_items_by_type(item_type: String) -> Array[RItem]:
	var filtered_items: Array[RItem] = []
	for item in itemdict.values():
		if not item.get(item_type) == null:
			filtered_items.append(item)
	return filtered_items


# New function to get or create a ShaderMaterial for a item ID
func get_shader_material_by_id(item_id: String) -> ShaderMaterial:
	# Check if the material already exists
	if shader_materials.has(item_id):
		return shader_materials[item_id]
	else:
		# Create a new ShaderMaterial
		var albedo_texture: Texture = sprite_by_id(item_id)
		var shader_material: ShaderMaterial = create_item_shader_material(albedo_texture)
		# Store it in the dictionary
		shader_materials[item_id] = shader_material
		return shader_material


# Helper function to create a ShaderMaterial for the item
func create_item_shader_material(albedo_texture: Texture) -> ShaderMaterial:
	# Create a new ShaderMaterial
	var shader_material = ShaderMaterial.new()
	shader_material.shader = Gamedata.hide_above_player_shader  # Use the shared shader

	# Assign the texture to the material
	shader_material.set_shader_parameter("texture_albedo", albedo_texture)

	return shader_material


# Handle the game ended signal. We need to clear the shader materials because they
# need to be re-created on game start since some of them may have changed in between.
func _on_game_ended():
	# Loop through all shader materials and free them
	for material in shader_materials.values():
		material.free()
	# Clear the dictionary
	shader_materials.clear()


# This will update the given resource file with the provided json data
# It is intended to save item data from json to the res://ItemProtosets.tres file
# So we can use the item json data in-game
func update_item_protoset_json_data(tres_path: String, new_json_data: String) -> void:
	# Load the ItemProtoset resource
	var item_protoset = load(tres_path) as ItemProtoset
	if not item_protoset:
		print_debug("Failed to load ItemProtoset resource from:", tres_path)
		return

	# Update the json_data property
	item_protoset.json_data = new_json_data

	# Save the resource back to the .tres file
	var save_result = ResourceSaver.save(item_protoset, tres_path)
	if save_result != OK:
		print_debug("Failed to save updated ItemProtoset resource to:", tres_path)
	else:
		print_debug("ItemProtoset resource updated and saved successfully to:", tres_path)


# Saves the items protoset to disk. We need to do this for the Gloot addon
# This will remain the case until https://github.com/peter-kish/gloot/issues/194 is solved.
func save_items_protoset() -> void:
	var save_data: Array = []
	for item: RItem in itemdict.values():
		save_data.append(item.get_data())
	update_item_protoset_json_data("res://ItemProtosets.tres", JSON.stringify(save_data, "\t"))

func get_first_recipe_by_id(item_id: String) -> RItem.CraftRecipe:
	return by_id(item_id).get_first_recipe()


# Returns a list of items that are hand-craftable.
# These items must have the craft property and at least one recipe with the "hand_craftable" flag set to true.
func get_hand_craftable_items() -> Array[RItem]:
	var hand_craftable_items: Array[RItem] = []

	for item: RItem in itemdict.values():
		# Check if the item has the `craft` property and at least one recipe
		if not item.get("craft") == null and item.craft.recipes.size() > 0:
			# Check if any recipe has the "hand_craftable" flag set to true
			for recipe: RItem.CraftRecipe in item.craft.recipes:
				if recipe.get("flags") == null:
					hand_craftable_items.append(item)
					break  # The item has no flags so assume it's hand craftable
				elif recipe.flags.get("hand_craftable", true):
					hand_craftable_items.append(item)
					break  # Exit the loop as we only need one matching recipe

	return hand_craftable_items
