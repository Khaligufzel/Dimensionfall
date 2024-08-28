extends VBoxContainer

# This script belongs to the EntitiesContainer in the mapeditor.tscn
# It provides a list of brushes to paint with

@export var scrolling_Flow_Container: PackedScene = null
@export var tileBrush: PackedScene = null

var instanced_brushes: Array[Node] = []

signal tile_brush_selection_change(tilebrush: Control)
var selected_brush: Control:
	set(newBrush):
		selected_brush = newBrush
		tile_brush_selection_change.emit(selected_brush)

func _ready():
	loadMobs()
	loadTiles()
	loadFurniture()
	
# this function will read all files in Gamedata.data.mobs.data and creates tilebrushes for each tile in the list. It will make separate lists for each category that the mobs belong to.
func loadMobs():
	var mobList: Dictionary = Gamedata.mobs.get_all()
	var newMobsList: Control = scrolling_Flow_Container.instantiate()
	newMobsList.header = "Mobs"
	newMobsList.collapse_button_pressed.connect(_on_collapse_button_pressed)
	add_child(newMobsList)
	newMobsList.is_collapsed = load_collapse_state("Mobs")
	for dmob: DMob in mobList.values():
		# Get the texture from dmob
		var texture: Resource = dmob.sprite
		# Create a TextureRect node
		var brushInstance = tileBrush.instantiate()
		# Assign the texture to the TextureRect
		brushInstance.set_tile_texture(texture)
		# Since the map editor needs to knw what tile ID is used,
		# We store the tile id in a variable in the brush
		brushInstance.entityID = dmob.id
		brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
		brushInstance.entityType = "mob"
		# Add the TextureRect as a child to the TilesList
		newMobsList.add_content_item(brushInstance)
		instanced_brushes.append(brushInstance)


func loadFurniture():
	var furnitureList: Dictionary = Gamedata.furnitures.get_all()
	var newFurnitureList: Control = scrolling_Flow_Container.instantiate()
	newFurnitureList.header = "Furniture"
	newFurnitureList.collapse_button_pressed.connect(_on_collapse_button_pressed)
	add_child(newFurnitureList)
	newFurnitureList.is_collapsed = load_collapse_state("Furniture")

	for furniture in furnitureList.values():
		var texture: Texture = furniture.sprite
		var brushInstance = tileBrush.instantiate()
		brushInstance.set_tile_texture(texture)
		brushInstance.entityID = furniture.id
		brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
		brushInstance.entityType = "furniture"
		newFurnitureList.add_content_item(brushInstance)
		instanced_brushes.append(brushInstance)


# this function will read all files in Gamedata.tiles and creates tilebrushes for each tile in the list. It will make separate lists for each category that the tiles belong to.
func loadTiles():
	var tileList: Dictionary = Gamedata.tiles.get_all()

	for tile: DTile in tileList.values():
		if tile.spriteid:
			# We need to put the tiles in the right category
			# Each tile can have 0 or more categories
			for category in tile.categories:
				# Check if the category was already added
				var newTilesList: Control = find_list_by_category(category)
				if !newTilesList:
					newTilesList = scrolling_Flow_Container.instantiate()
					newTilesList.header = category
					newTilesList.collapse_button_pressed.connect(_on_collapse_button_pressed)
					add_child(newTilesList)
					newTilesList.is_collapsed = load_collapse_state(category)
				
				var imagefileName: String = tile.spriteid
				imagefileName = imagefileName.get_file()
				# Get the texture from gamedata
				var texture: Resource = Gamedata.tiles.sprite_by_file(imagefileName)
				# Create a TileBrush node
				var brushInstance = tileBrush.instantiate()
				# Assign the texture to the TileBrush
				brushInstance.set_tile_texture(texture)
				# Since the map editor needs to know what tile ID is used,
				# we store the tile id in a variable in the brush
				brushInstance.entityID = tile.id
				brushInstance.tilebrush_clicked.connect(tilebrush_clicked)

				# Add the TileBrush as a child to the newTilesList
				newTilesList.add_content_item(brushInstance)
				instanced_brushes.append(brushInstance)



#Find the list associated with the category
func find_list_by_category(category: String) -> Control:
	var currentCategories: Array[Node] = get_children()
	var categoryFound: Control = null
	#Check if the category was already added
	for categoryList in currentCategories:
		if categoryList.header == category:
			categoryFound = categoryList
			break
	return categoryFound


#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	deselect_all_brushes()
	# Update the selected brush to the one that was clicked, 
	# even if it was already selected
	selected_brush = tilebrush
	selected_brush.set_selected(true)


# Deselects all brushes by setting their selected state to false
func deselect_all_brushes():
	for child in instanced_brushes:
		child.set_selected(false)


# Called when the collapse button is pressed, saves the collapse state for the given header
func _on_collapse_button_pressed(header: String):
	save_collapse_state(header)


# Saves the collapsed state of the list associated with the given header to the configuration file
func save_collapse_state(header: String):
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Ensure to load existing settings to not overwrite them
	var err = config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Failed to load settings:", err)
		return

	var list_node = find_list_by_category(header)
	if list_node:
		# Save the collapsed state to the configuration file
		config.set_value("mapeditor:brushlist:" + header, "is_collapsed", list_node.is_collapsed)
		config.save(path)


# Loads the collapsed state for the given header from the configuration file and returns it
func load_collapse_state(header: String) -> bool:
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Load the config file
	var err = config.load(path)
	if err == OK:
		if config.has_section_key("mapeditor:brushlist:" + header, "is_collapsed"):
			# Return the stored collapsed state
			return config.get_value("mapeditor:brushlist:" + header, "is_collapsed")
		else:
			print("No saved state for:", header)
			return false
	else:
		print("Failed to load settings for:", header, "with error:", err)
		return false
