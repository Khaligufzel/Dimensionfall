extends Node3D


var level_json_as_text
var level_levels : Array
var map_save_folder: String

var level_width : int = 32
var level_height : int = 32


@onready var defaultBlock: PackedScene = preload("res://Defaults/Blocks/default_block.tscn")
@onready var defaultSlope: PackedScene = preload("res://Defaults/Blocks/default_slope.tscn")
@export var defaultMob: PackedScene
@export var defaultItem: PackedScene
@export var defaultFurniturePhysics: PackedScene
@export var defaultFurnitureStatic: PackedScene
@export var level_manager : Node3D
@export_file var default_level_json



# Called when the node enters the scene tree for the first time.
func _ready():
	generate_map()
	$"../NavigationRegion3D".bake_navigation_mesh()
	
func generate_map():
	map_save_folder = Helper.save_helper.get_saved_map_folder(Helper.current_level_pos)
	generate_tactical_map()
	# These tree functions apply only to maps thet were previously saved in a save game
	generate_mobs()
	generate_items()
	generate_furniture()

# We generate a tactical map, which is made up of x by y maps of 32x32 blocks
# If we can find a saved map on the current coordinate, we load that
# Otherwise, we load the mapdata from the game data and make a brand new one
func generate_tactical_map():
	var tacticalMapJSON: Dictionary = {}
	var level_name: String = Helper.current_level_name
	map_save_folder = Helper.save_helper.get_saved_map_folder(Helper.current_level_pos)
	# Load the default map from json
	# Unless the map_save_folder is set
	# In which case we load tha map instead
	if map_save_folder == "":
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.tacticalmaps.dataPath + level_name)
		var i: int = 0
		for z in range(tacticalMapJSON.mapheight):
			for x in range(tacticalMapJSON.mapwidth):
				generate_tactical_map_level_segment(x, z,tacticalMapJSON.maps[i])
				i+=1
	else:
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		map_save_folder + "/map.json")
		generate_saved_level(tacticalMapJSON)

func generate_tactical_map_level_segment(segment_x: int, segment_z: int, mapsegment: Dictionary):
	var offset_x = segment_x * level_width
	var offset_z = segment_z * level_height
	#This contains the data of one segment, loaded from maps.data, for example generichouse.json
	var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.maps.dataPath + mapsegment.id)
	var tileJSON: Dictionary = {}

	var level_number = 0
	for level in mapsegmentData.levels:
		if level != []:
			var level_node = Node3D.new()
			level_manager.add_child(level_node)
			level_node.add_to_group("maplevels")
			level_node.global_position.y = level_number - 10
			level_node.global_position.x = offset_x
			level_node.global_position.z = offset_z

			var current_block = 0
			for h in range(level_height):
				for w in range(level_width):
					if level[current_block]:
						tileJSON = level[current_block]
						if tileJSON.has("id") and tileJSON.id != "":
							var block = create_block_with_id(tileJSON.id)
							level_node.add_child(block)
							block.position.x = w
							block.position.z = h
							apply_block_rotation(tileJSON, block)
							add_block_mob(tileJSON, block)
							add_furniture_to_block(tileJSON, block)
					current_block += 1
			if !len(level_node.get_children()) > 0:
				level_node.remove_from_group("maplevels")
				level_node.queue_free()
			
		level_number += 1

# Called when the map is generated
# Only applicable if a save is loaded
func generate_mobs() -> void:
	if map_save_folder == "":
		return
	var mobsArray = Helper.json_helper.load_json_array_file(map_save_folder + "/mobs.json")
	for mob: Dictionary in mobsArray:
		add_mob_to_map.call_deferred(mob)

# Called by generate_mobs function when a save is loaded
func add_mob_to_map(mob: Dictionary) -> void:
	var newMob: CharacterBody3D = defaultMob.instantiate()
	newMob.add_to_group("mobs")
	get_tree().get_root().add_child(newMob)
	newMob.global_position.x = mob.global_position_x
	newMob.global_position.y = mob.global_position_y
	newMob.global_position.z = mob.global_position_z
	# Check if rotation data is available and apply it
	if mob.has("rotation"):
		newMob.rotation_degrees.y = mob.rotation
	newMob.apply_stats_from_json(mob)

# Called when the map is generated
# Only applicable if a save is loaded
func generate_items() -> void:
	if map_save_folder == "":
		return
	var itemsArray = Helper.json_helper.load_json_array_file(map_save_folder + "/items.json")
	for item: Dictionary in itemsArray:
		add_item_to_map.call_deferred(item)
		
# Called by generate_items function when a save is loaded
func add_item_to_map(item: Dictionary):
	var newItem: Node3D = defaultItem.instantiate()
	newItem.add_to_group("mapitems")
	get_tree().get_root().add_child(newItem)
	newItem.global_position.x = item.global_position_x
	newItem.global_position.y = item.global_position_y
	newItem.global_position.z = item.global_position_z
	# Check if rotation data is available and apply it
	if item.has("rotation"):
		newItem.rotation_degrees.y = item.rotation
	newItem.get_node(newItem.inventory).deserialize(item.inventory)

# Called when the map is generated
# Only applicable if a save is loaded
func generate_furniture() -> void:
	if map_save_folder == "":
		return
	var furnitureArray = Helper.json_helper.load_json_array_file(map_save_folder + "/furniture.json")
	for furnitureData: Dictionary in furnitureArray:
		add_furniture_to_map.call_deferred(furnitureData)

