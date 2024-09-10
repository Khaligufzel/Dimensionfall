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
var previous_visible_tile: Control = null  # Stores the previously visible tile
var chunk_pool: Array = []  # Pool to store unloaded GridChunks
var text_visible_by_coord: Dictionary = {}  # Tracks text visibility
var target: Target = null  # Holds the target location as an instance of the Target class
# Variable to store the current offset in the main script
var current_offset: Vector2 = Vector2.ZERO  # Holds the current screen offset

# We will emit this signal when the position_coords change
# Which happens when the user has panned the overmap
signal position_coord_changed(delta: Vector2)

# Target location for quests
class Target:
	var map_id: String
	var coordinate: Vector2

	# Constructor to initialize the map_id and coordinate
	func _init(mymap_id: String, mycoordinate: Vector2):
		print_debug("initialized target with " + map_id)
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


	# Constructor to initialize the chunk with its grid position, chunk position, and necessary references
	func _init(mygrid_position: Vector2, mychunk_position: Vector2, mytile_size: int, myovermapTile: PackedScene):
		self.grid_position = mygrid_position # Local grid position. Ex. (0,0),(0,1),(1,1)
		self.chunk_position = mychunk_position # Global grid position ex. (0,0),(0,256),(256,256)
		self.tile_size = mytile_size
		self.grid_container = GridContainer.new()
		self.grid_container.columns = chunk_width
		self.overmapTile = myovermapTile
		self.grid_container.set("theme_override_constants/h_separation", 0)
		self.grid_container.set("theme_override_constants/v_separation", 0)
		# Use set_position to apply the fixed offset to the initial position
		#set_position(chunk_position)
		self.tile_dictionary = {}  # Initialize the dictionary
		# Connect to the player_coord_changed signal from Helper.overmap_manager
		Helper.overmap_manager.player_coord_changed.connect(_on_player_coord_changed)
		update_absolute_position()
		self.create_tiles()  # Create tiles when the chunk is initialized
		self.redraw_tiles()

	# Function to create tiles for the chunk
	func create_tiles():
		for y in range(chunk_size):
			for x in range(chunk_size):
				var tile = overmapTile.instantiate()  # Create a new tile instance

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

				# Use the same function to update tile based on its position and player location
				update_tile_texture_and_reveal(tile, global_pos, Helper.overmap_manager.player_last_cell)

	# Function inside GridChunk to calculate and set its absolute position in pixels based on the player's position
	func update_absolute_position():
		# Calculate the chunk's absolute position in pixels
		var chunk_pixel_position: Vector2 = (grid_position - Helper.position_coord) * tile_size

		# Update the chunk's position based on the player's position and offset
		set_position(chunk_pixel_position)

		# Debug: Print the updated absolute position
		if grid_position == Vector2.ZERO:
			print("GridChunk -> update_absolute_position: Chunk at (0,0) absolute position:", chunk_pixel_position)

	# This method sets the position of the grid container and applies the offset
	func set_position(new_position: Vector2):
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the incoming new position and the current offset
			print("GridChunk -> set_position (0,0): New position:", new_position, "Offset:", offset)
		
		# Apply the offset when setting the position
		self.grid_container.position = new_position + offset
		
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the final resulting position of the grid container
			print("GridChunk -> set_position (0,0): Resulting position:", self.grid_container.position)

	# Function to update the chunk's offset
	func update_offset(new_offset: Vector2):
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the current offset and the new offset being applied
			print("GridChunk -> update_offset (0,0): Current offset:", offset, "New offset:", new_offset)
		
		# Update the offset
		offset = new_offset
		update_absolute_position()
		# Recalculate the chunk position based on the new offset
		#set_position(chunk_position)
		
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the final position after the offset update
			print("GridChunk -> update_offset (0,0): Final grid container position after applying offset:", self.grid_container.position)

	# Function inside GridChunk to update its grid_container position by a delta
	func update_grid_position(delta: Vector2):
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the current position and the delta being applied
			print("GridChunk -> update_grid_position (0,0): Current position:", grid_container.position, "Delta:", delta)
		
		# Update the grid container position by subtracting the delta scaled by tile_size
		grid_container.position -= delta * tile_size
		
		# Update the chunk position based on the new grid container position
		chunk_position = grid_container.position
		
		# Only print debug if grid_position is (0,0)
		if grid_position == Vector2.ZERO:
			# Debug: Print the updated position and chunk position after applying the delta
			print("GridChunk -> update_grid_position (0,0): Updated grid container position:", grid_container.position, "Updated chunk position:", chunk_position)



	# Function to find a tile within this chunk based on a global position
	func get_tile_at_position(global_pos: Vector2) -> Control:
		var local_pos = calculate_local_pos(global_pos)  # Use the new function
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

	# Function to update the tile's text visibility based on player's position
	func update_tile_text_visibility(player_position: Vector2):
		# Hide the text on the previously visible tile, if any
		if visible_tile:
			visible_tile.set_text_visible(false)
			visible_tile = null

		# Check if the player position is within this chunk's bounds
		if is_position_in_chunk(player_position):
			# Directly calculate the local position within the chunk by subtracting the chunk's grid position
			var local_pos = player_position - grid_position  # No division by tile_size
			if tile_dictionary.has(local_pos):
				var tile = tile_dictionary[local_pos]
				tile.set_text_visible(true)
				visible_tile = tile  # Store the reference to the new visible tile


	func _on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
		# Update tile text visibility based on the player's new position
		update_tile_text_visibility(new_pos)
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
	func update_tile_texture_and_reveal(tile: Control, global_pos: Vector2, player_position: Vector2):
		# Get the map cell from overmap_manager
		var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(global_pos)
		
		if not map_cell:
			# If no map cell found, reset the texture
			tile.set_texture(null)
			return

		# Calculate distance to player
		var distance_to_player = global_pos.distance_to(player_position)
		
		if distance_to_player <= 8:
			# Reveal the map cell if within the player's range
			map_cell.reveal()

		# Set texture based on whether the map cell is revealed
		if map_cell.revealed:
			var texture: Texture = map_cell.get_sprite()
			tile.set_texture(texture)
			# Set the tile's rotation based on the map cell's rotation property
			tile.set_texture_rotation(map_cell.rotation)
		else:
			# If outside the range and not revealed, reset the texture
			tile.set_texture(null)


	# Function to check if the player's last position falls within the range of this chunk's grid area
	func is_within_player_range() -> bool:
		# Get the player's last known position from the overmap manager
		var player_last_cell = Helper.overmap_manager.player_last_cell

		# Define the chunk bounds: from grid_position to grid_position + chunk_size
		var chunk_start = grid_position
		var chunk_end = grid_position + Vector2(chunk_size, chunk_size)

		# Check if the player's position falls within the chunk's bounds with a radius of 8
		if player_last_cell.x >= chunk_start.x - 8 and player_last_cell.x <= chunk_end.x + 8 and \
		   player_last_cell.y >= chunk_start.y - 8 and player_last_cell.y <= chunk_end.y + 8:
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
	#center_map_on_player() # Center the map


