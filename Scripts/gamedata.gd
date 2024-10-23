extends Node

# Autoload singleton that loads all game data required to run the game
# Accessible via Gamedata.property
var data: Dictionary = {"overmaptiles": {"sprites": {}, "spritePath":"./Mods/Core/OvermapTiles/"}}
var maps: DMaps
var tacticalmaps: DTacticalmaps
var furnitures: DFurnitures
var items: DItems
var tiles: DTiles
var mobs: DMobs
var itemgroups: DItemgroups
var playerattributes: DPlayerAttributes
var wearableslots: DWearableSlots
var stats: DStats
var skills: DSkills
var quests: DQuests
var overmapareas: DOvermapareas

# Load the shader resource
static var hide_above_player_shader := preload("res://Shaders/HideAbovePlayer.gdshader")

# Dictionary to store loaded textures
var textures: Dictionary = {
	"container": load("res://Textures/container_32.png"),
	"container_filled": load("res://Textures/container_filled_32.png")
}
var materials: Dictionary = {}

# Enums to define the different content types
enum ContentType {
	TACTICALMAPS,       #0
	MAPS,               #1
	FURNITURES,         #2
	ITEMGROUPS,         #3
	ITEMS,              #4
	TILES,              #5
	MOBS,               #6
	PLAYERATTRIBUTES,   #7
	WEARABLESLOTS,      #8
	STATS,              #9
	SKILLS,             #10
	QUESTS,              #11
	OVERMAPAREAS        #12
}

# Rotation mappings for how directions change based on tile rotation
const ROTATION_MAP: Dictionary = {
	0: {"north": "north", "east": "east", "south": "south", "west": "west"},
	90: {"north": "east", "east": "south", "south": "west", "west": "north"},
	180: {"north": "south", "east": "west", "south": "north", "west": "east"},
	270: {"north": "west", "east": "north", "south": "east", "west": "south"}
}

# Define direction offsets for easy neighbor lookups
const DIRECTION_OFFSETS: Dictionary = {
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"south": Vector2(0, 1),
	"west": Vector2(-1, 0)
}

# Dictionary to map content types to Gamedata variables
var gamedata_map: Dictionary = {}

# This function is called when the node is added to the scene.
func _ready():
	# Instantiate the content type instances
	maps = DMaps.new()
	tacticalmaps = DTacticalmaps.new()
	furnitures = DFurnitures.new()
	items = DItems.new()
	tiles = DTiles.new()
	mobs = DMobs.new()
	itemgroups = DItemgroups.new()
	playerattributes = DPlayerAttributes.new()
	wearableslots = DWearableSlots.new()
	stats = DStats.new()
	skills = DSkills.new()
	quests = DQuests.new()
	overmapareas = DOvermapareas.new()

	# Now populate the gamedata_map with the instantiated objects
	gamedata_map = {
		ContentType.TACTICALMAPS: tacticalmaps,	
		ContentType.MAPS: maps,	
		ContentType.FURNITURES: furnitures,
		ContentType.ITEMGROUPS: itemgroups,
		ContentType.ITEMS: items,
		ContentType.TILES: tiles,
		ContentType.MOBS: mobs,
		ContentType.PLAYERATTRIBUTES: playerattributes,
		ContentType.WEARABLESLOTS: wearableslots,
		ContentType.STATS: stats,
		ContentType.SKILLS: skills,
		ContentType.QUESTS: quests,
		ContentType.OVERMAPAREAS: overmapareas
	}

	load_sprites()
	materials["container"] = create_item_shader_material(textures.container)
	materials["container_filled"] = create_item_shader_material(textures.container_filled)


# Helper function to create a ShaderMaterial for the item
func create_item_shader_material(albedo_texture: Texture) -> ShaderMaterial:
	# Create a new ShaderMaterial
	var shader_material = ShaderMaterial.new()
	shader_material.shader = hide_above_player_shader  # Use the shared shader

	# Assign the texture to the material
	shader_material.set_shader_parameter("texture_albedo", albedo_texture)

	return shader_material


# Loads sprites and assigns them to the proper dictionary
func load_sprites() -> void:
	for dict in data.keys():
		if data[dict].has("spritePath"):
			var loaded_sprites: Dictionary = {}
			var spritesDir: String = data[dict].spritePath
			var png_files: Array = Helper.json_helper.file_names_in_dir(spritesDir, ["png"])
			for png_file in png_files:
				# Load the .png file as a texture
				var texture := load(spritesDir + png_file) 
				# Add the material to the dictionary
				loaded_sprites[png_file] = texture
			data[dict].sprites = loaded_sprites


# Gets the array index of an item by its ID
func get_array_index_by_id(contentData: Dictionary, id: String) -> int:
	# Iterate through the array
	for i in range(len(contentData.data)):
		# Check if the current item is a dictionary
		if typeof(contentData.data[i]) == TYPE_DICTIONARY:
			# Check if it has the 'id' key and matches the given ID
			if contentData.data[i].has("id") and contentData.data[i]["id"] == id:
				return i
		# Check if the current item is a string and matches the given ID
		elif typeof(contentData.data[i]) == TYPE_STRING and contentData.data[i] == id:
			return i
	# Return -1 if the ID is not found
	return -1


# Saves data to file
func save_data_to_file(contentData: Dictionary):
	var datapath: String = contentData.dataPath
	if datapath.ends_with(".json"):
		Helper.json_helper.write_json_file(datapath, JSON.stringify(contentData.data, "\t"))


# Returns one of the D- data types. We return it as refcounted since every class differs
func get_data_of_type(type: ContentType) -> RefCounted:
	return gamedata_map[type]


# Removes the provided reference from references
# For example, remove "town_00" from references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
# TODO: Have this function replace add_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dremove_reference(references: Dictionary, module: String, type: String, refid: String) -> bool:
	var changes_made = false
	if not references.has(module):
		return false
	if not references[module].has(type):
		return false
	var refs = references[module][type]
	if refid in refs:
		refs.erase(refid)
		changes_made = true
		# Clean up if necessary
		if refs.size() == 0:
			references[module].erase(type)
		if references[module].is_empty():
			references.erase(module)
	return changes_made


# Adds a reference to the references list
# For example, add "town_00" to references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
# TODO: Have this function replace add_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dadd_reference(references: Dictionary, module: String, type: String, refid: String) -> bool:
	var changes_made: bool = false
	if not references.has(module):
		references[module] = {}
	if not references[module].has(type):
		references[module][type] = []
	if refid not in references[module][type]:
		references[module][type].append(refid)
		changes_made = true
	return changes_made


# Helper function to update references if they have changed.
# old: an entity id that is present in the old data
# new: an entity id that is present in the new data
# entity_id: The entity that's referenced in old and/or new
# type: The type of entity that will be referenced
# Example usage: update_reference(old_quest, new_quest, item_id, "item")
# This example will remove item_id from the old_quest's references and
# add the item_id to the new_quest's refrences
# TODO: Have this function replace update_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dupdate_reference(ref: Dictionary, old: String, new: String, type: String) -> bool:
	if old == new:
		return false  # No change detected, exit early

	var changes_made = false

	# Remove from old group if necessary
	if old != "":
		changes_made = dremove_reference(ref, "core", type, old) or changes_made
	if new != "":
		changes_made = dadd_reference(ref, "core", type, new) or changes_made
	return changes_made
