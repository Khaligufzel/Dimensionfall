extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
@export var overmapTile: PackedScene = null
@export var overmapTileLabel: Label = null


var noise = FastNoiseLite.new()
var grid_chunks: Dictionary = {} # Stores references to grid containers (visual tile grids)
var chunk_width: int = 8  # Smaller chunk sizes improve performance
var chunk_size: int = 8
var tile_size: int = 32
var grid_pixel_size: int = chunk_size * tile_size
var selected_overmap_tile: Control = null
var chunk_pool: Array = []  # Pool to store unloaded GridChunks
var text_visible_by_coord: Dictionary = {}  # Tracks text visibility
var target: Target = null  # Holds the target location as an instance of the Target class
# Variable to store the current offset in the main script
var current_offset: Vector2 = Vector2.ZERO  # Holds the current screen offset

# We will emit this signal when the position_coords change
# Which happens when the user has panned the overmap
signal position_coord_changed()

# Target location for quests
class Target:
	var map_id: String
	var coordinate: Vector2

	# Constructor to initialize the map_id and coordinate
	func _init(mymap_id: String, mycoordinate: Vector2):
		self.map_id = mymap_id
		self.coordinate = mycoordinate

	# Prevent modifying the coordinate after it has been set
	func set_coordinate(new_coordinate: Vector2):
		if self.coordinate == Vector2():  # Only set if the coordinate hasn't been initialized
			self.coordinate = new_coordinate