# Connect necessary signals
func connect_signals():
	position_coord_changed.connect(on_position_coord_changed)
	Helper.overmap_manager.player_coord_changed.connect(on_player_coord_changed)
	# Connect the visibility toggling signal
	visibility_changed.connect(on_overmap_visibility_toggled)
	# Connect to the target_map_changed signal from the quest helper
	Helper.quest_helper.target_map_changed.connect(on_target_map_changed)

# Center the map on the player's last known position visually, but keep the logical position at (0,0)
func center_map_on_player():
	# Position the arrow at the center of tilesContainer
	var center_of_container = tilesContainer.size / 2

	# Instead of changing Helper.position_coord, we adjust the visual position
	move_overmap_visual(Helper.overmap_manager.player_last_cell, center_of_container)

# This moves the overmap visually without affecting the logical position_coord
func move_overmap_visual(target_position: Vector2, visual_offset: Vector2):
	var delta = target_position - visual_offset
	update_tiles_position(delta)


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
		for y in range(-3, 2):
			var chunk_grid_position: Vector2 = grid_position + Vector2(x, y) * chunk_size

			# If the chunk doesn't exist, reuse from pool or create a new one
			if not grid_chunks.has(chunk_grid_position):
				var new_chunk: GridChunk
				if chunk_pool.size() > 0:
					# Reuse a chunk from the pool
					new_chunk = chunk_pool.pop_back()
					new_chunk.reset_chunk(chunk_grid_position, get_localized_position(chunk_grid_position))
				else:
					# Create a new chunk if the pool is empty
					new_chunk = GridChunk.new(chunk_grid_position, get_localized_position(chunk_grid_position), tile_size, overmapTile)

				# Check if the grid_container is already a child before adding it
				if new_chunk.grid_container.get_parent() == null:
					tilesContainer.add_child(new_chunk.grid_container)
				# Set the chunk's offset to the current global offset
				new_chunk.update_offset(current_offset)
				grid_chunks[chunk_grid_position] = new_chunk

	# Unload chunks that are out of view
	unload_chunks()


