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


# Dictionary to store loaded textures
var textures: Dictionary = {
	"container": load("res://Textures/container_32.png"),
	"container_filled": load("res://Textures/container_filled_32.png")
}

# We write down the associated paths for the files to load
# Next, sprites are loaded from spritesPath into the .sprites property
# Finally, the data is loaded from dataPath into the .data property
func _ready():
	load_sprites()
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


# Removes the provided reference from references
# For example, remove "town_00" from references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
# TODO: Have this function replace add_reference when all entities have been transformed into
# their own class. Until then, a d is added to the front to indicate it's used in data classes
func dremove_reference(references: Dictionary, module: String, type: String, refid: String) -> bool:
	var changes_made = false
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
