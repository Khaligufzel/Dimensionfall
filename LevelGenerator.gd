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
@export var level_manager : Node3D
@export_file var default_level_json



# Called when the node enters the scene tree for the first time.
func _ready():
	generate_map()
	$"../NavigationRegion3D".bake_navigation_mesh()
	
func generate_map():
	map_save_folder = Helper.save_helper.get_saved_map_folder(Helper.current_level_pos)
	generate_level()
	# These two functions apply only to maps thet were previously saved in a save game
	generate_mobs()
	generate_items()
	

func generate_mobs() -> void:
	if map_save_folder == "":
		return
	var mobsArray = Helper.json_helper.load_json_array_file(map_save_folder + "/mobs.json")
	for mob: Dictionary in mobsArray:
		add_mob_to_map.call_deferred(mob)

func add_mob_to_map(mob: Dictionary) -> void:
	var newMob: CharacterBody3D = defaultMob.instantiate()
	newMob.add_to_group("mobs")
	newMob.set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.mobs,mob.id))
	get_tree().get_root().add_child(newMob)
	newMob.global_position.x = mob.global_position_x
	newMob.global_position.y = mob.global_position_y
	newMob.global_position.z = mob.global_position_z
	newMob.id = mob.id

func generate_items() -> void:
	if map_save_folder == "":
		return
	var itemsArray = Helper.json_helper.load_json_array_file(map_save_folder + "/items.json")
	for item: Dictionary in itemsArray:
		add_item_to_map.call_deferred(item)
		
func add_item_to_map(item: Dictionary):
	var newItem: Node3D = defaultItem.instantiate()
	newItem.add_to_group("mapitems")
	get_tree().get_root().add_child(newItem)
	newItem.global_position.x = item.global_position_x
	newItem.global_position.y = item.global_position_y
	newItem.global_position.z = item.global_position_z
	newItem.get_node(newItem.inventory).deserialize(item.inventory)

# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_level() -> void:
	var level_name: String = Helper.current_level_name
	var tileJSON: Dictionary = {}
	if level_name == "":
		get_level_json()
	else:
		# Load the default map from json
		# Unless the map_save_folder is set
		# In which case we load tha map instead
		if map_save_folder == "":
			get_custom_level_json("./Mods/Core/Maps/" + level_name)
		else:
			get_custom_level_json(map_save_folder + "/map.json")
	
	
	var level_number = 0
	#we need to generate level layer by layer starting from the bottom
	for level in level_levels:
		if level != []:
			var level_node = Node3D.new()
			level_node.add_to_group("maplevels")
			level_manager.add_child(level_node)
			#The lowest level starts at -10 which would be rock bottom
			level_node.global_position.y = level_number-10
			
			var current_block = 0
			# we will generate number equal to "layer_height" of horizontal rows of blocks
			for h in level_height:
				
				# this loop will generate blocks from West to East based on the tile number
				# in json file

				for w in level_width:
					# checking if we have tile from json in our block array containing packedscenes
					# of blocks that we need to instantiate.
					# If yes, then instantiate
					if level[current_block]:
						tileJSON = level[current_block]
						if tileJSON.has("id"):
							if tileJSON.id != "":
								var block: StaticBody3D = create_block_with_id(tileJSON.id)
								level_node.add_child(block)
								block.global_position.x = w
								block.global_position.z = h
								# Remmeber the id for save and load purposes
								block.id = tileJSON.id
								apply_block_rotation(tileJSON, block)
								add_block_mob(tileJSON, block)
					current_block += 1
		level_number += 1

	# YEAH I KNOW THAT SHOULD BE ONE FUNCTION, BUT IT'S 2:30 AM and... I'm TIRED LOL
func get_level_json():
	var file = default_level_json
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict: Dictionary = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]
	level_width = json_as_dict["mapwidth"]
	level_width = json_as_dict["mapheight"]

func get_custom_level_json(level_path):
	var file = level_path
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]


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
		newMob.set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.mobs,tileJSON.mob))
		get_tree().get_root().add_child(newMob)
		newMob.global_position.x = block.global_position.x
		newMob.global_position.y = block.global_position.y+0.5
		newMob.global_position.z = block.global_position.z


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
		
		
	#tileJSON.sprite is the 'sprite' key in the json that was found for this tile
	#If the sprite is found in the tile sprites, we assign it.
	if tileJSON.sprite in Gamedata.data.tiles.sprites:
		var material = Gamedata.data.tiles.sprites[tileJSON.sprite]
		block.update_texture(material)
	return block