func unload_chunks():
	var range_limit = 9 * chunk_size
	var chunks_to_remove: Array = []

	# Find chunks that are too far away
	for chunk_position in grid_chunks.keys():
		if chunk_position.distance_to(Helper.position_coord + Vector2(24, 24)) > range_limit:
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
		position_coord_changed.emit(delta)


# Update tiles position by calling the GridChunk's method
func update_tiles_position(delta: Vector2):
	for chunk in grid_chunks.values():
		chunk.update_grid_position(delta)  # Call the new method in each GridChunk


# We will call this function when the position_coords change
func on_position_coord_changed(delta: Vector2):
	update_tiles_position(delta)
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
	if clicked_tile.has_meta("map_file"):
		selected_overmap_tile = clicked_tile
		var mapFile = clicked_tile.get_meta("map_file")
		var tilePos = clicked_tile.get_meta("global_pos")
		var posString: String = "Pos: (" + str(tilePos.x)+","+str(tilePos.y)+")"
		var nameString: String = "\nName: " + mapFile
		var envString: String = clicked_tile.tileData.texture
		envString = envString.replace("res://Mods/Core/OvermapTiles/","")
		envString = "\nEnvironment: " + envString
		var challengeString: String = "\nChallenge: Easy"
		overmapTileLabel.text = posString + nameString + envString + challengeString
	else: 
		selected_overmap_tile = null
		overmapTileLabel.text = "Select a valid target"


func _on_home_button_button_up():
	# Calculate the screen center offset
	var screen_center_offset = get_viewport_rect().size * 0.5

	# Convert screen center offset to world coordinates based on the tile size
	var halfTileSize = tile_size/12.0
	var world_center_offset = screen_center_offset / halfTileSize

	# Calculate the new position as the negative of the world center offset
	var new_position_coord = -world_center_offset / tile_size

	# Calculate the delta for moving the tiles
	var delta = Vector2(0,0) - Helper.position_coord

	# Update position_coord to the new position
	Helper.position_coord = Vector2(0,0)#new_position_coord

	# Emit the signal to update the overmap's position and tiles
	position_coord_changed.emit(delta)
	
	# Optionally, update the position label if it exists
	if positionLabel:
		positionLabel.text = "Position: " + str(Helper.position_coord)


# Function to find the overmap tile at the given position
func get_overmap_tile_at_position(myposition: Vector2) -> Control:
	# Calculate the chunk position based on tile size and chunk size
	var chunk_pos = (myposition / chunk_size).floor() * chunk_size
	
	# Check if the chunk exists in grid_chunks
	if grid_chunks.has(chunk_pos):
		var chunk: GridChunk = grid_chunks[chunk_pos]
		# Delegate the tile lookup to the GridChunk's dictionary lookup
		return chunk.get_tile_at_position(myposition)
	
	# Return null if the tile is not found in the corresponding chunk
	return null


# When the player moves a coordinate on the map, i.e. when crossing the chunk border.
# Movement could be between (0,0) and (0,1) for example
func on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
	if not visible:
		return

	var delta = new_pos - Helper.position_coord# - calculate_screen_center_offset()
	move_overmap(delta)


# Set the target
func set_target(map_id: String, coordinate: Vector2):
	if target == null:
		target = Target.new(map_id, coordinate)  # Create a new target



# Function to handle overmap visibility toggling
func on_overmap_visibility_toggled():
	if visible:
		# Hide the previous tile marker when the overmap is opened
		if previous_visible_tile:
			previous_visible_tile.set_text_visible(false)
			previous_visible_tile = null

		# Force update of the player position and chunks
		# This will cause the player_coord_changed signal to be emitted,
		# triggering on_position_coord_changed and centering the map on the player's position
		Helper.overmap_manager.update_player_position_and_manage_segments(true)


