# extends Node2D

# @export_group("Settings")
# @export var number_of_rooms : int = 4
# @export var rooms_size_x : int = 5
# @export var rooms_size_y : int = 5
# @export var rooms_size_random : int = 1

# @export_group("Variables")
# @export var floor_texture : Texture2D
# @export var wall_texture : Texture2D

# var grid_size : int = 24
# var grid : Array = []

# # Called when the node enters the scene tree for the first time.
# func _ready():
# 	generate_house()
# 	draw_house()

# # Function to generate the house layout
# func generate_house():
# 	# Initialize the grid
# 	grid = []
# 	for i in range(grid_size):
# 		grid.append([])
# 		for j in range(grid_size):
# 			grid[i].append(0) # 0 means empty, 1 means floor, 2 means wall

# 	# Place the first room
# 	var start_x = randi() % (grid_size - rooms_size_x)
# 	var start_y = randi() % (grid_size - rooms_size_y)
# 	place_room(start_x, start_y, rooms_size_x, rooms_size_y)

# 	var previous_room = Rect2(start_x, start_y, rooms_size_x, rooms_size_y)

# 	for i in range(1, number_of_rooms):
# 		var room_width = rooms_size_x + int(randi() % rooms_size_random)
# 		var room_height = rooms_size_y + int(randi() % rooms_size_random)

# 		# Ensure room dimensions are valid
# 		room_width = max(1, room_width)
# 		room_height = max(1, room_height)

# 		var x = previous_room.position.x + previous_room.size.x + 1 # Leave a gap for the wall
# 		var max_y_shift = max(1, int(previous_room.size.y - room_height))
# 		var y = int(previous_room.position.y + randi() % max_y_shift)

# 		# Ensure the new room fits within the grid
# 		x = min(x, grid_size - room_width)
# 		y = clamp(y, 0, grid_size - room_height)

# 		place_room(x, y, room_width, room_height)

# 		# Add a door between rooms
# 		var door_y = clamp(previous_room.position.y + int(previous_room.size.y / 2), 0, grid_size - 1)
# 		grid[previous_room.position.x + int(previous_room.size.x)][door_y] = 1

# 		# Update previous room
# 		previous_room = Rect2(x, y, room_width, room_height)

# 	# Generate walls around floors
# 	for i in range(grid_size):
# 		for j in range(grid_size):
# 			if grid[i][j] == 1: # If it's a floor
# 				# Check adjacent cells
# 				for dx in range(-1, 2):
# 					for dy in range(-1, 2):
# 						if dx == 0 and dy == 0:
# 							continue
# 						var nx = i + dx
# 						var ny = j + dy
# 						if nx >= 0 and nx < grid_size and ny >= 0 and ny < grid_size:
# 							if grid[nx][ny] == 0:
# 								grid[nx][ny] = 2 # Set wall

# # Function to place a room at a given position
# func place_room(x: int, y: int, width: int, height: int):
# 	for i in range(width):
# 		for j in range(height):
# 			grid[x + i][y + j] = 1 # Set floor

# # Function to draw the house based on the grid
# func draw_house():
# 	for i in range(grid_size):
# 		for j in range(grid_size):
# 			if grid[i][j] == 1: # Floor
# 				var floor_instance = Sprite2D.new()
# 				floor_instance.texture = floor_texture
# 				floor_instance.position = Vector2(i * 32, j * 32)
# 				add_child(floor_instance)
# 			elif grid[i][j] == 2: # Wall
# 				var wall_instance = Sprite2D.new()
# 				wall_instance.texture = wall_texture
# 				wall_instance.position = Vector2(i * 32, j * 32)
# 				add_child(wall_instance)

# # Function to print the grid layout in the console for debugging
# func print_grid():
# 	for row in grid:
# 		print(row)


extends Node2D

@export_group("Settings")
@export var number_of_rooms : int = 1
@export var rooms_size_x : int = 10
@export var rooms_size_y : int = 10
@export var size_random : int = 2
@export var number_of_floors : int = 1

@export_group("Variables")
@export var floor_texture : Texture2D
@export var wall_texture : Texture2D

var grid_size : int = 14
var grid : Array = []


# Called when the node enters the scene tree for the first time.
func _ready():
	generate_house()

