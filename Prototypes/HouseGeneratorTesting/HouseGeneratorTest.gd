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
	#
	# when we are at it, let's go ahead and get info about which room was divided. We will use that in the next step
	var wall_direction : int = split_smaller_room_horizontally(max_room_x, max_room_y, splitting_wall_x)


	# making the last room. this time it will be a little different,
	# we will not just simply split the biggest room into half with one wall.
	# I want to make it in the corner

	make_corner_room(max_room_x, max_room_y, splitting_wall_x, wall_direction)


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
	else:
		for i in range(splitting_wall_x, max_room_x):
			grid[i][random_wall_y] = 2 # wall
	
	return direction


func make_corner_room(max_room_x : int, max_room_y : int, splitting_wall_x : int, wall_direction : int):
	
	# Let's see which room is the biggest (undivided)


	# We need to decide where will be the inner corner of the main room.
	var inner_corner_x : int
	if wall_direction == -1:
		inner_corner_x = randi_range(4 + splitting_wall_x, max_room_x - 5)
	else:
		inner_corner_x = randi_range(4, splitting_wall_x - 5)

	var inner_corner_y : int = randi_range(4, max_room_y - 5)

	# test
	grid[inner_corner_x][inner_corner_y] = 2 # wall

	## left or right room?
	if wall_direction == -1:
		# we can make the smaller room in 4 different corners, so I guess to add variety let's make it random
		match randi_range(0,3):
			0: # south west
				for i in range(splitting_wall_x, inner_corner_x):
					grid[i][inner_corner_y] = 2 # wall
				for i in range(inner_corner_y, max_room_y):
					grid[inner_corner_x][i] = 2
			1: # north west
				for i in range(splitting_wall_x, inner_corner_x):
					grid[i][inner_corner_y] = 2 # wall
				for i in range(0, inner_corner_y):
					grid[inner_corner_x][i] = 2
			2: # north east
				for i in range(inner_corner_x, max_room_x):
					grid[i][inner_corner_y] = 2 # wall
				for i in range(0, inner_corner_y):
					grid[inner_corner_x][i] = 2
			3: # south east
				for i in range(splitting_wall_x, inner_corner_x):
					grid[i][inner_corner_y] = 2 # wall
				for i in range(inner_corner_y, max_room_y):
					grid[inner_corner_x][i] = 2

	if wall_direction == 1:
		# we can make the smaller room in 4 different corners, so I guess to add variety let's make it random
		match randi_range(0,0):
			0: # south west
				for i in range(0, inner_corner_x):
					grid[i][inner_corner_y] = 2
				for i in range(inner_corner_y, max_room_y):
					grid[inner_corner_x][i] = 2
			1: # north west
				for i in range(0, inner_corner_x):
					grid[i][inner_corner_y] = 2
				for i in range(0, inner_corner_y):
					grid[inner_corner_x][i] = 2
			2: # north east
				for i in range(inner_corner_x, splitting_wall_x):
					grid[i][inner_corner_y] = 2
				for i in range(0, inner_corner_y):
					grid[inner_corner_x][i] = 2
			3: # south east
				for i in range(inner_corner_x, splitting_wall_x):
					grid[i][inner_corner_y] = 2
				for i in range(inner_corner_y, max_room_y):
					grid[inner_corner_x][i] = 2
				
	


func _input(event):
	if event.is_action_pressed("reload_weapon") :
		generate_house()


