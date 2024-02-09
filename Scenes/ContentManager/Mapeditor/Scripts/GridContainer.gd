extends GridContainer
@export var tileScene: PackedScene
#This is the index of the level we are on. 0 is ground level. can be -10 to +10
var currentLevel: int = 10
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array = []
@export var mapEditor: Control
@export var LevelScrollBar: VScrollBar
@export var levelgrid_below: GridContainer
@export var levelgrid_above: GridContainer
@export var mapScrollWindow: ScrollContainer
@export var brushPreviewTexture: TextureRect
@export var buttonRotateRight: Button
var selected_brush: Control

enum EditorMode {
	NONE,
	DRAW_RECTANGLE, # When the user has clicked the DrawRectangle checkbox
	COPY_RECTANGLE, # When the user has clicked the CopyRectangle checkbox
	COPY_ALL_LEVELS # When the user has clicked the CopyAllLevels checkbox
}
# Replace your booleans with a single variable to track the current editor mode
var currentMode: EditorMode = EditorMode.NONE
var erase: bool = false
var showBelow: bool = false
var showAbove: bool = false
var snapAmount: float
var defaultMapData: Dictionary = {"mapwidth": 32, "mapheight": 32, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}
var rotationAmount: int = 0

var start_point = Vector2()
var end_point = Vector2()
var is_drawing = false
var snapLevel: Vector2 = Vector2(snapAmount, snapAmount).round()
# Variable to hold copied tile data along with dimensions
var copied_tiles_info: Dictionary = {"tiles_data": [], "width": 0, "height": 0}


#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		if data.is_empty():
			mapData = defaultMapData.duplicate()
		else:
			mapData = data.duplicate()
		loadLevelData(currentLevel)
signal zoom_level_changed(zoom_level: int)


func _on_mapeditor_ready() -> void:
	columns = mapEditor.mapWidth
	levelgrid_below.columns = mapEditor.mapWidth
	levelgrid_above.columns = mapEditor.mapWidth
	create_tiles()
	snapAmount = 1.28*mapEditor.zoom_level
	levelgrid_below.hide()
	levelgrid_above.hide()
	_on_zoom_level_changed(mapEditor.zoom_level)


# This function will fill fill this GridContainer with a grid of 32x32 instances of "res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn"
func create_tiles():
	create_level_tiles(self, mapEditor.mapWidth, mapEditor.mapHeight, true)
	create_level_tiles(levelgrid_below, mapEditor.mapWidth, mapEditor.mapHeight, false)
	create_level_tiles(levelgrid_above, mapEditor.mapWidth, mapEditor.mapHeight, false)


# Helper function to create tiles for a specific level grid
func create_level_tiles(grid: GridContainer, width: int, height: int, connect_signals: bool):
	for x in range(width):
		for y in range(height):
			var tile_instance = tileScene.instantiate()
			grid.add_child(tile_instance)
			if connect_signals:
				tile_instance.tile_clicked.connect(grid_tile_clicked)
			tile_instance.set_clickable(connect_signals)