# Define the inner class that handles grid container properties and logic
class GridChunk:
	var grid_container: GridContainer
	var chunk_position: Vector2
	var grid_position: Vector2
	var tile_size: int
	var chunk_width: int = 8  # Smaller chunk sizes improve performance
	var chunk_size: int = 8
	var tile_dictionary: Dictionary  # Dictionary to store tiles by their global_pos
	var overmapTile: PackedScene = null
	var visible_tile: Control = null  # Stores the currently visible tile with text
	var offset: Vector2 = Vector2.ZERO  # Default offset is zero
	var overmap_node  # Reference to the overmap node


	# Constructor to initialize the chunk with its grid position, chunk position, and necessary references
	# Expects this dictionary:
	# {
	# 	"mygrid_position": mygrid_position: Vector2,
	# 	"mychunk_position": mychunk_position: Vector2,
	# 	"mytile_size": mytile_size: int,
	# 	"myovermapTile": myovermapTile: PackedScene,
	# 	"overmap_node": overmap_node: Control
	# }
	func _init(properties: Dictionary):
		self.grid_position = properties.mygrid_position # Local grid position. Ex. (0,0),(0,1),(1,1)
		self.chunk_position = properties.mychunk_position # Global grid position ex. (0,0),(0,256),(256,256)
		self.tile_size = properties.mytile_size
		self.grid_container = GridContainer.new()
		self.grid_container.columns = chunk_width
		self.overmapTile = properties.myovermapTile
		self.overmap_node = properties.overmap_node
		self.grid_container.set("theme_override_constants/h_separation", 0)
		self.grid_container.set("theme_override_constants/v_separation", 0)
		self.tile_dictionary = {}  # Initialize the dictionary
		# Connect to the player_coord_changed signal from Helper.overmap_manager
		Helper.overmap_manager.player_coord_changed.connect(_on_player_coord_changed)
		self.create_tiles()  # Create tiles when the chunk is initialized
		self.redraw_tiles()
		on_position_coord_changed()

	# Function to create tiles for the chunk
	func create_tiles():
		for y in range(chunk_size):
			for x in range(chunk_size):
				var tile = overmapTile.instantiate()  # Create a new tile instance

				# Connect the tile's clicked signal to the _on_tile_clicked function
				tile.tile_clicked.connect(overmap_node._on_tile_clicked)
				# Add the tile to the grid container and dictionary
				grid_container.add_child(tile)
				tile_dictionary[Vector2(x, y)] = tile  # Store tile by its x, y coordinates

	# Reset chunk to a new position and redraw its tiles
	func reset_chunk(new_grid_position: Vector2, new_chunk_position: Vector2):
		self.grid_position = new_grid_position
		self.chunk_position = new_chunk_position
		self.set_position(new_chunk_position)
		self.redraw_tiles()

	# Redraw the tiles based on the new grid position
	func redraw_tiles():
		for y in range(chunk_size):
			for x in range(chunk_size):
				var global_pos = grid_position + Vector2(x, y)
				var tile = tile_dictionary[Vector2(x, y)]

				# Set the tile color based on its global position
				if global_pos == Vector2.ZERO:
					tile.set_color(Color(0.3, 0.3, 1))  # Blue color for tile at (0,0)
				else:
					tile.set_color(Color(1, 1, 1))  # White color for other tiles
				tile.set_text("")
				# Use the same function to update tile based on its position and player location
				update_tile_texture_and_reveal(tile, global_pos, Helper.overmap_manager.player_current_cell)

	func on_position_coord_changed():
		update_absolute_position()
		# Update tile text visibility based on the player's new position
		update_tile_text_visibility()

	# Function inside GridChunk to calculate and set its absolute position in pixels based on the player's position
	func update_absolute_position():
		# Calculate the chunk's absolute position in pixels
		var chunk_pixel_position: Vector2 = (grid_position - Helper.position_coord) * tile_size
		# Update the chunk's position based on the player's position and offset
		set_position(chunk_pixel_position)

	# This method sets the position of the grid container and applies the offset
	func set_position(new_position: Vector2):
		# Apply the offset when setting the position
		self.grid_container.position = new_position + offset

	# Function to update the chunk's offset
	func update_offset(new_offset: Vector2):
		offset = new_offset
		update_absolute_position()

	# Function to find a tile within this chunk based on a global position
	func get_tile_at_position(global_pos: Vector2) -> Control:
		var local_pos = calculate_local_pos(global_pos)  # Use the new function
		if tile_dictionary.has(local_pos):
			return tile_dictionary[local_pos]
		return null

	# Function to find a tile within this chunk based on a global coordinate
	# Coordinates are managed by Helper.overmap_manager. When the player moves from (0,0)
	# to (0,1), he will have traversed 32 units in-game
	func get_tile_at_coordinate(coord: Vector2) -> Control:
		var local_pos = coord - grid_position
		if tile_dictionary.has(local_pos):
			return tile_dictionary[local_pos]
		return null

	# Function to check if the chunk has a tile at a specific global position
	func has_tile_at_position(global_pos: Vector2) -> bool:
		var local_pos = calculate_local_pos(global_pos)  # Use the new function
		return tile_dictionary.has(local_pos)
	
	# Function to calculate local position from a global position
	func calculate_local_pos(global_pos: Vector2) -> Vector2:
		# Calculate the local position within the chunk
		return (global_pos - chunk_position) / tile_size

	# Function to check if a global position is within this chunk
	func is_position_in_chunk(global_pos: Vector2) -> bool:
		var chunk_end = grid_position + Vector2(chunk_size, chunk_size)
		return global_pos.x >= grid_position.x and global_pos.x < chunk_end.x and \
			   global_pos.y >= grid_position.y and global_pos.y < chunk_end.y

	# Function to update the tile's text visibility based on the player's last known position
	func update_tile_text_visibility():
		# Hide the text on the previously visible tile, if any
		if visible_tile:
			visible_tile.set_text("")
			visible_tile = null

		# Check if the player's last known position is within this chunk's bounds
		if is_position_in_chunk(Helper.overmap_manager.player_current_cell):
			# Calculate the local position of the player within the chunk
			var local_pos = Helper.overmap_manager.player_current_cell - grid_position
			if tile_dictionary.has(local_pos):
				# The player is on this tile, so we put the player marker as text
				var tile = tile_dictionary[local_pos]
				tile.set_text("✠")
				visible_tile = tile  # Store the reference to the new visible tile

	func _on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
		if overmap_node and not overmap_node.is_visible():
			return
		# Step 1: Check if the chunk is within the player's range
		if is_within_player_range():
			# Step 2: Iterate through each tile in the chunk
			for y in range(chunk_size):
				for x in range(chunk_size):
					var global_pos = grid_position + Vector2(x, y)
					var tile = tile_dictionary[Vector2(x, y)]
					# Call the combined function to update the tile and reveal the map cell
					update_tile_texture_and_reveal(tile, global_pos, new_pos)

	# This function handles both revealing the map cell and updating the tile's texture
	# It is used by both the player position update and regular map tile updates
	# NOTE: I've seen this function be called 576 times in a frame in the profiler, leading to 
	# 576 set_texture calls for the affected overmap tiles. In total, this can cause up to 90ms for 
	# the frame. This is because each tile is processed in _on_player_coord_changed. Maybe we 
	# can find a way to reduce the amount of calls for set_texture
	func update_tile_texture_and_reveal(tile: Control, global_pos: Vector2, player_position: Vector2):
		# Get the map cell from overmap_manager
		var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(global_pos)
		
		if not map_cell:
			# If no map cell is found, reset the map_cell on the tile and clear the texture
			tile.map_cell = null  # Reset map_cell to an empty dictionary
			return

		# Calculate distance to player
		var distance_to_player = global_pos.distance_to(player_position)
		
		if distance_to_player <= 8:
			# Reveal the map cell if within the player's range
			map_cell.reveal()

		# Assign the map_cell to the tile and let the tile handle texture and rotation
		tile.map_cell = map_cell


	# Function to check if the player's last position falls within the range of this chunk's grid area
	func is_within_player_range() -> bool:
		# Get the player's last known position from the overmap manager
		var player_current_cell = Helper.overmap_manager.player_current_cell

		# Define the chunk bounds: from grid_position to grid_position + chunk_size
		var chunk_start = grid_position
		var chunk_end = grid_position + Vector2(chunk_size, chunk_size)

		# Check if the player's position falls within the chunk's bounds with a radius of 8
		if player_current_cell.x >= chunk_start.x - 8 and player_current_cell.x <= chunk_end.x + 8 and \
		   player_current_cell.y >= chunk_start.y - 8 and player_current_cell.y <= chunk_end.y + 8:
			return true
		return false


