extends Node3D


# This script is supposed to work with the Chunk scene
# This script will manage the internals of a map chunk
# A chunk is made up of blocks, slopes, furniture and mobs
# The first time a chunk is loaded, it will be from a map definition
# Each time after that, it will load whatever whas saved when the player exited the map
# When the player exits the map, the chunk will get saved so it can be loaded later
# During the game chunks will be loaded and unloaded to improve performance
# A chunk is defined by 21 levels and each level can potentially hold 32x32 blocks
# On top of the blocks we spawn mobs and furniture
# Loading and unloading of chunks is managed by levelGenerator.gd




@export var defaultBlock: PackedScene = preload("res://Defaults/Blocks/default_block.tscn")
@export var defaultSlope: PackedScene = preload("res://Defaults/Blocks/default_slope.tscn")
@export var defaultMob: PackedScene
@export var defaultItem: PackedScene
@export var defaultFurniturePhysics: PackedScene
@export var defaultFurnitureStatic: PackedScene


var level_width : int = 32
var level_height : int = 32
var _levels: Array = []


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func generate_chunk(segment_x: int, segment_z: int, mapsegment: Dictionary):
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
			level_node.add_to_group("maplevels")
			add_child(level_node)
			_levels.append(level_node)
			level_node.global_position.y = level_number - 10

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



# When the map is created for the first time, we will apply block rotation
# This function will not be called when a map is loaded
func apply_block_rotation(tileJSON: Dictionary, block: StaticBody3D):
	# The slope has a default rotation of 90
	# The block has a default rotation of 0
	var myRotation: int = tileJSON.get("rotation", 0) + block.rotation_degrees.y
	if myRotation == 0:
		# Only the block will match this case, not the slope. The block points north
		block.rotation_degrees = Vector3(0,myRotation+180,0)
	elif myRotation == 90:
		# A slope will point north
		# A block will point east
		block.rotation_degrees = Vector3(0,myRotation+0,0)
	elif myRotation == 180:
		# A block will point south
		# A slope will point east
		block.rotation_degrees = Vector3(0,myRotation-180,0)
	elif myRotation == 270:
		# A block will point west
		# A slope will point south
		block.rotation_degrees = Vector3(0,myRotation+0,0)
	elif myRotation == 360:
		# Only a slope can match this case
		block.rotation_degrees = Vector3(0,myRotation-180,0)



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



func add_furniture_to_block(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("furniture"):
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
		Gamedata.data.furniture, tileJSON.furniture.id)
		var furnitureSprite: Texture = Gamedata.data.furniture.sprites[furnitureJSON.sprite]
		
		# Calculate the size of the furniture based on the sprite dimensions
		var spriteWidth = furnitureSprite.get_width() / 100.0 # Convert pixels to meters (assuming 100 pixels per meter)
		var spriteDepth = furnitureSprite.get_height() / 100.0 # Convert pixels to meters
		
		var edgeSnappingDirection = furnitureJSON.get("edgesnapping", "None")
		var newRot = tileJSON.furniture.get("rotation", 0)
		
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = defaultFurniturePhysics.instantiate()
		else:
			newFurniture = defaultFurnitureStatic.instantiate()
		
		newFurniture.add_to_group("furniture")
		
		# Set the sprite and adjust the collision shape
		newFurniture.set_sprite(furnitureSprite)
		
		add_child(newFurniture)
		
		# Position furniture at the center of the block by default
		var furniturePosition = block.global_position
		furniturePosition.y += 0.5 # Slightly above the block
		
		# Apply edge snapping if necessary
		if edgeSnappingDirection != "None":
			furniturePosition = apply_edge_snapping(furniturePosition, edgeSnappingDirection, spriteWidth, spriteDepth, newRot, block)
		
		newFurniture.global_position = furniturePosition
		
		if tileJSON.furniture.has("rotation"):
			newFurniture.set_new_rotation(tileJSON.furniture.rotation)
		else:
			newFurniture.set_new_rotation(0)
		
		newFurniture.id = furnitureJSON.id



func apply_edge_snapping(newpos, direction, width, depth, newRot, block):
	# Block size, assuming a block is 1x1 meters
	var blockSize = Vector3(1.0, 1.0, 1.0)
	
	# Adjust position based on edgesnapping direction and rotation
	match direction:
		"North":
			newpos.z -= blockSize.z / 2 - depth / 2
		"South":
			newpos.z += blockSize.z / 2 - depth / 2
		"East":
			newpos.x += blockSize.x / 2 - width / 2
		"West":
			newpos.x -= blockSize.x / 2 - width / 2
		# Add more cases if needed
	
	# Consider rotation if necessary
	newpos = rotate_position_around_block_center(newpos, newRot, block.global_position)
	
	return newpos



func rotate_position_around_block_center(newpos, newRot, block_center):
	# Convert rotation to radians for trigonometric functions
	var radians = deg_to_rad(newRot)
	
	# Calculate the offset from the block center
	var offset = newpos - block_center
	
	# Apply rotation matrix transformation
	var rotated_offset = Vector3(
		offset.x * cos(radians) - offset.z * sin(radians),
		offset.y,
		offset.x * sin(radians) + offset.z * cos(radians)
	)
	
	# Return the new position
	return block_center + rotated_offset
