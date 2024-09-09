extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
@export var overmapTile: PackedScene = null
@export var overmapTileLabel: Label = null
@export var controls_container: VBoxContainer = null
@export var margin_container: MarginContainer = null


var noise = FastNoiseLite.new()
var grid_chunks: Dictionary = {} # Stores references to grid containers (visual tile grids)
var chunk_width: int = 8  # Smaller chunk sizes improve performance
var chunk_size: int = 8
var tile_size: int = 32
var grid_pixel_size: int = chunk_size * tile_size
var selected_overmap_tile: Control = null
var previous_visible_tile: Control = null  # Stores the previously visible tile
var tile_pool: Array = []  # Object pool for reusing tiles
var text_visible_by_coord: Dictionary = {}  # Tracks text visibility
var target: Target = null  # Holds the target location as an instance of the Target class


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
	var get_pooled_tile_func: Callable
	var update_tile_func: Callable
	var return_pooled_tile_func: Callable
	var chunk_width: int = 8  # Smaller chunk sizes improve performance
	var chunk_size: int = 8
	
	# Constructor to initialize the chunk with its grid position, chunk position, and necessary references
	func _init(mygrid_position: Vector2, mychunk_position: Vector2, mytile_size: int, get_pooled_tile: Callable, update_tile: Callable, return_pooled_tile: Callable):
		self.grid_position = mygrid_position
		self.chunk_position = mychunk_position
		self.tile_size = mytile_size
		self.get_pooled_tile_func = get_pooled_tile
		self.update_tile_func = update_tile
		self.return_pooled_tile_func = return_pooled_tile
		self.grid_container = GridContainer.new()
		self.grid_container.columns = chunk_width
		self.grid_container.set("theme_override_constants/h_separation", 0)
		self.grid_container.set("theme_override_constants/v_separation", 0)
		self.grid_container.position = chunk_position

	# Fill the grid container with tiles
	func fill_grid():
		for y in range(chunk_size):
			for x in range(chunk_size):
				var tile = get_pooled_tile_func.call()
				var local_pos = Vector2(x * tile_size, y * tile_size)
				var global_pos = grid_position + Vector2(x, y)

				# Update tile based on map cell data
				update_tile_func.call(tile, global_pos)

				tile.set_meta("global_pos", global_pos)
				tile.set_meta("local_pos", local_pos)

				# Add the tile to the grid container
				grid_container.add_child(tile)

	# Set the position of the grid container (useful for redrawing)
	func set_position(new_position: Vector2):
		self.grid_container.position = new_position
	
	# Remove all children (tiles) and free the grid container
	func clear():
		for tile in grid_container.get_children():
			return_pooled_tile_func.call(tile)
		grid_container.queue_free()


# Modify add_chunk_to_grid to use the new GridChunk class
func add_chunk_to_grid(chunk_grid_position: Vector2):
	var localized_position = get_localized_position(chunk_grid_position)
	var new_chunk = GridChunk.new(chunk_grid_position, localized_position, tile_size, get_pooled_tile, update_tile_with_map_cell, return_pooled_tile)
	new_chunk.fill_grid()  # Fill the grid container with tiles
	tilesContainer.add_child(new_chunk.grid_container)  # Add to tilesContainer
	grid_chunks[chunk_grid_position] = new_chunk  # Store the chunk

# Modify redraw_existing_chunks to use the new GridChunk class
func redraw_existing_chunks():
	for chunk_position in grid_chunks.keys():
		var chunk = grid_chunks[chunk_position]
		var localized_position = get_localized_position(chunk_position)
		chunk.set_position(localized_position)  # Update chunk position
		print("Updated Chunk Position: ", chunk.grid_container.position)

# Update other functions accordingly
func get_localized_position(chunk_grid_position: Vector2) -> Vector2:
	return chunk_grid_position * tile_size - Helper.position_coord * tile_size


