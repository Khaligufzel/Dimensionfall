class_name DMap
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles data for one map. You can access it trough Gamedata.maps


var id: String = "":
	set(newid):
		id = newid.replace(".json", "") # In case the filename is passed, we remove json
var name: String = ""
var description: String = ""
var categories: Array = []
var weight: int = 1000
var mapwidth: int = 32
var mapheight: int = 32
var levels: Array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
var references: Dictionary = {}
var areas: Array = []
var sprite: Texture = null

var dataPath: String


# The area that may be present on the map
# TODO: Implement this into the script
class area:
	var entities: Array = []
	var id: String = ""
	var rotate_random: bool = false
	var spawn_chance: int = 100
	var tiles: Array = []


# Definition of a tile on the map, in one of the levels
# TODO: Implement this into the script
class maptile:
	# Only a reference to an area, not an instance of an area. Can have "id" and "rotation"
	var areas: Array = [] 
	var id: String = "" # The id of the tile
	var rotation: int = 0
	# Furniture, Mob and Itemgroups are mutually exclusive. Only one can exist at a time
	var furniture: String = ""
	var mob: String = ""
	var itemgroups: Array = []


func _init(newid: String, newdataPath: String):
	id = newid
	dataPath = newdataPath


func set_data(newdata: Dictionary) -> void:
	name = newdata.get("name", "")
	description = newdata.get("description", "")
	categories = newdata.get("categories", [])
	weight = newdata.get("weight", 1000)
	mapwidth = newdata.get("mapwidth", 32)
	mapheight = newdata.get("mapheight", 32)
	levels = newdata.get("levels", [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]])
	references = newdata.get("references", {})
	areas = newdata.get("areas", [])


func get_data() -> Dictionary:
	var mydata: Dictionary = {}
	mydata["id"] = id
	mydata["name"] = name
	mydata["description"] = description
	if not categories.is_empty():
		mydata["categories"] = categories
	mydata["weight"] = weight
	mydata["mapwidth"] = mapwidth
	mydata["mapheight"] = mapheight
	mydata["levels"] = levels
	if not references.is_empty():
		mydata["references"] = references
	if not areas.is_empty():
		mydata["areas"] = areas
	return mydata


func load_data_from_disk():
	set_data(Helper.json_helper.load_json_dictionary_file(get_file_path()))
	sprite = load(get_sprite_path()) 


func save_data_to_disk() -> void:
	var map_data_json = JSON.stringify(get_data().duplicate(), "\t")
	Helper.json_helper.write_json_file(get_file_path(), map_data_json)


func get_filename() -> String:
	return id + ".json"
	
func get_file_path() -> String:
	return dataPath + get_filename()
	
func get_sprite_path() -> String:
	return get_file_path().replace(".json", ".png")


func remove_self_from_tacticalmap(tacticalmap_id: String) -> void:
	var tfile = Gamedata.data.tacticalmaps.dataPath + tacticalmap_id
	var tmapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(tfile)

	# Check if the "chunks" key exists and is an array
	if tmapdata.has("chunks") and tmapdata["chunks"] is Array:
		# Filter out chunks that match the map_id, leaving only valid ones in the tacticalmap
		tmapdata["chunks"] = tmapdata["chunks"].filter(func(chunk):
			return not (chunk.has("id") and chunk["id"] == id)
		)
		var map_data_json = JSON.stringify(tmapdata.duplicate(), "\t")
		Helper.json_helper.write_json_file(tfile, map_data_json)


# A map is being deleted. Remove all references to this map
func delete_files():
	var json_file_path = get_file_path()
	var png_file_path = get_sprite_path()
	Helper.json_helper.delete_json_file(json_file_path)
	# Use DirAccess to check and delete the PNG file
	var dir = DirAccess.open(dataPath)
	if dir.file_exists(png_file_path):
		dir.remove(id + ".png")
		dir.remove(id + ".png.import")
	

func delete():
	delete_files()
	
	# Remove this map from the tacticalmaps in this map's references
	for ref in references:
		for mod in references.keys():
			for tmap in references[mod].get("tacticalmaps", []):
				remove_self_from_tacticalmap(tmap)
	
	remove_my_reference_from_all_entities()


