extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
@export var overmapTile: PackedScene = null
@export var travelButton: Button = null
@export var overmapTileLabel: Label = null
var position_coord: Vector2 = Vector2(0, 0)
var last_position_coord: Vector2 = Vector2()
var tiles: Array = ["1.png", "arcstones1.png", "forestunderbrushscale5.png", "rockyfloor4.png"]
var noise = FastNoiseLite.new()
var grid_chunks: Dictionary = {} # Stores references to grid containers (visual tilegrids)
var chunk_width: int = 32
var chunk_size = 32
var tile_size = 32
var grid_pixel_size = chunk_size*tile_size
var selected_overmap_tile: Control = null

func _ready():
	var gameFileJson: Dictionary = Helper.json_helper.load_json_dictionary_file(\
	Helper.save_helper.current_save_folder + "/game.json")
	noise.seed = gameFileJson.mapseed
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.5
	noise.frequency = 0.04
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	update_chunks()
	connect("position_coord_changed", on_position_coord_changed)

# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
func update_chunks():
	# Convert the current position to grid coordinates based on the grid's pixel size
	var grid_position = (position_coord / grid_pixel_size).floor() * grid_pixel_size
	#The position is increase arbitrarily so it is more center of screen
	grid_position.x += grid_pixel_size
	grid_position.y += grid_pixel_size

	for x in range(-1, 1):
		for y in range(-1, 1):
			var chunk_grid_position = grid_position + Vector2(x, y) * grid_pixel_size
			# Use the separate noise_chunks Dictionary for retrieving the noise data
			if not Helper.chunks.has(chunk_grid_position):
				generate_chunk(chunk_grid_position)
			# Retrieve the chunk data for the specific position.
			var chunk_data = Helper.chunks[chunk_grid_position]  
			
			if not grid_chunks.has(chunk_grid_position):
				# Use chunk data to create and fill the GridContainer.
				var localized_x: float = chunk_grid_position.x-position_coord.x
				var localized_y: float = chunk_grid_position.y-position_coord.y
				var new_grid_container = create_and_fill_grid_container(chunk_data,\
				Vector2(localized_x,localized_y))
				tilesContainer.call_deferred("add_child",new_grid_container)
	#				tilesContainer.add_child(new_grid_container)
				# Store the GridContainer using the grid position as the key.
				grid_chunks[chunk_grid_position] = new_grid_container

	# After generating new chunks, you may want to unload any that are off-screen.
	unload_chunks()


func generate_chunk(grid_position: Vector2):
	var chunk = []
	for y in range(chunk_size):  # x goes from 0 to chunk_size - 1
		for x in range(chunk_size):  # y goes from 0 to chunk_size - 1
			# We calculate global coordinates by 
			# offsetting the local coordinates by the grid_position
			var global_x = x + grid_position.x / tile_size
			var global_y = y + grid_position.y / tile_size
			var noise_value = noise.get_noise_2d(global_x, global_y)
			# Scale noise_value to a valid index in the tiles array
			# Ensure noise_value is scaled correctly based on the number of tiles.
			var tile_index = int((noise_value + 1) / 2 * tiles.size()) % tiles.size()
			chunk.append({"tile": tiles[tile_index], "tacticalmap":\
			get_random_mapname_1_in_100()})
	# Store the chunk using the grid_position as the key.
	Helper.chunks[grid_position] = chunk
	
func get_random_mapname_1_in_100() -> String:
	var random_file: String = ""
	var chance = randi_range(0, 100)
	if chance < 1:
		var random_index = randi() % Gamedata.all_map_files.size()
		random_file = Gamedata.all_map_files[random_index]
	return random_file



