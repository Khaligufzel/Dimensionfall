extends Node

# This script is intended to be used inside the GameData autoload singleton
# This script handles references between maps and other entities.

# A map is being deleted. Remove all references to this map
func on_map_deleted(map_id: String):
	var changes_made = false
	var file_to_load = Gamedata.data.maps.dataPath + map_id + ".json"
	var mapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(file_to_load)
	
	if not mapdata.has("levels"):
		print("Map data does not contain 'levels'.")
		return

	# This callable will remove this map from every tacticalmap that references this map.
	var myfunc: Callable = func(tmap_id):
		var tfile = Gamedata.data.tacticalmaps.dataPath + tmap_id
		var tmapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(tfile)
		
		# Check if the "chunks" key exists and is an array
		if tmapdata.has("chunks") and tmapdata["chunks"] is Array:
			# Filter out chunks that match the map_id, leaving only valid ones in the tacticalmap
			tmapdata["chunks"] = tmapdata["chunks"].filter(func(chunk):
				return not (chunk.has("id") and chunk["id"] == map_id + ".json")
			)
			var map_data_json = JSON.stringify(tmapdata.duplicate(), "\t")
			Helper.json_helper.write_json_file(tfile, map_data_json)
	
	# Pass the callable to every tacticalmap in the map's references
	# It will call myfunc on every tacticalmap in mapdata.references.core.tacticalmaps
	Gamedata.execute_callable_on_references_of_type(mapdata, "core", "tacticalmaps", myfunc)
	
	# Collect unique entities from mapdata
	var entities = collect_unique_entities(mapdata, {})
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
func on_mapdata_changed(map_id: String, newdata: Dictionary, olddata: Dictionary):
	# Collect unique entities from both new and old data
	var entities = collect_unique_entities(newdata, olddata)
	var new_entities = entities["new_entities"]
	var old_entities = entities["old_entities"]
	map_id = map_id.get_file().replace(".json", "")

	# Add references for new entities
	for entity_type in new_entities.keys():
		for entity_id in new_entities[entity_type]:
			if not old_entities[entity_type].has(entity_id):
				Gamedata.add_reference(Gamedata.data[entity_type], "core", "maps", entity_id, map_id)

	# Remove references for entities not present in new data
	for entity_type in old_entities.keys():
		for entity_id in old_entities[entity_type]:
			if not new_entities[entity_type].has(entity_id):
				Gamedata.remove_reference(Gamedata.data[entity_type], "core", "maps", entity_id, map_id)

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
func collect_unique_entities(newdata: Dictionary, olddata: Dictionary) -> Dictionary:
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
	for level in newdata.get("levels", []):
		add_entities_to_set(level, new_entities)

	# Collect entities from olddata
	for level in olddata.get("levels", []):
		add_entities_to_set(level, old_entities)

	# Collect entities from newdata
	if newdata.has("areas"):
		for area in newdata["areas"]:
			add_entities_to_set(area, new_entities)

	# Collect entities from olddata
	if olddata.has("areas"):
		for area in olddata["areas"]:
			add_entities_to_set(area, old_entities)
	
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
func remove_entity_from_map(map_id: String, entity_type: String, entity_id: String) -> void:
	var file_to_load = Gamedata.data.maps.dataPath + map_id + ".json"
	var mapdata: Dictionary = Helper.json_helper.load_json_dictionary_file(file_to_load)
	
	if not mapdata.has("levels"):
		print("Map data does not contain 'levels'.")
		return

	var levels = mapdata["levels"]
	
	# Translate the type to the actual key that we need
	if entity_type == "tile":
		entity_type = "id"

	# Iterate over each level in the map
	for level_index in range(levels.size()):
		var level = levels[level_index]

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

		# Update the level in the mapdata after modifications
		levels[level_index] = level

	# Update the mapdata levels after processing all
	mapdata["levels"] = levels
	print_debug("Entity removal operations completed for all levels.")
	
	erase_entity_from_areas(mapdata, entity_type, entity_id)
	
	var map_data_json = JSON.stringify(mapdata.duplicate(), "\t")
	Helper.json_helper.write_json_file(file_to_load, map_data_json)


# Function to erase an entity from every area in the mapdata.areas property
func erase_entity_from_areas(mapdata: Dictionary, entity_type: String, entity_id: String) -> void:
	if not mapdata.has("areas"):
		print("Map data does not contain 'areas'.")
		return

	var areas = mapdata["areas"]

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

	mapdata["areas"] = areas
	print_debug("Entity removal operations completed for all areas.")