func get_localized_position(chunk_grid_position: Vector2) -> Vector2:
	var cchunk: Vector2 = chunk_grid_position * tile_size
	var ctile: Vector2 = Helper.position_coord * tile_size
	return cchunk - ctile


func _ready():
	# Centers the view when opening the ovemap.
	Helper.position_coord = Vector2(0, 0)
	update_chunks()
	connect_signals()


# Connect necessary signals
func connect_signals():
	position_coord_changed.connect(on_position_coord_changed)
	Helper.overmap_manager.player_coord_changed.connect(on_player_coord_changed)
	# Connect the visibility toggling signal
	visibility_changed.connect(on_overmap_visibility_toggled)
	# Connect to the target_map_changed signal from the quest helper
	Helper.quest_helper.target_map_changed.connect(on_target_map_changed)


# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
func update_chunks():
	# Convert the current position to grid coordinates based on the chunk size
	# The grid position will move 8 over when the Helper_coord passes the last tile
	# The grid_position will be 0,0 between 0,0 and 7,7 if chunk_size = 8
	# The grid_position will be 1,0 between 8,0 and 15,7 if chunk_size = 8
	var grid_position: Vector2 = (Helper.position_coord / chunk_size).floor() * chunk_size

	for x in range(-3, 4):
		for y in range(-2, 3):
			var chunk_grid_position: Vector2 = grid_position + Vector2(x, y) * chunk_size

			# If the chunk doesn't exist, reuse from pool or create a new one
			if not grid_chunks.has(chunk_grid_position):
				var new_chunk: GridChunk
				if chunk_pool.size() > 0:
					# Reuse a chunk from the pool
					new_chunk = chunk_pool.pop_back()
					new_chunk.reset_chunk(chunk_grid_position, get_localized_position(chunk_grid_position))
				else:
					
					var chunkproperties: Dictionary = {
						"mygrid_position": chunk_grid_position,
						"mychunk_position": get_localized_position(chunk_grid_position),
						"mytile_size": tile_size,
						"myovermapTile": overmapTile,
						"overmap_node": self
					}
					# Create a new chunk if the pool is empty
					new_chunk = GridChunk.new(chunkproperties)
					new_chunk.overmap_node = self
					# Connect the position_coord_changed signal to the GridChunk's update_absolute_position function
					position_coord_changed.connect(new_chunk.on_position_coord_changed)

				# Check if the grid_container is already a child before adding it
				if new_chunk.grid_container.get_parent() == null:
					tilesContainer.add_child(new_chunk.grid_container)
				# Set the chunk's offset to the current global offset
				new_chunk.update_offset(current_offset)


				grid_chunks[chunk_grid_position] = new_chunk

	# Unload chunks that are out of view
	unload_chunks()


func unload_chunks():
	var range_limit = 7 * chunk_size
	var chunks_to_remove: Array = []

	# Find chunks that are too far away
	for chunk_position in grid_chunks.keys():
		if chunk_position.distance_to(Helper.position_coord) > range_limit:
			var gridchunk: GridChunk = grid_chunks[chunk_position]
			# Reset the chunk and move it to the pool
			chunk_pool.append(gridchunk)  # Add to the pool for reuse
			chunks_to_remove.append(chunk_position)

	# Remove the chunks from the dictionary after unloading
	for chunk_position in chunks_to_remove:
		grid_chunks.erase(chunk_position)


