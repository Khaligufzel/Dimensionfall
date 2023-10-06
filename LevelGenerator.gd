extends Node3D

var level_name



var level_json_as_text

var level_layers : Array

@export var layer_width : int = 32
@export var layer_height : int = 32


@export var level_manager : Node3D
@export var block_scenes : Array[PackedScene]
@export_file var default_level_json



# Called when the node enters the scene tree for the first time.
func _ready():
	level_name = Helper.current_level_name
	generate_level()
	
func generate_level():
	
	if level_name == "":
		get_level_json()
	else:
		get_custom_level_json("user://levels/" + level_name)
	
	
	var layer_number = 0
	#we need to generate level layer by layer starting from the bottom
	for layer in level_layers:
		var layer_node = Node3D.new()
		level_manager.add_child(layer_node)
		layer_node.global_position.y = layer_number
		
		
		var current_block = 0
		
		# we will generate number equal to "layer_height" of horizontal rows of blocks
		for h in layer_height:
			
			# this loop will generate blocks from West to East based on the tile number
			# in json file

			
			for w in layer_width:
				
				# checking if we have tile from json in our block array containing packedscenes
				# of blocks that we need to instantiate.
				# If yes, then instantiate
				
				if block_scenes[layer["data"][current_block]-1]:
					
					if layer["data"][current_block]-1 >= 0:
						var block : StaticBody3D
						block = block_scenes[layer["data"][current_block]-1].instantiate()
						
						layer_node.add_child(block)
						
						block.global_position.x = w
						#block.global_position.y = layer_number
						block.global_position.z = h
				current_block += 1
			
		layer_number += 1
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	
	
	# YEAH I KNOW THAT SHOULD BE ONE FUNCTION, BUT IT'S 2:30 AM and... I'm TIRED LOL
func get_level_json():
	var file = default_level_json
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(level_json_as_text)
	level_layers = json_as_dict["layers"]

func get_custom_level_json(level_path):
	var file = level_path
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(level_json_as_text)
	level_layers = json_as_dict["layers"]