func _ready():
	# Centers the view when opening the ovemap.
	Helper.position_coord = Vector2(0, 0)
	update_chunks()
	connect_signals()
	center_map_on_player() # Center the map

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
	var visual_offset = calculate_screen_center_offset()

	# Instead of changing Helper.position_coord, we adjust the visual position
	move_overmap_visual(Helper.overmap_manager.player_last_cell, visual_offset)
	update_overmap_tile_visibility(Helper.overmap_manager.player_last_cell)

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
	# The grid position will move 32 over when the Helper_coord passes the last tile
	# The grid_position will be 0,0 between 0,0 and 31,31 if chunk_size = 32
	# The grid_position will be 1,0 between 32,0 and 64,31 if chunk_size = 32
	var grid_position: Vector2 = (Helper.position_coord / chunk_size).floor() * chunk_size

	for x in range(0, 7):
		for y in range(0, 5):
			var chunk_grid_position: Vector2 = grid_position + Vector2(x, y) * chunk_size

			if not grid_chunks.has(chunk_grid_position):
				add_chunk_to_grid(chunk_grid_position)

	# After generating new chunks, you may want to unload any that are off-screen.
	unload_chunks()



# Get a tile from the pool or create a new one if the pool is empty
func get_pooled_tile() -> Control:
	if tile_pool.size() > 0:
		return tile_pool.pop_back()
	else:
		var tile = overmapTile.instantiate()
		tile.tile_clicked.connect(_on_tile_clicked)
		return tile


# Return a tile to the pool
func return_pooled_tile(tile: Control):
	if tile.get_parent() != null:
		tile.get_parent().remove_child(tile)
	tile_pool.append(tile)


# The user will leave chunks behind as the map is panned around
# Chunks that are too far from the current position will be destroyed
# This will only destroy the visual representation of the data.
func unload_chunks():
	# Lowering this number 5 will cause newly created chunks 
	# to be instantly deleted and recreated
	var range_limit = 6 * chunk_size
	for chunk_position in grid_chunks.keys():
		if chunk_position.distance_to(Helper.position_coord + Vector2(24,24)) > range_limit:
			var gridchunk: GridChunk = grid_chunks[chunk_position]
			for tile in gridchunk.grid_container.get_children():
				return_pooled_tile(tile)
			gridchunk.grid_container.queue_free()
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


# This function will move all the tile grids on screen when the position_coords change
# This will make it look like the user pans across the map
func update_tiles_position(delta: Vector2):
	for grid_container in tilesContainer.get_children():
		# Update the grid container's position by subtracting the delta
		grid_container.position -= delta * tile_size


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


# This function creates and populates a GridContainer with tiles based on chunk size and position.
# The function generates a new GridContainer, sets its columns to chunk_width, and ensures no space between tiles.
# It then generates terrain for each tile based on a noise algorithm and assigns metadata to each tile.
# Tiles are added as children to the GridContainer, which is positioned based on chunk_position.
# The function returns the populated GridContainer.
func create_and_fill_grid_container(grid_position: Vector2, chunk_position: Vector2) -> GridContainer:
	var grid_container = GridContainer.new()
	grid_container.columns = chunk_width  # Set the number of columns to chunk_width.
	# Make sure there is no space between the tiles
	grid_container.set("theme_override_constants/h_separation", 0)
	grid_container.set("theme_override_constants/v_separation", 0)

	# Iterate over the chunk size to create and add TextureRects for each tile.
	for y in range(chunk_size):
		for x in range(chunk_size):
			var tile = get_pooled_tile()
			var local_pos = Vector2(x * tile_size, y * tile_size)
			var global_pos = grid_position + Vector2(x, y)

			# Use the new function to update the tile based on map cell data
			update_tile_with_map_cell(tile, global_pos)

			tile.set_meta("global_pos", global_pos)
			tile.set_meta("local_pos", local_pos)
			
			# Handle visibility of text if needed
			if text_visible_by_coord.has(global_pos) and text_visible_by_coord[global_pos]:
				tile.set_text_visible(true)
			else:
				tile.set_text_visible(false)

			if global_pos == Vector2.ZERO:
				tile.set_color(Color(0.3, 0.3, 1))  # blue color
			else:
				tile.set_color(Color(1,1,1))

			grid_container.add_child(tile)

	grid_container.position = chunk_position
	return grid_container


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
	var delta = new_position_coord - Helper.position_coord

	# Update position_coord to the new position
	Helper.position_coord = new_position_coord

	# Emit the signal to update the overmap's position and tiles
	position_coord_changed.emit(delta)
	
	# Optionally, update the position label if it exists
	if positionLabel:
		positionLabel.text = "Position: (0, 0)"