#When the user presses and holds the middle mousebutton and moves the mouse, change the parent's scroll_horizontal and scroll_vertical properties appropriately
func _input(event) -> void:
	#The mapeditor may be invisible if the user selects another tab in the content editor
	if !mapEditor.visible:
		return
	
	# Convert the mouse position to MapScrollWindow's local coordinate system
	var local_mouse_pos = mapScrollWindow.get_local_mouse_position()
	var mapScrollWindowRect = mapScrollWindow.get_rect()
	# Check if the mouse is within the MapScrollWindow's rect
	if !mapScrollWindowRect.has_point(local_mouse_pos):
		return
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit(mapEditor.zoom_level+2)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					LevelScrollBar.value += 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN: 
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit(mapEditor.zoom_level-2)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					LevelScrollBar.value -= 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					is_drawing = true
					start_point = event.global_position.snapped(snapLevel)
				else:
					# Finalize drawing/copying operation
					end_point = event.global_position.snapped(snapLevel)
					if is_drawing:
						var drag_threshold: int = 5 # Pixels
						var distance_dragged = start_point.distance_to(end_point)
						
						if distance_dragged <= drag_threshold:
							print_debug("Released the mouse button, but clicked instead of dragged")
						else:
							match currentMode:
								EditorMode.DRAW_RECTANGLE:
									# Paint in the rectangle if drawRectangle is enabled
									paint_in_rectangle()
								EditorMode.COPY_RECTANGLE:
									# Copy selected tiles to memory if copyRectangle is 
									# enabled and not in drawRectangle mode
									copy_selected_tiles_to_memory()
								EditorMode.COPY_ALL_LEVELS:
									# Handle new feature for copying all levels
									pass
					unhighlight_tiles()
					is_drawing = false


	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		end_point = event.global_position
		if is_drawing:
			if not currentMode == EditorMode.NONE:
				update_rectangle()

		# Calculate new position for the brush preview
		var new_position = event.position + brushPreviewTexture.get_rect().size / 2
		# Get the boundaries of the mapScrollWindow
		var scroll_global_pos = mapScrollWindow.get_global_position()
		# Clamp the new position to the mapScrollWindow's boundaries
		new_position.x = clamp(new_position.x, scroll_global_pos.x, scroll_global_pos.x + mapScrollWindowRect.size.x - brushPreviewTexture.get_rect().size.x)
		new_position.y = clamp(new_position.y, scroll_global_pos.y, scroll_global_pos.y + mapScrollWindowRect.size.y - brushPreviewTexture.get_rect().size.y)
		# Update the position of the brush preview
		brushPreviewTexture.global_position = new_position


# Highlight tiles that are in the rectangle that the user has drawn with the mouse
func update_rectangle() -> void:
	if is_drawing and not currentMode == EditorMode.NONE:
		highlight_tiles_in_rect()


#When one of the grid tiles is clicked, we paint the tile accordingly
func grid_tile_clicked(clicked_tile) -> void:
	if is_drawing:
		paint_single_tile(clicked_tile)


# We paint a single tile if draw rectangle is not selected
# Either erase the tile or paint it if a brush is selected.
func paint_single_tile(clicked_tile) -> void:
	if currentMode == EditorMode.DRAW_RECTANGLE or !clicked_tile:
		return
		
	# New condition to check if copyRectangle is true and copied_tiles_info has data
	if currentMode == EditorMode.DRAW_RECTANGLE:
		if copied_tiles_info["tiles_data"].size() > 0:
			paste_copied_tile_data(clicked_tile)
			return  # Return after pasting to avoid executing further code
		else:
			return

	if erase:
		if selected_brush:
			if selected_brush.entityType == "mob":
				clicked_tile.set_mob_id("")
			elif selected_brush.entityType == "furniture":
				clicked_tile.set_furniture_id("")
			else:
				clicked_tile.set_tile_id("")
				clicked_tile.set_rotation_amount(0)
		else:
			clicked_tile.set_default()
	elif selected_brush:
		if selected_brush.entityType == "mob":
			clicked_tile.set_mob_id(selected_brush.tileID)
			clicked_tile.set_mob_rotation(rotationAmount)
		elif selected_brush.entityType == "furniture":
			clicked_tile.set_furniture_id(selected_brush.tileID)
			clicked_tile.set_furniture_rotation(rotationAmount)
		else:
			clicked_tile.set_tile_id(selected_brush.tileID)
			clicked_tile.set_rotation_amount(rotationAmount)


func storeLevelData() -> void:
	currentLevelData.clear()
	var has_significant_data = false

	# First pass: Check if any tile has significant data
	for child in get_children():
		if child.tileData and (child.tileData.has("id") or \
		child.tileData.has("mob") or child.tileData.has("furniture")):
			has_significant_data = true
			break

	# Second pass: Add all tiles to currentLevelData if any significant data is found
	if has_significant_data:
		for child in get_children():
			currentLevelData.append(child.tileData)
	else:
		# If no tile has significant data, consider adding a special marker or log
		print_debug("No significant tile data found for the current level")

	mapData.levels[currentLevel] = currentLevelData.duplicate()


