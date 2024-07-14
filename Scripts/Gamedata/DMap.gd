class_name DMap
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of maps. You can access it trough Gamedata.maps


var id: String = "":
	set(newid):
		id = newid.replace(".json", "") # In case the filename is passed, we remove json
var name: String
var description: String
var categories: Array
var weight: int
var mapwidth: int = 32
var mapheight: int = 32
var levels: Array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
var references: Dictionary = {}
var areas: Array = []

var dataPath: String


func _init(newid: String, newdataPath: String):
	id = newid
	dataPath = newdataPath


func set_data(newdata: Dictionary) -> void:
	id = newdata.get("id", "")
	name = newdata.get("name", "")
	description = newdata.get("description", "")
	categories = newdata.get("categories", [])
	weight = newdata.get("weight", 1000)
	mapwidth = newdata.get("mapwidth", 32)
	mapheight = newdata.get("mapheight", 32)
	levels = newdata.get("levels", [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]])
	references = newdata.get("references", {})
	areas = newdata.get("areas", [])


func load_data_from_disk():
	set_data(Helper.json_helper.load_json_dictionary_file(get_file_path()))


func save_data_to_disk() -> void:
	var map_data_json = JSON.stringify(get_data().duplicate(), "\t")
	Helper.json_helper.write_json_file(get_file_path(), map_data_json)


func get_data() -> Dictionary:
	var mydata: Dictionary = {}
	mydata["id"] = id
	mydata["name"] = name
	mydata["description"] = description
	mydata["categories"] = categories
	mydata["weight"] = weight
	mydata["mapwidth"] = mapwidth
	mydata["mapheight"] = mapheight
	mydata["levels"] = levels
	mydata["references"] = references
	mydata["areas"] = areas
	return mydata


func get_filename() -> String:
	return id + ".json"
	
func get_file_path() -> String:
	return dataPath + get_filename()


func remove_self_from_tacticalmap(tacticalmap_id: String):
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
func on_map_deleted(map_id: String):
	var changes_made = false

	# Remove this map from the tacticalmaps in this map's references
	for ref in references:
		for mod in references.keys():
			for tmap in mod.get("tacticalmaps", []):
				remove_self_from_tacticalmap(tmap)

	# Collect unique entities from mapdata
	var entities = collect_unique_entities(DMap.new(id, dataPath))
	var unique_entities = entities["new_entities"]

	# Remove references for unique entities
	for entity_type in unique_entities.keys():
		for entity_id in unique_entities[entity_type]:
			changes_made = Gamedata.remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, map_id) or changes_made

	if changes_made:
		# References have been added to tiles, furniture and/or mobs
		# We could track changes individually so we only save what has actually changed.
		Gamedata.save_data_to_file(Gamedata.data.tiles)
		Gamedata.save_data_to_file(Gamedata.data.furniture)
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
		for entity_id in new_entities[entity_type]:
			if not old_entities[entity_type].has(entity_id):
				Gamedata.add_reference(Gamedata.data[entity_type], "core", "maps", entity_id, id)

	# Remove references for entities not present in new data
	for entity_type in old_entities.keys():
		for entity_id in old_entities[entity_type]:
			if not new_entities[entity_type].has(entity_id):
				Gamedata.remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, id)

	# Save changes to the data files if there were any updates
	if new_entities["mobs"].size() > 0 or old_entities["mobs"].size() > 0:
		Gamedata.save_data_to_file(Gamedata.data.mobs)
	if new_entities["furniture"].size() > 0 or old_entities["furniture"].size() > 0:
		Gamedata.save_data_to_file(Gamedata.data.furniture)
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
	for area in areas:
		add_entities_in_area_to_set(area, new_entities)

	# Collect entities from olddata
	for area in oldmap.areas:
		add_entities_in_area_to_set(area, old_entities)
	
	return {"new_entities": new_entities, "old_entities": old_entities}


# Helper function to add entities to the respective sets
func add_entities_in_area_to_set(area: Dictionary, entity_set: Dictionary):
	if area.has("entities"):
		for entity in area["entities"]:
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

	if area.has("tiles"):
		for tile in area["tiles"]:
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


# Removes all instances of the provided entity from the provided map
# map_id is the id of one of the maps. It will be loaded from json to manipulate it.
# entity_type can be "tile", "furniture", "itemgroup" or "mob"
# entity_id is the id of the tile, furniture, itemgroup or mob
func remove_entity_from_map(entity_type: String, entity_id: String) -> void:
	# Translate the type to the actual key that we need
	if entity_type == "tile":
		entity_type = "id"

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

	erase_entity_from_areas(entity_type, entity_id)


# Function to erase an entity from every area in the mapdata.areas property
func erase_entity_from_areas(entity_type: String, entity_id: String) -> void:
	for area in areas:
		match entity_type:
			"tile":
				if area.has("tiles"):
					area["tiles"] = area["tiles"].filter(func(tile):
						return tile["id"] != entity_id
					)
			"furniture", "mob", "itemgroup":
				if area.has("entities"):
					area["entities"] = area["entities"].filter(func(entity):
						return not (entity["type"] == entity_type and entity["id"] == entity_id)
					)