# Function to update the visibility of overmap tile text
func update_overmap_tile_visibility(new_pos: Vector2):
	# Hide the previous visible tile's marker, if any
	if previous_visible_tile:
		previous_visible_tile.set_text_visible(false)
		previous_visible_tile = null  # Reset previous tile to avoid conflicts

	# Clear the dictionary that tracks visible text
	text_visible_by_coord.clear()
	text_visible_by_coord[new_pos] = true

	# Find the current tile at the new position
	var current_tile = get_overmap_tile_at_position(new_pos)
	if current_tile:
		current_tile.set_text_visible(true)
		previous_visible_tile = current_tile  # Store the new visible tile

	# Define the radius around the player
	var radius = 8
	var cell_pos: Vector2 = new_pos

	# Iterate over the fixed range around the player position
	for x in range(int(cell_pos.x - radius), int(cell_pos.x + radius) + 1):
		for y in range(int(cell_pos.y - radius), int(cell_pos.y + radius) + 1):
			var distance_to_cell = Vector2(x - cell_pos.x, y - cell_pos.y).length()
			
			if distance_to_cell <= radius:
				var cell_key = Vector2(x, y)

				# Use get_overmap_tile_at_position to get the tile at this cell position
				var tile = get_overmap_tile_at_position(cell_key)
				
				if tile:
					# Update the tile with its map cell information
					update_tile_with_map_cell(tile, cell_key)
					# Handle visibility of text based on the player's new position
					if cell_key == new_pos:
						tile.set_text_visible(true)
						previous_visible_tile = tile  # Store the new visible tile
					else:
						tile.set_text_visible(false)



func update_tile_with_map_cell(tile: Control, global_pos: Vector2):
	# Get map_cell from overmap_manager
	var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(global_pos)
	
	if map_cell:
		# If the map cell is within a radius of 8 around the player's position
		if global_pos.distance_to(Helper.overmap_manager.player_last_cell) <= 8:
			map_cell.reveal()
		
		# Set texture based on the revealed status
		if map_cell.revealed:
			var texture: Texture = map_cell.get_sprite()
			tile.set_texture(texture)
		else:
			tile.set_texture(null)  # Reset texture to null if not revealed
		
		# Set the tile's rotation based on the map_cell's rotation property
		tile.set_texture_rotation(map_cell.rotation)
	else:
		# No map cell found, reset texture
		tile.set_texture(null)


# Function to find the overmap tile at the given position
func get_overmap_tile_at_position(myposition: Vector2) -> Control:
	# Calculate the chunk position based on tile size and chunk size
	var chunk_pos = (myposition / chunk_size).floor() * chunk_size
	
	# Check if the chunk exists in grid_chunks
	if grid_chunks.has(chunk_pos):
		var chunk: GridChunk = grid_chunks[chunk_pos]
		
		# Loop through the tiles in the GridContainer of the chunk
		for tile in chunk.grid_container.get_children():
			if tile.get_meta("global_pos") == myposition:
				return tile
	
	# Return null if the tile is not found in the corresponding chunk
	return null



# When the player moves a coordinate on the map, i.e. when crossing the chunk border.
# Movement could be between (0,0) and (0,1) for example
func on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
	if not visible:
		return

	update_overmap_tile_visibility(new_pos)
	var delta = new_pos - Helper.position_coord - calculate_screen_center_offset()
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

		# Update the player marker visibility based on the current position
		update_overmap_tile_visibility(Helper.overmap_manager.player_last_cell)


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



# Calculates the screen center offset based on the margin_container and controls_container sizes
func calculate_screen_center_offset() -> Vector2:
	if margin_container and controls_container:
		# Use the height of the controls_container directly for the available height
		var available_height = margin_container.size.y

		# Subtract the width of the controls_container from the margin_container for the available width
		var available_width = margin_container.size.x - controls_container.size.x

		# Create a Vector2 for the available size
		var available_size = Vector2(available_width, available_height)

		# Calculate the center offset using the available size
		var new_offset = (available_size) * 0.5

		return new_offset
	else:
		print("Error: Either margin_container or controls_container is not set or has no size.")
		return Vector2.ZERO