# Loads the leveldata from the mapdata
# If no data exists, use the default to create a new map
func loadLevelData(newLevel: int) -> void:
	if newLevel > 0 and showBelow:
		levelgrid_below.show()
		loadLevel(newLevel-1, levelgrid_below)
	else:
		levelgrid_below.hide()
	if newLevel < 21 and showAbove:
		levelgrid_above.show()
		loadLevel(newLevel+1, levelgrid_above)
		for tile in levelgrid_above.get_children():
			tile.set_above()
	else:
		levelgrid_above.hide()
	loadLevel(newLevel, self)


func loadLevel(level: int, grid: GridContainer) -> void:
	if mapData.is_empty():
		print_debug("Tried to load data from an empty mapData dictionary")
		return;
	var newLevelData: Array = mapData.levels[level]
	var i: int = 0
	# If any data exists on this level, we load it
	if newLevelData != []:
		for tile in grid.get_children():
			tile.tileData = newLevelData[i]
			i += 1
	else:
		#No data is present on this level. apply the default value for each tile
		for tile in grid.get_children():
			tile.set_default()


# We change from one level to another. For exmple from ground level (0) to 1
# Save the data we currently have in the mapData
# Then load the data from mapData if it exists for that level
# If no data exists for that level, create new level data
func change_level(newlevel: int) -> void:
	storeLevelData()
	loadLevelData(newlevel)
	currentLevel = newlevel
	storeLevelData()


# We need to add 10 since the scrollbar starts at -10
func _on_level_scrollbar_value_changed(value) -> void:
	change_level(10+0-value)


# Function to check if any corner of a tile or its edges are within or on the boundary of the normalized rectangle
func is_tile_in_rect(tile: Control, normalized_start: Vector2, normalized_end: Vector2, zoom_level: float) -> bool:
	var tile_size = tile.get_size() / zoom_level
	var tile_global_pos = tile.global_position / zoom_level
	var tile_bottom_right = tile_global_pos + tile_size

	# Adjusting checks to be inclusive of the boundary conditions
	var overlaps_top_left = tile_global_pos.x <= normalized_end.x and tile_global_pos.y <= normalized_end.y
	var overlaps_bottom_right = tile_bottom_right.x >= normalized_start.x and tile_bottom_right.y >= normalized_start.y

	return overlaps_top_left and overlaps_bottom_right


# This function takes two coordinates representing a rectangle and the current zoom level.
# It will check which of the TileGrid's children's positions fall inside this rectangle.
# It returns all the child tiles that fall inside this rectangle.
func get_tiles_in_rectangle(rect_start: Vector2, rect_end: Vector2) -> Array:
	var tiles_in_rectangle: Array = []

	# Normalize the rectangle coordinates
	var normalized_start = Vector2(min(rect_start.x, rect_end.x), min(rect_start.y, rect_end.y))
	var normalized_end = Vector2(max(rect_start.x, rect_end.x), max(rect_start.y, rect_end.y))

	# Adjust the rectangle coordinates based on the zoom level
	normalized_start /= mapEditor.zoom_level
	normalized_end /= mapEditor.zoom_level

	for tile in get_children():
		if is_tile_in_rect(tile, normalized_start, normalized_end, mapEditor.zoom_level):
			tiles_in_rectangle.append(tile)

	return tiles_in_rectangle



# This function calculates the dimensions of the selected tiles in terms of how many tiles were selected horizontally (width) and vertically (height).
func get_selection_dimensions(rect_start: Vector2, rect_end: Vector2) -> Dictionary:
	var selected_tiles = get_tiles_in_rectangle(rect_start, rect_end)
	var x_positions = []
	var y_positions = []

	# Normalize the rectangle coordinates based on the zoom level
	rect_start /= mapEditor.zoom_level
	rect_end /= mapEditor.zoom_level

	for tile in selected_tiles:
		# Assuming the position is based on the tile's position in the grid container
		var tile_pos = tile.get_position() / (snapAmount * mapEditor.zoom_level)
		var x_position = tile_pos.x
		var y_position = tile_pos.y
		
		# Add the positions to the lists if they're not already there
		if not x_positions.has(x_position):
			x_positions.append(x_position)
		if not y_positions.has(y_position):
			y_positions.append(y_position)

	# Sort the positions in ascending order for consistency
	x_positions.sort()
	y_positions.sort()

	# Calculate the selection width and height based on the unique positions
	var selection_width = x_positions.size()
	var selection_height = y_positions.size()

	# Return the dimensions as a dictionary
	return {"width": selection_width, "height": selection_height}


