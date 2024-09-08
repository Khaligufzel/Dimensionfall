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
var tile_pool: Array = []  # Object pool for reusing tiles
var text_visible_by_coord: Dictionary = {}  # Tracks text visibility

# We will emit this signal when the position_coords change
# Which happens when the user has panned the overmap
signal position_coord_changed(delta: Vector2)


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

# Center the map on the player's last known position
func center_map_on_player():
	var center_offset = calculate_screen_center_offset()
	move_overmap(Helper.overmap_manager.player_last_cell - center_offset)
	update_overmap_tile_visibility(Helper.overmap_manager.player_last_cell)

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


# Helper function to add a new chunk to the grid
func add_chunk_to_grid(chunk_grid_position: Vector2):
	var localized_position = get_localized_position(chunk_grid_position)
	var new_grid_container = create_and_fill_grid_container(chunk_grid_position, localized_position)
	tilesContainer.add_child(new_grid_container)
	grid_chunks[chunk_grid_position] = new_grid_container


# Calculate the localized position of the chunk
func get_localized_position(chunk_grid_position: Vector2) -> Vector2:
	return chunk_grid_position * tile_size - Helper.position_coord * tile_size


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
			var grid_container = grid_chunks[chunk_position]
			for tile in grid_container.get_children():
				return_pooled_tile(tile)
			grid_container.queue_free()
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
	
	# Check if the chunk exists
	if grid_chunks.has(chunk_pos):
		var chunk = grid_chunks[chunk_pos]
		
		# Loop through the tiles in the specific chunk
		for tile in chunk.get_children():
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


# Calculates the center of the window. We subtract 50% because the
# overmap doesn't cover the whole screen, only about 50%
func calculate_screen_center_offset() -> Vector2:
	var screen_center_offset = get_viewport_rect().size * 0.5 / tile_size
	return screen_center_offset * 0.5  # Reduce by 50%


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
func find_location_on_overmap(map_id: String):
	# Find the closest map cell with the given map_id
	var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_id(map_id)

	if not closest_cell:
		return

	# Get the current visible area of the overmap (position and size of the TilesContainer)
	var visible_rect = Rect2(tilesContainer.position, tilesContainer.rect_size)

	# Calculate the pixel position of the closest cell by multiplying its coordinates by tile_size
	var cell_position = Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y) * tile_size
	var is_cell_visible = visible_rect.has_point(cell_position)

	if is_cell_visible:
		# Case 1: The cell is visible, mark the tile
		mark_overmap_tile(cell_position)
	else:
		# Case 2: The cell is not visible, show an arrow pointing to its direction
		show_directional_arrow_to_cell(cell_position)


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
	# Calculate the direction from the center of the visible area to the cell
	var overmap_center = tilesContainer.rect_size * 0.5
	var direction_to_cell = (cell_position - overmap_center).normalized()

	# Create or update the arrow Control (arrow must already be part of your scene)
	var arrow = $ArrowLabel  # Node named ArrowLabel for showing direction
	arrow.rotation = direction_to_cell.angle()

	# Position the arrow on the edge of the TilesContainer, clamped within its dimensions
	var arrow_position = clamp_arrow_to_container_bounds(arrow, direction_to_cell)
	arrow.position = arrow_position
	arrow.visible = true


# Helper function to clamp the arrow to the edge of the TilesContainer
func clamp_arrow_to_container_bounds(arrow: Control, direction: Vector2) -> Vector2:
	# Calculate the edge position based on the direction and container size
	var container_size = tilesContainer.rect_size
	var arrow_position = direction * (container_size / 2)

	# Clamp the position to the edges of the container
	arrow_position.x = clamp(arrow_position.x, 0, container_size.x - arrow.rect_size.x)
	arrow_position.y = clamp(arrow_position.y, 0, container_size.y - arrow.rect_size.y)

	return arrow_position