func remove_my_reference_from_all_entities() -> void:
	var changes_made = false
	
	# Collect unique entities from mapdata
	var entities = collect_unique_entities(DMap.new(id, dataPath))
	var unique_entities = entities["new_entities"]

	# Remove references for unique entities
	for entity_type in unique_entities.keys():
		for entity_id in unique_entities[entity_type]:
			changes_made = Gamedata.remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, id) or changes_made

	if changes_made:
		# References have been added to tiles, furniture and/or mobs
		# We could track changes individually so we only save what has actually changed.
		Gamedata.save_data_to_file(Gamedata.data.tiles)
		Gamedata.furnitures.save_furnitures_to_disk()
		Gamedata.save_data_to_file(Gamedata.data.mobs)
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)


# Function to update map entity references when a map's data changes
func data_changed(oldmap: DMap):
	# Collect unique entities from both new and old data
	var entities = collect_unique_entities(oldmap)
	var new_entities = entities["new_entities"]
	var old_entities = entities["old_entities"]

	# Add references for new entities
	for entity_type in new_entities.keys():
		if entity_type == "furniture":
			for entity_id in new_entities[entity_type]:
				var furniture: DFurniture = Gamedata.furnitures.by_id(entity_id)
				furniture.add_reference("core","maps",id)
		else:
			for entity_id in new_entities[entity_type]:
				Gamedata.add_reference(Gamedata.data[entity_type], "core", "maps", entity_id, id)

	# Remove references for entities not present in new data
	for entity_type in old_entities.keys():
		if entity_type == "furniture":
			for entity_id in old_entities[entity_type]:
				if not new_entities[entity_type].has(entity_id):
					var furniture: DFurniture = Gamedata.furnitures.by_id(entity_id)
					furniture.remove_reference("core","maps",id)
		else:
			for entity_id in old_entities[entity_type]:
				if not new_entities[entity_type].has(entity_id):
					Gamedata.remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, id)

	# Save changes to the data files if there were any updates
	if new_entities["mobs"].size() > 0 or old_entities["mobs"].size() > 0:
		Gamedata.save_data_to_file(Gamedata.data.mobs)
	if new_entities["furniture"].size() > 0 or old_entities["furniture"].size() > 0:
		Gamedata.furnitures.save_furnitures_to_disk()
	if new_entities["tiles"].size() > 0 or old_entities["tiles"].size() > 0:
		Gamedata.save_data_to_file(Gamedata.data.tiles)
	if new_entities["itemgroups"].size() > 0 or old_entities["itemgroups"].size() > 0:
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)


# Function to collect unique entities from each level in newdata and olddata
func collect_unique_entities(oldmap: DMap) -> Dictionary:
	var new_entities = {
		"mobs": [],
		"furniture": [],
		"itemgroups": [],
		"tiles": []
	}
	var old_entities = {
		"mobs": [],
		"furniture": [],
		"itemgroups": [],
		"tiles": []
	}

	# Collect entities from newdata
	for level in levels:
		add_entities_to_set(level, new_entities)

	# Collect entities from olddata
	for level in oldmap.levels:
		add_entities_to_set(level, old_entities)

	# Collect entities from newdata
	for myarea in areas:
		add_entities_in_area_to_set(myarea, new_entities)

	# Collect entities from olddata
	for myarea in oldmap.areas:
		add_entities_in_area_to_set(myarea, old_entities)
	
	return {"new_entities": new_entities, "old_entities": old_entities}


# Helper function to add entities to the respective sets
func add_entities_in_area_to_set(myarea: Dictionary, entity_set: Dictionary):
	if myarea.has("entities"):
		for entity in myarea["entities"]:
			match entity["type"]:
				"mob":
					if not entity_set["mobs"].has(entity["id"]):
						entity_set["mobs"].append(entity["id"])
				"furniture":
					if not entity_set["furniture"].has(entity["id"]):
						entity_set["furniture"].append(entity["id"])
				"itemgroup":
					if not entity_set["itemgroups"].has(entity["id"]):
						entity_set["itemgroups"].append(entity["id"])

	if myarea.has("tiles"):
		for tile in myarea["tiles"]:
			if not entity_set["tiles"].has(tile["id"]):
				entity_set["tiles"].append(tile["id"])