func unhighlight_tiles() -> void:
	for tile in get_children():
		tile.unhighlight()


func highlight_tiles_in_rect() -> void:
	unhighlight_tiles()
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	for tile in tiles:
		tile.highlight()


#Paint every tile in the selected rectangle
#We always erase if erase is selected, even if no brush is selected
#Only paint if a brush is selected and erase is false
func paint_in_rectangle():
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	if erase:
		for tile in tiles:
			if selected_brush:
				if selected_brush.entityType == "mob":
					tile.set_mob_id("")
				elif selected_brush.entityType == "furniture":
					tile.set_furniture_id("")
				else:
					tile.set_tile_id("")
					tile.set_rotation_amount(0)
			else:
				tile.set_default()
	elif selected_brush:
		for tile in tiles:
			if selected_brush.entityType == "mob":
				tile.set_mob_id(selected_brush.tileID)
			elif selected_brush.entityType == "furniture":
				tile.set_furniture_id(selected_brush.tileID)
			else:
				tile.set_tile_id(selected_brush.tileID)
				tile.set_rotation_amount(rotationAmount)
	update_rectangle()

#The user has pressed the erase toggle button in the editor
func _on_erase_toggled(button_pressed):
	erase = button_pressed


func _on_draw_rectangle_toggled(button_pressed):
	if button_pressed:
		currentMode = EditorMode.DRAW_RECTANGLE
	else:
		currentMode = EditorMode.NONE


func _on_tilebrush_list_tile_brush_selection_change(tilebrush):
	selected_brush = tilebrush
	update_preview_texture()


func update_preview_texture():
	if selected_brush:
		brushPreviewTexture.texture = selected_brush.get_texture()
		brushPreviewTexture.visible = true
	else:
		brushPreviewTexture.visible = false


func _on_show_below_toggled(button_pressed):
	showBelow = button_pressed
	if showBelow:
		levelgrid_below.show()
	else:
		levelgrid_below.hide()


func _on_show_above_toggled(button_pressed):
	showAbove = button_pressed
	if showAbove:
		levelgrid_above.show()
	else:
		levelgrid_above.hide()


#This function takes the mapData property and saves all of it as a json file.
func save_map_json_file():
	# Convert the TileGrid.mapData to a JSON string
	storeLevelData()
	var map_data_json = JSON.stringify(mapData.duplicate(), "\t")
	Helper.json_helper.write_json_file(mapEditor.contentSource, map_data_json)


func load_map_json_file():
	var fileToLoad: String = mapEditor.contentSource
	mapData = Helper.json_helper.load_json_dictionary_file(fileToLoad)


func _on_zoom_level_changed(zoom_level: int):
	# Calculate the new scale based on zoom level
	var scale_factor = zoom_level * 0.01 
	brushPreviewTexture.scale = Vector2(scale_factor, scale_factor)
	brushPreviewTexture.pivot_offset = brushPreviewTexture.size / 2
	for tile in get_children():
		tile.set_scale_amount(1.28*zoom_level)
	for tile in levelgrid_below.get_children():
		tile.set_scale_amount(1.28*zoom_level)
	for tile in levelgrid_above.get_children():
		tile.set_scale_amount(1.28*zoom_level)
	

# When the user releases the mouse button on the rotate right button
func _on_rotate_right_pressed():
	rotationAmount += 90
	rotationAmount = rotationAmount % 360 # Keep rotation within 0-359 degrees
	buttonRotateRight.text = str(rotationAmount)
	brushPreviewTexture.rotation_degrees = rotationAmount
	brushPreviewTexture.pivot_offset = brushPreviewTexture.size / 2
	if copied_tiles_info["tiles_data"].size() > 0:
		rotate_selection_clockwise()