# Called by generate_furniture function when a save is loaded
func add_furniture_to_map(furnitureData: Dictionary) -> void:
	var newFurniture: Node3D
	var isMoveable = furnitureData.has("moveable") and furnitureData.moveable
	if isMoveable:
		newFurniture = defaultFurniturePhysics.instantiate()
	else:
		newFurniture = defaultFurnitureStatic.instantiate()
	newFurniture.add_to_group("furniture")
	newFurniture.set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.furniture, furnitureData.id))
	get_tree().get_root().add_child(newFurniture)
	newFurniture.global_position.x = furnitureData.global_position_x
	newFurniture.global_position.y = furnitureData.global_position_y
	newFurniture.global_position.z = furnitureData.global_position_z
	# Check if rotation data is available and apply it
	if furnitureData.has("rotation"):
		if isMoveable:
			newFurniture.rotation_degrees.y = furnitureData.rotation
		else:
			newFurniture.set_new_rotation(furnitureData.rotation)
	
	# Check if sprite rotation data is available and apply it
	if furnitureData.has("sprite_rotation") and isMoveable:
		newFurniture.set_new_rotation(furnitureData.sprite_rotation)
	newFurniture.id = furnitureData.id

# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_level(tacticalMapJSON: Dictionary) -> void:
	var tileJSON: Dictionary = {}
	var currentBlocks: Array = []
	#we need to generate level layer by layer starting from the bottom
	for level: Dictionary in tacticalMapJSON.maplevels:
		if level != {}:
			var level_node = Node3D.new()
			level_node.add_to_group("maplevels")
			level_manager.add_child(level_node)
			level_node.global_position.y = level.map_y
			level_node.global_position.x = level.map_x
			level_node.global_position.z = level.map_z
			currentBlocks = level.blocks
			var current_block = 0
			# we will generate number equal to "layer_height" of horizontal rows of blocks
			for h in level_height:
				
				# this loop will generate blocks from West to East based on the tile number
				# in json file
				for w in level_width:
					# checking if we have tile from json in our block array containing packedscenes
					# of blocks that we need to instantiate.
					# If yes, then instantiate
					if currentBlocks[current_block]:
						tileJSON = currentBlocks[current_block]
						if tileJSON.has("id"):
							if tileJSON.id != "":
								var block: StaticBody3D = create_block_with_id(tileJSON.id)
								level_node.add_child(block)
								# Because the level node already has a x and y position,
								# We only set the local position relative to the parent
								block.position.x = w
								block.position.z = h
								apply_block_rotation(tileJSON, block)
								add_block_mob(tileJSON, block)
								add_furniture_to_block(tileJSON, block)
					current_block += 1

func add_furniture_to_block(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("furniture"):
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
		Gamedata.data.furniture, tileJSON.furniture.id)
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = defaultFurniturePhysics.instantiate()
		else:
			newFurniture = defaultFurnitureStatic.instantiate()
		newFurniture.add_to_group("furniture")
		newFurniture.set_sprite(Gamedata.data.furniture.sprites[furnitureJSON.sprite])
		get_tree().get_root().add_child(newFurniture)
		newFurniture.global_position.x = block.global_position.x
		newFurniture.global_position.y = block.global_position.y + 0.5
		newFurniture.global_position.z = block.global_position.z

		if tileJSON.furniture.has("rotation"):
			newFurniture.set_new_rotation(tileJSON.furniture.rotation)
		else:
			newFurniture.set_new_rotation(0)
		newFurniture.id = furnitureJSON.id

func apply_block_rotation(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("rotation"):
		if tileJSON.rotation != 0:
			# We subtract 90 so we know that north is 
			# on the top of the screen
			# The default block has a y rotation of 90
			# So it is already pointing north (0 = 90)
			# 90 = 0 - points east
			# 180 (we add 90 instead of subtract) = 270 = south
			# 270 = 180 - points west
			var myRotation: int = tileJSON.rotation
			if myRotation == 180:
				block.rotation_degrees = Vector3(0,myRotation+90,0)
			else:
				block.rotation_degrees = Vector3(0,myRotation-90,0)

func add_block_mob(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("mob"):
		var newMob: CharacterBody3D = defaultMob.instantiate()
		newMob.add_to_group("mobs")
		get_tree().get_root().add_child(newMob)
		newMob.global_position.x = block.global_position.x
		newMob.global_position.y = block.global_position.y + 0.5
		newMob.global_position.z = block.global_position.z
		#if tileJSON.mob.has("rotation"):
			#newMob.rotation_degrees.y = tileJSON.mob.rotation
		newMob.apply_stats_from_json(Gamedata.get_data_by_id(\
		Gamedata.data.mobs, tileJSON.mob.id))

# This function takes a tile id and creates a new instance of either a block
# or a slope which is a StaticBody3D. Look up the sprite property that is specified in
# the json associated with the id. It will then take the sprite from the 
# sprite dictionary based on the provided spritename and apply it 
# to the instance of StaticBody3D. Lastly it will return the StaticBody3D.
func create_block_with_id(id: String) -> StaticBody3D:
	var block: StaticBody3D
	var tileJSONData = Gamedata.data.tiles
	var tileJSON = tileJSONData.data[Gamedata.get_array_index_by_id(tileJSONData,id)]
	if tileJSON.has("shape"):
		if tileJSON.shape == "slope":
			block = defaultSlope.instantiate()
		else:
			block = defaultBlock.instantiate()
	else:
		block = defaultBlock.instantiate()
	# Remmeber the id for save and load purposes
	block.id = id
		
		
	#tileJSON.sprite is the 'sprite' key in the json that was found for this tile
	#If the sprite is found in the tile sprites, we assign it.
	if tileJSON.sprite in Gamedata.data.tiles.sprites:
		var material = Gamedata.data.tiles.sprites[tileJSON.sprite]
		block.update_texture(material)
	return block

