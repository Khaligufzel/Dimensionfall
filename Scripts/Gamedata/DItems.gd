class_name DItems
extends RefCounted

# There's a D in front of the class name to indicate this class only handles item data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of items. You can access it trough Gamedata.items


var dataPath: String = "./Mods/Core/Items/Items.json"
var spritePath: String = "./Mods/Core/Items/"
var itemdict: Dictionary = {}
var sprites: Dictionary = {}
var shader_materials: Dictionary = {}  # Cache for shader materials by item ID


func _init():
	load_sprites()
	load_items_from_disk()


# Load all itemdata from disk into memory
func load_items_from_disk() -> void:
	var itemlist: Array = Helper.json_helper.load_json_array_file(dataPath)
	for myitem in itemlist:
		var item: DItem = DItem.new(myitem)
		if myitem.has("sprite"):
			item.sprite = sprites[item.spriteid]
		itemdict[item.id] = item


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	var png_files: Array = Helper.json_helper.file_names_in_dir(spritePath, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(spritePath + png_file) 
		# Add the material to the dictionary
		sprites[png_file] = texture


func on_data_changed():
	save_items_to_disk()


# Saves all items to disk
func save_items_to_disk() -> void:
	var save_data: Array = []
	for item in itemdict.values():
		save_data.append(item.get_data())
	Helper.json_helper.write_json_file(dataPath, JSON.stringify(save_data, "\t"))
	update_item_protoset_json_data("res://ItemProtosets.tres", JSON.stringify(save_data, "\t"))


func get_all() -> Dictionary:
	return itemdict


func duplicate_to_disk(itemid: String, newitemid: String) -> void:
	var itemdata: Dictionary = by_id(itemid).get_data().duplicate(true)
	# A duplicated item is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	itemdata.erase("references")
	itemdata.id = newitemid
	var newitem: DItem = DItem.new(itemdata)
	itemdict[newitemid] = newitem
	save_items_to_disk()


func add_new(newid: String) -> void:
	var newitem: DItem = DItem.new({"id":newid})
	itemdict[newitem.id] = newitem
	save_items_to_disk()


func delete_by_id(itemid: String) -> void:
	itemdict[itemid].delete()
	itemdict.erase(itemid)
	save_items_to_disk()


func by_id(itemid: String) -> DItem:
	return itemdict[itemid]


func has_id(itemid: String) -> bool:
	return itemdict.has(itemid)


# Returns the sprite of the item
# itemid: The id of the item to return the sprite of
func sprite_by_id(itemid: String) -> Texture:
	return itemdict[itemid].sprite

# Returns the sprite of the item
# itemid: The id of the item to return the sprite of
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Removes the reference from the selected item
func remove_reference(itemid: String, module: String, type: String, refid: String):
	var myitem: DItem = itemdict[itemid]
	myitem.remove_reference(module, type, refid)


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# itemid: The id of the item to add the reference to
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity to reference, for example "grass_field"
func add_reference(itemid: String, module: String, type: String, refid: String):
	var myitem: DItem = itemdict[itemid]
	myitem.add_reference(module, type, refid)


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


# Filters items by type. Returns a list of items of that type
# item_type: Any of craft, magazine, ranged, melee, food, wearable
func get_items_by_type(item_type: String) -> Array[DItem]:
	var filtered_items: Array[DItem] = []
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