# Function to create a 128x128 miniature map of the current level
func create_miniature_map_image() -> Image:
	var map_width = mapEditor.mapWidth
	var map_height = mapEditor.mapHeight
	var tile_width = int(128 / map_width)  # Calculate tile width for the miniature map
	var tile_height = int(128 / map_height)  # Calculate tile height for the miniature map

	# Create a new Image with a size of 128x128 pixels
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)

	# Iterate through each tile in the current level and draw it into the image
	for x in range(map_width):
		for y in range(map_height):
			var tile = get_child(y * map_width + x)
			var tile_texture = tile.get_tile_texture()
			var tile_image = tile_texture.get_image()
			# Resize the tile image to fit the miniature map
			tile_image.resize(tile_width, tile_height)
			# Convert the tile image to the same format as the main image
			tile_image.convert(Image.FORMAT_RGBA8)
			# Draw the resized tile image onto the main image
			image.blit_rect(tile_image, Rect2(Vector2(), \
			tile_image.get_size()), Vector2(x * tile_width, y * tile_height))
	return image


# Function to create and save a 128x128 miniature map of the current level
func save_miniature_map_image():
	# Call the function to create the image texture
	var image_texture = create_miniature_map_image()  
	var image = image_texture
	# Save the image to a file
	var file_name = mapEditor.contentSource.get_file().replace("json", "png")
	var file_path = Gamedata.data.maps.spritePath + file_name
	image.save_png(file_path)


func _on_create_preview_image_button_button_up():
	save_miniature_map_image()
	

# This function will loop over all levels and rotate them if they contain tile data.
func rotate_map() -> void:
	# Store the data of the current level before rotating the map
	storeLevelData()
	
	for i in range(mapData.levels.size()):
		# Load each level's data into currentLevelData
		currentLevelData = mapData.levels[i]
		# Rotate the current level data
		rotate_level_clockwise()
		# Update the rotated data back into the mapData
		mapData.levels[i] = currentLevelData.duplicate()

	# After rotation, reload the current level's data
	loadLevelData(currentLevel)


# Rotates the current level 90 degrees clockwise.
func rotate_level_clockwise() -> void:
	# Check if currentLevelData has at least one item
	if !currentLevelData.size() > 0:
		return
	var width = mapEditor.mapWidth
	var height = mapEditor.mapHeight
	var new_level_data: Array[Dictionary] = []

	# Initialize new_level_data with empty dictionaries
	for i in range(width * height):
		new_level_data.append({})

	# Rotate the tile data
	for x in range(width):
		for y in range(height):
			var old_index = y * width + x
			var new_x = width - y - 1
			var new_y = x
			var new_index = new_y * width + new_x
			new_level_data[new_index] = currentLevelData[old_index].duplicate()

			# Add rotation to the tile's data if it has an id
			if new_level_data[new_index].has("id"):
				var tile_rotation = int(new_level_data[new_index].get("rotation", 0))
				new_level_data[new_index]["rotation"] = (tile_rotation + 90) % 360
			
			# Rotate furniture if present, initializing rotation to 0 if not set
			if new_level_data[new_index].has("furniture"):
				var furniture_rotation = int(new_level_data[new_index].get("furniture").get("rotation", 0))
				new_level_data[new_index]["furniture"]["rotation"] = (furniture_rotation + 90) % 360

	# Update the current level data
	currentLevelData = new_level_data



# Called when the Copy Rectangle ToggleButton's state changes.
func _on_copy_rectangle_toggled(toggled_on: bool) -> void:
	# If it was toggled off, clear the data from copied_tiles_info, clear rotation, and hide the brush preview
	if not toggled_on:
		currentMode = EditorMode.NONE
		copied_tiles_info = {"tiles_data": [], "width": 0, "height": 0}
		reset_rotation()
		brushPreviewTexture.visible = false
	# If it was toggled on, show the brush preview (if there's something to preview)
	else:
		currentMode = EditorMode.COPY_RECTANGLE
		if copied_tiles_info["tiles_data"].size() > 0:
			# You might want to update the brush preview to reflect the copied tiles
			update_preview_texture_with_copied_data()
		# If there's nothing to copy, perhaps alert the user
		else:
			print("No tiles copied to preview.")


