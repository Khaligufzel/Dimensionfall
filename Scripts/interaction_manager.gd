extends Node

var tile_map : TileMap
var tile

var interaction_object_door = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	tile_map = get_tree().get_first_node_in_group("TileMap")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func try_to_interact_with(collision_result):
	#print(tile_map.local_to_map(collision_result.position))
	
	#getting tile position from the collision
	var tile_pos = tile_map.local_to_map(collision_result.position)
	
	#checking if the tile is interactable
	var tile_data : TileData = tile_map.get_cell_tile_data(1, tile_pos)
	
	if tile_data:
		print("This tile has data in it")
		if tile_data.get_custom_data("InteractionObjectId") == 1:
			print("This tile contains door")
