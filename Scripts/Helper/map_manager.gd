extends Node

# This script manages the tacticalmap, where the player is playing in.
# It is part of the Helper singleton and can be accessed by Helper.map_manager
# It keeps track of entities on the map
# It can add and remove entities on the map
# It can check what's around the player in terms of blocks and furniture

# We keep a reference to the level_generator, which holds the chunks
# The level generator will register itself to this variable when it's ready
var level_generator: Node = null
	
func get_chunk_from_position(position_in_3d_space: Vector3) -> Chunk:
	return level_generator.get_chunk_from_position(position_in_3d_space)