func copy_selected_tiles_to_memory():
	# We want to start with 0 rotation, the user can rotate it later
	reset_rotation()
	# Get selection dimensions from the new function
	var selection_dimensions = get_selection_dimensions(start_point, end_point)
	
	# Clear previous copied tiles info
	copied_tiles_info["tiles_data"].clear()
	
	# Get all tiles within the selected rectangle
	var selected_tiles = get_tiles_in_rectangle(start_point, end_point)
	
	# Update copied_tiles_info with the new dimensions
	copied_tiles_info["width"] = selection_dimensions["width"]
	copied_tiles_info["height"] = selection_dimensions["height"]
	
	# Copy each tile's data to the copied_tiles_info dictionary
	for tile in selected_tiles:
		# Assuming each tile has a script with a property 'tileData' that contains its data
		var tile_data = tile.tileData.duplicate()  # Duplicate the dictionary to ensure a deep copy
		copied_tiles_info["tiles_data"].append(tile_data)
	
	# Optionally, update a preview texture or other UI element to visualize the copied data
	update_preview_texture_with_copied_data()


func update_preview_texture_with_copied_data():
	var preview_size = Vector2(512, 512)  # Size of the preview texture
	var tiles_width = copied_tiles_info["width"]
	var tiles_height = copied_tiles_info["height"]
	print_debug("tiles_width = " + str(tiles_width) + ", tiles_height = " + str(tiles_height))
	
	# Calculate size for each tile in the preview to fit all copied tiles
	var tile_size_x = preview_size.x / tiles_width
	var tile_size_y = preview_size.y / tiles_height
	var tile_size = Vector2(tile_size_x, tile_size_y)
	
	# Create a new Image with a size of 128x128 pixels
	var image = Image.create(preview_size.x, preview_size.y, false, Image.FORMAT_RGBA8)
	#image.fill(Color(0, 0, 0, 0))  # Fill with transparent color

	var idx = 0  # Tile index
	for tile_data in copied_tiles_info["tiles_data"]:
		# Assuming tile_data contains a key for 'texture_id' or similar
		var tile_texture: Texture
		if tile_data.has("id"):
			var texture_id = tile_data["id"]
			# You need a way to map 'texture_id' to an actual texture; this is just a conceptual placeholder
			tile_texture = Gamedata.get_sprite_by_id(Gamedata.data.tiles, texture_id).albedo_texture
		else:
			tile_texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
		
		if tile_texture:
			var tile_image = tile_texture.get_image()
			tile_image.resize(tile_size.x, tile_size.y)  # Resize image to fit the preview
			
			# Calculate position in the preview based on the tile index and copied area dimensions
			var pos_x = (idx % tiles_width) * tile_size.x
			var pos_y = (idx / tiles_width) * tile_size.y
			var pos_in_preview = Vector2(pos_x, pos_y)
			
			# Convert the tile image to the same format as the main image
			tile_image.convert(Image.FORMAT_RGBA8)
			# Draw the resized tile image onto the main image
			image.blit_rect(tile_image, Rect2(Vector2(), tile_image.get_size()), pos_in_preview)
		
		idx += 1  # Move to the next tile

	# Convert the Image to a Texture and assign it to brushPreviewTexture
	var texture = ImageTexture.create_from_image(image)
	brushPreviewTexture.texture = texture
	brushPreviewTexture.visible = true


func get_index_of_child(clicked_tile: Node) -> int:
	var children = get_children()  # Get all children of this GridContainer
	for i in range(len(children)):
		if children[i] == clicked_tile:
			return i  # Return the index if the child matches the clicked_tile
	return -1  # Return -1 if the clicked_tile is not found among the children