# The user will leave chunks behind as the map is panned around
# Chunks that are too far from the current position will be destoroyed
#This will only destroy the visual representation of the data stored in Helper.chunks
func unload_chunks():
	var dist = 0
	var rangeLimit = 0
	for chunk_position in grid_chunks.keys():
		dist = chunk_position.distance_to(position_coord)
		#Lowering this number 5 will cause newly created chunks 
		#to be instantly deleted and recreated
		rangeLimit = 3 * grid_pixel_size
		if dist > rangeLimit:
			#Distroy the grid itself
			grid_chunks[chunk_position].call_deferred("queue_free")
			#Remove the reference to the grid
			grid_chunks.erase(chunk_position)


var mouse_button_pressed: bool = false
#We will emit this signal when the position_coords change
signal position_coord_changed(delta)
func _input(event):
	if !visible:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				mouse_button_pressed = event.is_pressed()

	if event is InputEventMouseMotion and mouse_button_pressed:
		# Adjust the position based on the mouse movement, divided by 100 for sensitivity.
		var motion = event.relative / 2
		# Calculate the new position first.
		var new_position_coord = position_coord - motion
		# Round the new_position_coord to the nearest integer.
		new_position_coord = new_position_coord.round()
		# Calculate the delta based on the old and the rounded new positions.
		var delta = new_position_coord - position_coord
		if delta != Vector2.ZERO:
			# Update position_coord to the new rounded position.
			position_coord = new_position_coord
			# Emit the signal to update other parts of the game that depend on the position.
			emit_signal("position_coord_changed", delta)
			# Update last_position_coord for the next input event.
			last_position_coord = position_coord


#This function will move all the tilegrids on screen when the position_coords change
#This will make it look like the user pans across the map
func update_tiles_position(delta):
	for grid_container in tilesContainer.get_children():
		# Update the grid container's position by subtracting the delta
		grid_container.position -= delta

#We will call this function when the position_coords change
func on_position_coord_changed(delta):
	update_tiles_position(delta)
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(position_coord)
		
		
func create_and_fill_grid_container(chunk: Array, chunk_position: Vector2):
	var grid_container = GridContainer.new()
	grid_container.columns = chunk_width  # Set the number of columns to chunk_width.
	# Make sure there is no space between the tiles
	grid_container.set("theme_override_constants/h_separation", 0)
	grid_container.set("theme_override_constants/v_separation", 0)

	# Variables to keep track of the row and column position
	var row: int = 0
	var column: int = 0

	# Iterate over the chunk array to create and add TextureRects for each tile.
	for i in range(chunk.size()):
		if i > 0 and i % chunk_width == 0:
			row += 1
			column = 0  # Reset column at the start of a new row

		var tile_type = chunk[i].tile
		# Retrieve the texture based on the tile type.
		var texture = Gamedata.overmaptile_materials[tile_type]
		var tile = overmapTile.instantiate()
		var local_x = column*tile_size
		var local_y = row*tile_size
		var global_x = chunk_position.x + local_x
		var global_y = chunk_position.y + local_y
		# Assign the tile's row and column information
		tile.set_meta("global_pos", Vector2(global_x,global_y))
		tile.set_meta("local_pos", Vector2(local_x,local_y))
		if chunk[i].tacticalmap != "":
			tile.set_meta("map_file", chunk[i].tacticalmap)  # Set the metadata of the tile
			tile.set_color(Color(1, 0.8, 0.8))  # Make the tile slightly red
		tile.set_texture(texture)
		tile.connect("tile_clicked", _on_tile_clicked)
		# Add the tile as a child to the grid container
		grid_container.add_child(tile)

		# Increase column count after placing each tile
		column += 1

	# Set the position of the grid container in pixel space.
	grid_container.position = chunk_position

	# Return the filled grid container.
	return grid_container




#This function will be connected to the signal of the tiles
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
		travelButton.disabled = false
	else: 
		selected_overmap_tile = null
		travelButton.disabled = true
		overmapTileLabel.text = "Select a valid target"


func _on_travel_button_button_up():
	var mapFile = selected_overmap_tile.get_meta("map_file")
	var global_pos: Vector2 = selected_overmap_tile.get_meta("global_pos")
	Helper.switch_level(mapFile, global_pos)