# Function to generate the house layout
func generate_house():

	# Remove all children first if there are any from previous generation

	if get_child_count() > 0:
		for brave_little_child in get_children():
			brave_little_child.queue_free()


	# Initialize the grid
	grid = []
	for i in range(grid_size):
		grid.append([])
		for j in range(grid_size):
			grid[i].append(0) # 0 means empty, 1 means floor, 2 means wall
	
	# Generate one room in the grid
	generate_room(Vector2(3, 3), rooms_size_x + randi_range(-size_random, size_random), rooms_size_y + randi_range(-size_random, size_random))

	# Create Sprite2D nodes for walls and floors
	for x in range(grid_size):
		for y in range(grid_size):
			if grid[x][y] == 1: # Floor
				var floor_sprite = Sprite2D.new()
				floor_sprite.texture = floor_texture
				floor_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
				add_child(floor_sprite)
			elif grid[x][y] == 2: # Wall
				var wall_sprite = Sprite2D.new()
				wall_sprite.texture = wall_texture
				wall_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
				add_child(wall_sprite)

# Function to generate a room at a given position with given size
func generate_room(room_position : Vector2, size_x : int, size_y : int):
	# Ensure the room fits within the grid
	var start_x = room_position.x
	var start_y = room_position.y
	var end_x = min(start_x + size_x, grid_size)
	var end_y = min(start_y + size_y, grid_size)

	# Create walls around the room
	for i in range(start_x, end_x):
		for j in range(start_y, end_y):
			if i == start_x or i == end_x - 1 or j == start_y or j == end_y - 1:
				grid[i][j] = 2 # Wall
			else:
				grid[i][j] = 1 # Floor


func _input(event):
	if event.is_action_pressed("reload_weapon") :
		generate_house()


# extends Node2D

# @export_group("Settings")
# @export var number_of_rooms : int = 1
# @export var rooms_size_x : int = 10
# @export var rooms_size_y : int = 10
# @export var size_random : int = 2
# @export var number_of_floors : int = 1

# @export_group("Variables")
# @export var floor_texture : Texture2D
# @export var wall_texture : Texture2D

# var grid_size : int = 16
# var grid : Array = []


# # Called when the node enters the scene tree for the first time.
# func _ready():
# 	generate_house()

# # Function to generate the house layout
# func generate_house():

# 	# Remove all children first if there are any from previous generation
# 	if get_child_count() > 0:
# 		for brave_little_child in get_children():
# 			brave_little_child.queue_free()

# 	# Initialize the grid
# 	grid = []
# 	for i in range(grid_size):
# 		grid.append([])
# 		for j in range(grid_size):
# 			grid[i].append(0) # 0 means empty, 1 means floor, 2 means wall
	
# 	# Generate rooms in the grid
# 	generate_room(Vector2(3, 3), rooms_size_x + randi_range(-size_random, size_random), rooms_size_y + randi_range(-size_random, size_random))

# 	# Generate kitchen
# 	var kitchen_size_x = randi_range(3, min(10, 32 - rooms_size_x)) # Random size constrained by available space
# 	var kitchen_size_y = randi_range(3, min(10, 16 - rooms_size_y)) # Random size constrained by available space
# 	var kitchen_position = Vector2(rooms_size_x + randi_range(1, 32 - rooms_size_x - kitchen_size_x), randi_range(1, 16 - kitchen_size_y))
# 	generate_room(kitchen_position, kitchen_size_x, kitchen_size_y)

# 	# Generate bathroom
# 	var bathroom_size_x = randi_range(3, min(10, 32 - rooms_size_x - kitchen_size_x)) # Random size constrained by available space
# 	var bathroom_size_y = randi_range(3, min(10, 16 - rooms_size_y - kitchen_size_y)) # Random size constrained by available space
# 	var bathroom_position = Vector2(randi_range(1, 32 - bathroom_size_x), rooms_size_y + randi_range(1, 16 - rooms_size_y - bathroom_size_y))
# 	generate_room(bathroom_position, bathroom_size_x, bathroom_size_y)

# 	# Create Sprite2D nodes for walls and floors
# 	for x in range(grid_size):
# 		for y in range(grid_size):
# 			if grid[x][y] == 1: # Floor
# 				var floor_sprite = Sprite2D.new()
# 				floor_sprite.texture = floor_texture
# 				floor_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
# 				add_child(floor_sprite)
# 			elif grid[x][y] == 2: # Wall
# 				var wall_sprite = Sprite2D.new()
# 				wall_sprite.texture = wall_texture
# 				wall_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
# 				add_child(wall_sprite)

# # Function to generate a room at a given position with given size
# func generate_room(room_position : Vector2, size_x : int, size_y : int):
# 	# Ensure the room fits within the grid
# 	var start_x = max(0, min(room_position.x, grid_size - 1))
# 	var start_y = max(0, min(room_position.y, grid_size - 1))
# 	var end_x = min(start_x + size_x, grid_size)
# 	var end_y = min(start_y + size_y, grid_size)