# Function to paste copied tile data starting from the clicked tile
func paste_copied_tile_data(clicked_tile):
	# Check if we have copied tile data
	if copied_tiles_info.is_empty():
		print("No tile data to paste.")
		return

	# Assuming `clicked_tile` is a direct child of this GridContainer
	var tile_index = get_index_of_child(clicked_tile)
	var num_columns = columns  # Assuming `columns` is defined as the number of columns in the grid

	# Calculate the grid position from the tile index
	var start_x = tile_index % num_columns
	var start_y = float(tile_index) / num_columns
	
	
	# Calculate the ending points based on the width and height from copied_tiles_info
	var end_x = min(start_x + copied_tiles_info["width"], 32)
	var end_y = min(start_y + copied_tiles_info["height"], 32)

	# Tile data index
	var tile_data_index = 0

	# Loop through the grid starting from the clicked tile position
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			# Calculate the index for the current tile in the grid
			var current_tile_index = y * 32 + x
			# Get the current tile
			var current_tile: Control = get_child(current_tile_index)
			# Check if the current tile and tile data index are valid
			if current_tile and tile_data_index < copied_tiles_info["tiles_data"].size():
				# Update the current tile with the copied data
				current_tile.tileData = copied_tiles_info["tiles_data"][tile_data_index]
				tile_data_index += 1

	# Clear copied_tiles_info after pasting
	copied_tiles_info = {"tiles_data": [], "width": 0, "height": 0}
	print("Pasted tile data and cleared copied_tiles_info.")


func _on_copy_all_levels_toggled(toggled_on):
	if toggled_on:
		currentMode = EditorMode.COPY_ALL_LEVELS
	else:
		currentMode = EditorMode.NONE


# Function to rotate the selected tiles in copied_tiles_info 90 degrees clockwise
func rotate_selection_clockwise():
	var new_copied_tiles_info: Dictionary = {"tiles_data": [], "width": copied_tiles_info["height"], "height": copied_tiles_info["width"]}

	# We'll be rotating the tiles, so we need to change width and height
	var new_width = copied_tiles_info["height"]
	var new_height = copied_tiles_info["width"]

	for y in range(new_height):
		for x in range(new_width):
			var old_x = new_height - y - 1
			var old_y = x
			var old_index = old_y * copied_tiles_info["width"] + old_x
			var tile_data = copied_tiles_info["tiles_data"][old_index].duplicate()
			
			# Add rotation to the tile's data if it has an id
			if tile_data.has("id"):
				var tile_rotation = int(tile_data.get("rotation", 0))
				tile_data["rotation"] = (tile_rotation + 90) % 360
			
			# Rotate furniture if present, initializing rotation to 0 if not set
			if tile_data.has("furniture"):
				var furniture_rotation = int(tile_data.get("furniture").get("rotation", 0))
				tile_data["furniture"]["rotation"] = (furniture_rotation + 90) % 360
			
			# Add rotated tile data to new_copied_tiles_info
			new_copied_tiles_info["tiles_data"].append(tile_data)
	
	# Assign the newly rotated tiles to copied_tiles_info
	copied_tiles_info = new_copied_tiles_info


# Resets the rotation amount to 0 and updates relevant nodes
func reset_rotation() -> void:
	rotationAmount = 0
	brushPreviewTexture.rotation_degrees = rotationAmount
	buttonRotateRight.text = str(rotationAmount)


# Function to get the tile data from mapData for a given index and level
func get_tile_data_from_mapData(index: int, level: int) -> Dictionary:
	var level_data = mapData.levels[level]
	if index >= 0 and index < level_data.size():
		return level_data[index]
	else:
		return {} # Return an empty dictionary if the index is out of range


func get_tile_indexes_in_rectangle(rect_start, rect_end) -> Array[int]:
	var tile_indexes: Array[int] = []
	for tile in get_tiles_in_rectangle(rect_start, rect_end):
		var index = get_index_of_child(tile)
		if index != -1:
			tile_indexes.append(index)
	return tile_indexes