# Function to handle keyboard input for moving the overmap
func _input(event):
	if not visible:
		return
	if event is InputEventKey:
		var delta = Vector2.ZERO
		if event.is_pressed():
			match event.keycode:
				KEY_UP:
					delta = Vector2(0, -1)
				KEY_DOWN:
					delta = Vector2(0, 1)
				KEY_LEFT:
					delta = Vector2(-1, 0)
				KEY_RIGHT:
					delta = Vector2(1, 0)
		if delta != Vector2.ZERO:
			move_overmap(delta)


# Function to move the overmap by adjusting the position_coord
func move_overmap(delta: Vector2):
	var new_position_coord = (Helper.position_coord + delta).round()
	delta = new_position_coord - Helper.position_coord
	if delta != Vector2.ZERO:
		Helper.position_coord = new_position_coord
		position_coord_changed.emit()


# We will call this function when the position_coords change
func on_position_coord_changed():
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(Helper.position_coord)

	# Check and update the marker or arrow if the target is set
	if target != null:
		find_location_on_overmap(target)
	else:
		$ArrowLabel.visible = false  # Hide arrow if there's no target


# This function will be connected to the signal of the tiles
func _on_tile_clicked(clicked_tile):
	if clicked_tile.map_cell:
		overmapTileLabel.text = clicked_tile.map_cell.get_info_string()
	else: 
		selected_overmap_tile = null
		overmapTileLabel.text = "Select a valid target"


# The player presses the home button, sending the overmap view to (0,0)
func _on_home_button_button_up():
	# Update position_coord to the new position
	Helper.position_coord = Vector2(0,0)
	# Emit the signal to update the overmap's position and tiles
	position_coord_changed.emit()


# Function to find the overmap tile at the given position
# myposition: The global cell coordinate. The cell coordinates are managed by overmap_manager.
# For example, the player starts at (0,0) and the chunk he's in will have chunk_size cells
# If the player moves 32 units to the east, he will be in (0,1).
func get_overmap_tile_at_position(myposition: Vector2) -> Control:
	# Calculate the chunk position based on tile size and chunk size
	var chunk_pos = (myposition / chunk_size).floor() * chunk_size
	
	# Check if the chunk exists in grid_chunks
	if grid_chunks.has(chunk_pos):
		var chunk: GridChunk = grid_chunks[chunk_pos]
		# Delegate the tile lookup to the GridChunk's dictionary lookup
		return chunk.get_tile_at_coordinate(myposition)
	
	# Return null if the tile is not found in the corresponding chunk
	return null


# When the player moves a coordinate on the map, i.e. when crossing the chunk border.
# Movement could be between (0,0) and (0,1) for example
func on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
	if not visible:
		return
	var delta = new_pos - Helper.position_coord
	move_overmap(delta)


# Set the target. The target comes from the player reaching a "travel" step in a quest
func set_target(map_id: String, coordinate: Vector2):
	if target == null:
		target = Target.new(map_id, coordinate)  # Create a new target


# Function to handle overmap visibility toggling
func on_overmap_visibility_toggled():
	if visible:
		# Force update of the player position and chunks
		# This will cause the player_coord_changed signal to be emitted,
		# triggering on_position_coord_changed and centering the map on the player's position
		Helper.overmap_manager.update_player_position_and_manage_segments(true)
		_on_tiles_container_resized.call_deferred()


# Function to assist the player in finding a location based on the map_id
func find_location_on_overmap(mytarget: Target):
	# Check if mytarget's coordinate is set
	if mytarget.coordinate == Vector2():
		# If not set, find the closest map cell and set the coordinates
		var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_ids([mytarget.map_id], "VISITED")
		if closest_cell:
			mytarget.set_coordinate(Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y))
		else:
			$ArrowLabel.visible = false  # Hide arrow if no target is found
			return

	# Use the new function to check visibility after setting the target
	check_target_tile_visibility()


# Displays an arrow at the edge of the overmap window pointing towards the direction of the cell
func show_directional_arrow_to_cell(cell_position: Vector2):
	# Calculate overmap center in pixels using Helper.position_coord, which now refers to the center tile
	var overmap_center_in_pixels = (Helper.position_coord * tile_size)

	# Calculate the target position in pixels
	var target_position_in_pixels = cell_position * tile_size

	# Calculate the direction from the center of the overmap to the target
	var direction_to_cell = (target_position_in_pixels - overmap_center_in_pixels).normalized()

	# Get the arrow Control
	var arrow = $ArrowLabel
	arrow.rotation = direction_to_cell.angle()

	# Position the arrow at the center of tilesContainer
	var center_of_container = tilesContainer.size / 2

	# Apply directional offset to position the arrow based on the direction and container size
	var arrow_position = center_of_container + direction_to_cell * (tilesContainer.size / 2)

	# Clamp the position to the container's bounds
	arrow_position = clamp_arrow_to_container_bounds(arrow_position)

	# Set arrow position and make it visible
	arrow.position = arrow_position
	arrow.visible = true