# Function to assist the player in finding a location based on the map_id
func find_location_on_overmap(mytarget: Target):
	# Check if mytarget's coordinate is set
	if mytarget.coordinate == Vector2():
		# If not set, find the closest map cell and set the coordinates
		var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_id(mytarget.map_id)
		if closest_cell:
			mytarget.set_coordinate(Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y))
			print_debug("Target coordinates set to closest cell: ", mytarget.coordinate)
		else:
			$ArrowLabel.visible = false  # Hide arrow if no target is found
			return
	else:
		print_debug("Using existing target coordinates: ", mytarget.coordinate)

	# Calculate the pixel position of the target's coordinate relative to the overmap center in pixel coordinates
	var target_position = (mytarget.coordinate * tile_size) - (Helper.position_coord * tile_size)

	# Get the current visible area of the overmap (position and size of the TilesContainer)
	var visible_rect = Rect2(tilesContainer.position, tilesContainer.size)
	var is_cell_visible = visible_rect.has_point(target_position + tilesContainer.position)

	if is_cell_visible:
		# Case 1: The target is visible, mark the tile and hide the arrow
		mark_overmap_tile(mytarget.coordinate)
		$ArrowLabel.visible = false  # Hide arrow
	else:
		# Case 2: The target is not visible, show an arrow pointing to its direction
		show_directional_arrow_to_cell(mytarget.coordinate)



# Marks the overmap tile with a symbol at the given position
func mark_overmap_tile(cell_position: Vector2):
	# Find the tile at the given position
	var tile = get_overmap_tile_at_position(cell_position)
	if tile:
		# You can set a symbol or change the color/text of the tile to mark it
		tile.set_text_visible(true)
		tile.set_text("X")  # Mark with an "X" for example


# Displays an arrow at the edge of the overmap window pointing towards the direction of the cell
func show_directional_arrow_to_cell(cell_position: Vector2):
	# Calculate overmap center in pixels using Helper.position_coord, which now refers to the center tile
	var overmap_center_in_pixels = (Helper.position_coord * tile_size)

	# Calculate the target position in pixels
	var target_position_in_pixels = cell_position * tile_size

	# Calculate the direction from the center of the overmap to the target
	var direction_to_cell = (target_position_in_pixels - overmap_center_in_pixels).normalized()

	print_debug("Cell Position (pixels): ", target_position_in_pixels, ", Overmap Center (pixels): ", overmap_center_in_pixels, ", Direction to Cell: ", direction_to_cell)

	# Get the arrow Control
	var arrow = $ArrowLabel
	arrow.rotation = direction_to_cell.angle()

	print_debug("Arrow Rotation (radians): ", arrow.rotation)

	# Position the arrow at the center of tilesContainer
	var center_of_container = tilesContainer.size / 2

	# Apply directional offset to position the arrow based on the direction and container size
	var arrow_position = center_of_container + direction_to_cell * (tilesContainer.size / 2)

	# Clamp the position to the container's bounds
	arrow_position = clamp_arrow_to_container_bounds(arrow_position)

	# Set arrow position and make it visible
	arrow.position = arrow_position
	arrow.visible = true

	print_debug("Arrow Position: ", arrow.position)


# Helper function to clamp the arrow to the edges of the TilesContainer
func clamp_arrow_to_container_bounds(arrow_position: Vector2) -> Vector2:
	var container_size = tilesContainer.size

	# Clamp the arrow position within the bounds of the tilesContainer
	arrow_position.x = clamp(arrow_position.x, 0, container_size.x)
	arrow_position.y = clamp(arrow_position.y, 0, container_size.y)

	print_debug("Clamped Arrow Position: ", arrow_position)
	return arrow_position



# Respond to the target_map_changed signal
func on_target_map_changed(map_id: String):
	print_debug("target map changed to " + map_id)
	if map_id == null or map_id == "":
		target = null  # Clear the target if no valid map_id is provided
		$ArrowLabel.visible = false  # Hide arrow when no target
	else:
		# Find the closest cell for the provided map_id
		var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_id(map_id)
		if closest_cell and target == null:
			# Set the new target if it hasn't been set
			target = Target.new(map_id, Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y))
			# Ensure that the coordinates do not change once set
			find_location_on_overmap(target)


func _on_tiles_container_resized() -> void:
	# Position the arrow at the center of tilesContainer
	var center_of_container = tilesContainer.size / 2
	# Update the offset for all chunks
	update_offset_for_all_chunks(center_of_container)


# Updates the current offset globally, called when the window is resized
func update_offset_for_all_chunks(new_offset: Vector2):
	current_offset = new_offset
	for chunk in grid_chunks.values():
		chunk.update_offset(current_offset)