# Copies a column of tiles from all levels
# This column is represented by an array
func copy_tiles_from_all_levels(rect_start: Vector2, rect_end: Vector2) -> Array:
	var all_levels_copied_data: Array = []
	var tile_indexes = get_tile_indexes_in_rectangle(rect_start, rect_end)
	
	for level in range(mapData.levels.size()):
		var level_data = mapData.levels[level]
		if level_data.size() > 0:
			var level_copied_tiles: Array = []
			for tile_index in tile_indexes:
				var tile_data = get_tile_data_from_mapData(tile_index, level)
				if tile_data.size() > 0: # Make sure the tile has data before adding it
					level_copied_tiles.append(tile_data)
			all_levels_copied_data.append(level_copied_tiles)
		else:
			all_levels_copied_data.append([])

	return all_levels_copied_data


# Function to get tiles in range based on the provided start tile index, width, and height
func get_tiles_in_range(start_tile_index: int, width: int, height: int, level_index: int) -> Array:
	var tiles_in_range: Array = []
	
	# Calculate the start row and column based on the tile index and map width
	var start_row: int = start_tile_index / mapData["mapwidth"]
	var start_col: int = start_tile_index % mapData["mapwidth"]
	
	# Calculate the end row and column based on the width and height
	var end_row: int = start_row + height
	var end_col: int = start_col + width
	
	# Ensure the range does not exceed the map boundaries
	end_row = min(end_row, mapData["mapheight"])
	end_col = min(end_col, mapData["mapwidth"])
	
	# Loop through the specified range and collect tile data
	for row in range(start_row, end_row):
		for col in range(start_col, end_col):
			var tile_index: int = row * mapData["mapwidth"] + col
			# Ensure the tile index is within the level's data range
			if tile_index >= 0 and tile_index < mapData["levels"][level_index].size():
				tiles_in_range.append(mapData["levels"][level_index][tile_index])
	
	return tiles_in_range


# Function to get tile indexes in range based on the provided start tile index, width, and height
func get_tile_indexes_in_range(start_tile_index: int, width: int, height: int, level_index: int) -> Array:
	var tile_indexes: Array = []
	
	# Calculate the start row and column based on the tile index and map width
	var start_row: int = start_tile_index / mapData["mapwidth"]
	var start_col: int = start_tile_index % mapData["mapwidth"]
	
	# Calculate the end row and column based on the width and height
	var end_row: int = start_row + height
	var end_col: int = start_col + width
	
	# Ensure the range does not exceed the map boundaries
	end_row = min(end_row, mapData["mapheight"])
	end_col = min(end_col, mapData["mapwidth"])
	
	# Loop through the specified range and collect tile indexes
	for row in range(start_row, end_row):
		for col in range(start_col, end_col):
			var tile_index: int = row * mapData["mapwidth"] + col
			# Ensure the tile index is within the map's total number of tiles
			if tile_index < mapData["levels"][level_index].size():
				tile_indexes.append(tile_index)
	
	return tile_indexes


func apply_column_tiles_to_all_levels(clicked_tile: Control) -> void:
	# Get the index of the clicked tile
	var clicked_tile_index = get_index_of_child(clicked_tile)
	
	# Get selection dimensions from the new function
	var selection_dimensions = get_selection_dimensions(start_point, end_point)
	
	# Update copied_tiles_info with the new dimensions
	var width = selection_dimensions["width"]
	var height = selection_dimensions["height"]
	
	# Copy tiles from all levels based on the clicked column
	var copied_column_data = copy_tiles_from_all_levels(start_point, end_point)
	
	# Get the required tile indexes in range for the target location
	# Assuming we use the same clicked_tile_index for simplicity; adjust as needed for the target location
	var target_tile_indexes = get_tile_indexes_in_range(clicked_tile_index, width, height, currentLevel)
	
	# Loop over all levels in mapData
	for level_index in range(mapData["levels"].size()):
		var level_data = mapData["levels"][level_index]
		# Ensure there's corresponding copied data for this level
		if level_index < copied_column_data.size():
			var column_data_for_level = copied_column_data[level_index]
			for i in range(min(target_tile_indexes.size(), column_data_for_level.size())):
				var target_index = target_tile_indexes[i]
				# Check if target index is within the current level data range
				if target_index >= 0 and target_index < level_data.size():
					# Apply the copied tile data to the target tile index
					level_data[target_index] = column_data_for_level[i]

	# After pasting, reload the current level's data
	loadLevelData(currentLevel)