# Helper function to add entities to the respective sets
func add_entities_to_set(level: Array, entity_set: Dictionary):
	for entity in level:
		if entity.has("mob") and not entity_set["mobs"].has(entity["mob"]["id"]):
			entity_set["mobs"].append(entity["mob"]["id"])
		if entity.has("furniture"):
			if not entity_set["furniture"].has(entity["furniture"]["id"]):
				entity_set["furniture"].append(entity["furniture"]["id"])
			# Add unique itemgroups from furniture
			if entity["furniture"].has("itemgroups"):
				for itemgroup in entity["furniture"]["itemgroups"]:
					if not entity_set["itemgroups"].has(itemgroup):
						entity_set["itemgroups"].append(itemgroup)
		if entity.has("id") and not entity_set["tiles"].has(entity["id"]):
			entity_set["tiles"].append(entity["id"])
		# Add unique itemgroups directly from the entity
		if entity.has("itemgroups"):
			for itemgroup in entity["itemgroups"]:
				if not entity_set["itemgroups"].has(itemgroup):
					entity_set["itemgroups"].append(itemgroup)


# Removes all instances of the provided entity from the map
# entity_type can be "tile", "furniture", "itemgroup" or "mob"
# entity_id is the id of the tile, furniture, itemgroup or mob
func remove_entity_from_map(entity_type: String, entity_id: String) -> void:
	# Translate the type to the actual key that we need
	if entity_type == "tile":
		entity_type = "id"
	remove_entity_from_levels(entity_type, entity_id)
	erase_entity_from_areas(entity_type, entity_id)
	save_data_to_disk()


# Removes all instances of the provided entity from the levels
# entity_type can be "tile", "furniture", "itemgroup" or "mob"
# entity_id is the id of the tile, furniture, itemgroup or mob
func remove_entity_from_levels(entity_type: String, entity_id: String) -> void:
	# Iterate over each level in the map
	for level in levels:
		# Iterate through each entity in the level
		for entity_index in range(level.size()):
			var entity = level[entity_index]

			match entity_type:
				"id":
					# Check if the entity's 'id' matches and replace the entire entity with an empty object
					if entity.get("id", "") == entity_id:
						level[entity_index] = {}  # Replacing entity with an empty object
				"furniture":
					# Check if the entity has 'furniture' and the 'id' within it matches
					if entity.has("furniture") and entity["furniture"].get("id", "") == entity_id:
						entity.erase("furniture")  # Removing the furniture object from the entity
				"mob":
					# Check if the entity has 'mob' and the 'id' within it matches
					if entity.has("mob") and entity["mob"].get("id", "") == entity_id:
						entity.erase("mob")  # Removing the mob object from the entity
				"itemgroup":
					# Check if the entity has 'furniture' and 'itemgroups', then remove the itemgroup
					if entity.has("furniture") and entity["furniture"].has("itemgroups"):
						var itemgroups = entity["furniture"]["itemgroups"]
						if itemgroups.has(entity_id):
							itemgroups.erase(entity_id)
							if itemgroups.size() == 0:
								entity["furniture"].erase("itemgroups")
					# Also, check and remove itemgroups from the entity itself if present
					if entity.has("itemgroups"):
						var entity_itemgroups = entity["itemgroups"]
						if entity_itemgroups.has(entity_id):
							entity_itemgroups.erase(entity_id)
							if entity_itemgroups.size() == 0:
								entity.erase("itemgroups")


# Function to erase an entity from every area
func erase_entity_from_areas(entity_type: String, entity_id: String) -> void:
	for myarea in areas:
		match entity_type:
			"tile":
				if myarea.has("tiles"):
					myarea["tiles"] = myarea["tiles"].filter(func(tile):
						return tile["id"] != entity_id
					)
			"furniture", "mob", "itemgroup":
				if myarea.has("entities"):
					myarea["entities"] = myarea["entities"].filter(func(entity):
						return not (entity["type"] == entity_type and entity["id"] == entity_id)
					)


# Removes the provided reference from references
# For example, remove "town_00" from references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		save_data_to_disk()


# Adds a reference to the references list
# For example, add "town_00" to references.Core.tacticalmaps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "tacticlmaps"
# refid: The id of the entity, for example "town_00"
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		save_data_to_disk()


# Function to remove a area from mapData.areas by its id
func remove_area(area_id: String) -> void:	
	# Iterate through the areas array to find and remove the area by id
	for i in range(areas.size()):
		if areas[i]["id"] == area_id:
			areas.erase(areas[i])
			break
