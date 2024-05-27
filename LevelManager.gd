extends Node3D

  # Initialize with a value that's unlikely to be a valid starting Y-level
var last_player_y_level: float = -1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var player = get_tree().get_first_node_in_group("Players")
	if player:
		var current_player_y = player.global_position.y

		# Check if the player's Y-level has changed
		if current_player_y != last_player_y_level:
			update_visibility(current_player_y)
			last_player_y_level = current_player_y

func update_visibility(player_y: float):
	# Update level visibility
	for level in get_tree().get_nodes_in_group("maplevels"):
		var is_above_player = level.y > player_y
		level.visible = not is_above_player

	# Update furniture visibility
	for furniture in get_tree().get_nodes_in_group("furniture"):
		var is_above_player = furniture.global_position.y > player_y
		furniture.visible = not is_above_player

	# Update container visibility
	for container in get_tree().get_nodes_in_group("Containers"):
		var is_above_player = container.global_position.y > player_y
		container.visible = not is_above_player