# Helper function to clamp the arrow to the edges of the TilesContainer with 
# extra margin on the left side
func clamp_arrow_to_container_bounds(arrow_position: Vector2) -> Vector2:
	var container_size = tilesContainer.size
	var arrow_size = $ArrowLabel.size  # Get the size of the arrow label to use as the margin

	# Apply extra margin on the left side
	var left_margin = arrow_size.x  # Extra margin is the size of the arrow label

	# Clamp the arrow position within the bounds of the tilesContainer, adding extra margin on the left
	arrow_position.x = clamp(arrow_position.x, left_margin, container_size.x - arrow_size.x / 2)
	arrow_position.y = clamp(arrow_position.y, arrow_size.y / 2, container_size.y - arrow_size.y / 2)
	
	return arrow_position


func _on_tiles_container_resized() -> void:
	# Position the arrow at the center of tilesContainer
	var center_of_container = tilesContainer.size / 2
	# Update the offset for all chunks
	update_offset_for_all_chunks(center_of_container)
	# Check if the target tile has become visible after the resize
	check_target_tile_visibility.call_deferred()


# Updates the target display to be an arrow or an X depending on wheter or not
# the target is in visible area of the overmap
func check_target_tile_visibility() -> void:
	if target:
		# Try to get the tile at the target's coordinate
		var target_tile = get_overmap_tile_at_position(target.coordinate)
		
		if target_tile:
			# Calculate the tile's position and the visible area
			var tile_pos = target_tile.get_global_position() - tilesContainer.get_global_position()
			var visible_rect = Rect2(Vector2.ZERO, tilesContainer.size)
			
			# Check if the target tile is now visible
			if visible_rect.has_point(tile_pos):
				# If the tile is visible, hide the arrow and show the tile text
				target_tile.set_text("X")
				$ArrowLabel.visible = false
			else:
				# If the tile is still not visible, ensure the arrow is displayed
				show_directional_arrow_to_cell(target.coordinate)
		else:
			# If no tile found, treat it as invisible and show the arrow
			show_directional_arrow_to_cell(target.coordinate)


# Updates the current offset globally, called when the window is resized
func update_offset_for_all_chunks(new_offset: Vector2):
	current_offset = new_offset
	for chunk in grid_chunks.values():
		chunk.update_offset(current_offset)


# Respond to the target_map_changed signal
# map_ids: An array of map IDs that are potential targets.
# target_properties: A dictionary containing:
#   - reveal_condition (String): One of "HIDDEN", "REVEALED", "EXPLORED", "VISITED".
#     Determines how the target is selected based on its reveal state.
#   - exact_match (bool, default: false): If true, only exact matches for the reveal_condition are valid.
#   - dynamic (bool, default: false): If true, and the player is currently on the target cell,
#     a new target will be selected.
func on_target_map_changed(map_ids: Array, target_properties: Dictionary = {}):
	if map_ids.is_empty():
		if target:
			set_coordinate_text(target.coordinate, "")
		target = null  # Clear the target if no valid map_ids are provided
		$ArrowLabel.visible = false  # Hide arrow when no target
	else:
		# Extract properties from target_properties with defaults
		var dynamic: bool = target_properties.get("dynamic", false)

		# Find the closest cell for the provided map_ids
		if target:
			var at_target: bool = Helper.overmap_manager.is_player_at_position(Vector2(target.coordinate.x, target.coordinate.y))
			# Handle dynamic targeting: If the player is on the target, find a new target
			if dynamic and at_target:
				target = null # reset the target
		var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_ids(map_ids, target_properties)

		if closest_cell and target == null:
			# Set the new target
			target = Target.new(closest_cell.map_id, Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y))
			# Ensure that the coordinates do not change once set
			find_location_on_overmap(target)


# Updates a tile based on the coordinate and text
# mycoordinate: A Vector2 using the global grid coordinate. Coordinates are managed by overmap_manager
# mytext: The text to set on the tile at the coordinate
func set_coordinate_text(mycoordinate: Vector2, mytext: String):
	var tile = get_overmap_tile_at_position(mycoordinate)
	if tile:
		tile.set_text(mytext)
