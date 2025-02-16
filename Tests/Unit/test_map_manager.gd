extends GutTest

# This script is meant to test Helper.map_manager
# We test the functions from that helper script to improve reliability

var map_manager: Node

# Runs before each test.
func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	map_manager = Helper.map_manager
	await get_tree().process_frame 

func before_each():
	await get_tree().process_frame

func after_each():
	await get_tree().process_frame

func after_all():
	Runtimedata.reset()


func test_get_tile_area_rotation_with_rotation():
	var tile = {"areas": [{"id": "test_area", "rotation": 90}]}
	var area_data = {"id": "test_area"}
	assert_eq(map_manager.get_tile_area_rotation(tile, area_data), 90, "Expected rotation 90")

func test_get_tile_area_rotation_no_match():
	var tile = {"areas": [{"id": "other_area", "rotation": 45}]}
	var area_data = {"id": "test_area"}
	assert_eq(map_manager.get_tile_area_rotation(tile, area_data), 0, "Expected rotation 0 for non-matching area")

func test_get_tile_area_rotation_no_rotation():
	var tile = {"areas": [{"id": "test_area"}]}
	var area_data = {"id": "test_area"}
	assert_eq(map_manager.get_tile_area_rotation(tile, area_data), 0, "Expected rotation 0 for missing rotation")

func test_pick_item_based_on_count():
	var items = [{"id": "item1", "count": 1}, {"id": "item2", "count": 3}]
	var picked = map_manager.pick_item_based_on_count(items)
	assert_not_null(picked, "Expected an item to be picked")
	assert_true(["item1", "item2"].has(picked["id"]), "Picked unknown item")

func test_calculate_total_count():
	var items = [{"id": "item1", "count": 1}, {"id": "item2", "count": 3}]
	assert_eq(map_manager.calculate_total_count(items), 4, "Expected total count 4")


# Test both cases that are possible for the _get_random_rotation function
# Area data has been simplified to only id and rotate_random but usually contains more
func test_get_random_rotation():
	var area_random_data: Dictionary = {"id": "tree_layer","rotate_random": true}
	assert_true([0, 90, 180, 270].has(map_manager._get_random_rotation(area_random_data)), "Picked unknown rotation")
	var area_data: Dictionary = {"id": "tree_layer","rotate_random": false}
	assert_eq(map_manager._get_random_rotation(area_data), -1, "Expected -1")


# Test processing of a tile based on the provided area and map data
func test_process_tile_id():
	var area_data: Dictionary = { # The area that will be applied to this map tile
		"id": "ground_layer",
		"rotate_random": true,
		"spawn_chance": 100,
		"entities": [],
		"tiles": [
			{"id": "forest_underbrush_03", "count": 100},
			{"id": "forest_underbrush_04", "count": 100},
			{"id": "forest_underbrush_05", "count": 100},
			{"id": "dirt_light_00", "count": 2},
			{"id": "grass_medium_dirt_00", "count": 2}
		]
	}
	var original_tile: Dictionary = { # The tile as it was painted onto the map
		"id":"grass_medium_00",
		"areas":[{"id":"ground_layer","rotation":270}]
	}
	var result = {}
	# Since the area does not have "pick_one" set to true, we don't pick a tile ahead of time
	var picked_tile: Dictionary = {}
	map_manager._process_tile_id(area_data, original_tile, result, picked_tile)
	var result_id: String = result.get("id","")
	var result_rotation: int = result.get("rotation",0)

	# The grass_medium_00 tile must've been replaced by one of the following
	var valid_ids: Array[String] = ["forest_underbrush_03","forest_underbrush_04",
		"forest_underbrush_05",	"dirt_light_00", "grass_medium_dirt_00"	]

	# Check if result_id and rotation is valid
	assert_true(valid_ids.has(result_id), "Unexpected tile id: " + result_id)
	assert_true([0, 90, 180, 270].has(result_rotation), "Unexpected rotation: " + str(result_rotation))


# Test processing of a entities based on the provided area and map data
# The purpose is to apply furniture to a tile
func test_process_entities_data():
	var area_data: Dictionary = { # The area that will be applied to this map tile
		"id": "tree_layer",
		"rotate_random": true,
		"spawn_chance": 100,
		"entities": [
			{"id": "Tree_00", "type": "furniture", "count": 11},
			{"id": "PineTree_00", "type": "furniture", "count": 11},
			{"id": "WillowTree_00", "type": "furniture", "count": 11}
		],
		"tiles": [{"id": "null", "count": 100}]
	}
	var original_tile: Dictionary = { # The tile as it was painted onto the map
		"id":"grass_medium_00",
		"areas":[{"id":"tree_layer","rotation":90}]
	}
	# In this example, the grass_medium_00 was replaced by dirt_light_00:
	var result = {"id":"dirt_light_00","rotation":180} # Example result from _process_tile_id
	map_manager._process_entities_data(area_data, result, original_tile)
	var result_rotation: int = result.get("rotation",0)

	# The tile id and rotation shouldn't have changed
	assert_eq(result.get("id",""), "dirt_light_00", "Unexpected tile id")
	assert_eq(result.get("rotation",0), 180, "Rotation has changed")
	
	if result.has("furniture"):
		var valid_ids: Array[String] = ["Tree_00", "PineTree_00", "WillowTree_00"]
		# furniture has been selected from the area, so it must be a tree
		assert_true(valid_ids.has(result.furniture.id), "Unexpected furniture")
	else:
		# No furniture was put onto the tile, but the tile shouldn't have any of the following
		assert_does_not_have(result,"mob","Unexpected mob key")
		assert_does_not_have(result,"mobgroup","Unexpected mobgroup key")
		assert_does_not_have(result,"itemgroup","Unexpected itemgroup key")
		
