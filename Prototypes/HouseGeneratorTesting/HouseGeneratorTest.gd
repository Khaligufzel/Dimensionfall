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
@export var rooms_size_x : int = 24
@export var rooms_size_y : int = 12
@export var size_random_x : int = 6
@export var size_random_y : int = 2
@export var number_of_floors : int = 1

@export_group("Textures")
@export var floor_texture : Texture2D
@export var wall_texture : Texture2D

var grid_size : int = 32
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

	# randomly assign the x and y size of the room
	var max_room_x : int = rooms_size_x + randi_range(-size_random_x, size_random_x)
	var max_room_y : int = rooms_size_y + randi_range(-size_random_y, size_random_y)
	
	# Generate the main room in the grid
	generate_room(max_room_x, max_room_y)

	# make a vertical wall splitting the main room into two parts
	var splitting_wall_x : int = split_room_vertically(max_room_x, max_room_y)

	# splitting the smaller room created by last function with a horizontal wall
	# this will create the third room
	# also giving the location of the wall here, for start/end point of horizontal wall

	split_smaller_room_horizontally(max_room_x, max_room_y, splitting_wall_x)



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
func generate_room(size_x : int, size_y : int):
	# Ensure the room fits within the grid

	var end_x = min(size_x, grid_size)
	var end_y = min(size_y, grid_size)

	# Create walls around the room
	for i in range(0, end_x):
		for j in range(0, end_y):
			if i == 0 or i == end_x - 1 or j == 0 or j == end_y - 1:
				grid[i][j] = 2 # Wall
			else:
				grid[i][j] = 1 # Floor

func split_room_vertically(max_room_x : int, max_room_y : int):

	# first, we need to randomly pick x where we will start making the vertical wall
	# Min. should be 4, so room will be min. 3 wide (I hope that makes sense)
	# Max should be -5, for the same reason

	var random_wall_x : int = randi_range(4, max_room_x - 5)

	# next- let's actually divide the room!
	for i in range(0, max_room_y):
		grid[random_wall_x][i] = 2 # wall
	return random_wall_x

func split_smaller_room_horizontally(max_room_x : int, max_room_y : int, splitting_wall_x : int):

	# first, we need to randomly pick y where we will start making the horizontal wall
	# min and max like in func split_room_vertically

	var random_wall_y : int = randi_range(4, max_room_y - 5)

	# next step- we need to find out which room is smaller, so we can split that one
	var left_room_x_size : int = splitting_wall_x + 1
	var right_room_x_size : int = max_room_x - (splitting_wall_x + 1)

	# if the left room is smaller then direction = -1, else = 1
	var direction : int

	if left_room_x_size <= right_room_x_size:
		direction = -1
	else:
		direction = 1

	# so now when we know which room to split, let's DO IT
	
	if direction == -1:
		for i in range(0, splitting_wall_x):
			grid[i][random_wall_y] = 2 # wall
	


func _input(event):
	if event.is_action_pressed("reload_weapon") :
		generate_house()