# 	# Create walls around the room
# 	for i in range(start_x, end_x):
# 		for j in range(start_y, end_y):
# 			if i == start_x or i == end_x - 1 or j == start_y or j == end_y - 1:
# 				grid[i][j] = 2 # Wall
# 			else:
# 				grid[i][j] = 1 # Floor


# func _input(event):
# 	if event.is_action_pressed("reload_weapon") :
# 		generate_house()

# extends Node2D

# @export_group("Settings")
# @export var number_of_rooms : int = 1
# @export var rooms_size_x : int = 10
# @export var rooms_size_y : int = 10
# @export var size_random : int = 2
# @export var number_of_floors : int = 1

# @export_group("Variables")
# @export var floor_texture : Texture2D
# @export var wall_texture : Texture2D

# var grid_size : int = 16
# var grid : Array = []


# # Called when the node enters the scene tree for the first time.
# func _ready():
# 	generate_house()

# # Function to generate the house layout
# func generate_house():

# 	# Remove all children first if there are any from previous generation
# 	if get_child_count() > 0:
# 		for brave_little_child in get_children():
# 			brave_little_child.queue_free()

# 	# Initialize the grid
# 	grid = []
# 	for i in range(grid_size):
# 		grid.append([])
# 		for j in range(grid_size):
# 			grid[i].append(0) # 0 means empty, 1 means floor, 2 means wall
	
# 	# Generate rooms in the grid
# 	generate_main_room(Vector2(3, 3), rooms_size_x + randi_range(-size_random, size_random), rooms_size_y + randi_range(-size_random, size_random))

# 	# Generate kitchen
# 	var kitchen_size_x = randi_range(5, min(10, grid_size)) # Random size constrained by available space
# 	var kitchen_size_y = randi_range(1, min(10, grid_size)) # Random size constrained by available space
# 	var kitchen_position = Vector2(randi_range(0, max(0, grid_size - kitchen_size_x)), randi_range(0, max(0, grid_size - kitchen_size_y)))
# 	generate_room(kitchen_position, kitchen_size_x, kitchen_size_y)

# 	# Generate bathroom
# 	var bathroom_size_x = randi_range(2, min(10, grid_size - kitchen_size_x)) # Random size constrained by available space
# 	var bathroom_size_y = randi_range(1, min(10, grid_size - kitchen_size_y)) # Random size constrained by available space
# 	var bathroom_position = Vector2(randi_range(0, max(0, grid_size - bathroom_size_x)), randi_range(0, max(0, grid_size - bathroom_size_y)))
# 	generate_room(bathroom_position, bathroom_size_x, bathroom_size_y)

# 	# Create Sprite2D nodes for walls and floors
# 	for x in range(grid_size):
# 		for y in range(grid_size):
# 			if grid[x][y] == 1: # Floor
# 				var floor_sprite = Sprite2D.new()
# 				floor_sprite.texture = floor_texture
# 				floor_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
# 				add_child(floor_sprite)
# 			elif grid[x][y] == 2: # Wall
# 				var wall_sprite = Sprite2D.new()
# 				wall_sprite.texture = wall_texture
# 				wall_sprite.position = Vector2(x * 32, y * 32) # Adjust position based on texture size
# 				add_child(wall_sprite)

# # Function to generate the main room at a given position with given size
# func generate_main_room(room_position : Vector2, size_x : int, size_y : int):
# 	# Ensure the room fits within the grid
# 	var start_x = max(0, min(room_position.x, grid_size - 1))
# 	var start_y = max(0, min(room_position.y, grid_size - 1))
# 	var end_x = min(start_x + size_x, grid_size)
# 	var end_y = min(start_y + size_y, grid_size)

# 	# Create walls around the room
# 	for i in range(start_x, end_x):
# 		for j in range(start_y, end_y):
# 			if i == start_x or i == end_x - 1 or j == start_y or j == end_y - 1:
# 				grid[i][j] = 2 # Wall
# 			else:
# 				grid[i][j] = 1 # Floor

# # Function to generate a room at a given position with given size
# func generate_room(room_position : Vector2, size_x : int, size_y : int):
# 	# Ensure the room fits within the grid
# 	var start_x = max(0, min(room_position.x, grid_size - 1))
# 	var start_y = max(0, min(room_position.y, grid_size - 1))
# 	var end_x = min(start_x + size_x, grid_size)
# 	var end_y = min(start_y + size_y, grid_size)

# 	# Create walls around the room
# 	for i in range(start_x, end_x):
# 		for j in range(start_y, end_y):
# 			if i == start_x or i == end_x - 1 or j == start_y or j == end_y - 1:
# 				grid[i][j] = 2 # Wall
# 			else:
# 				grid[i][j] = 1 # Floor


# func _input(event):
# 	if event.is_action_pressed("reload_weapon") :
# 		generate_house()
