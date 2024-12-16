extends VBoxContainer

# This script belongs to the EntitiesContainer in the mapeditor.tscn

@export var selectmods: OptionButton
var selectedmod: String = "Core"
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
	# Load the saved selected mod or default to "Core"
	selectedmod = load_selected_mod()

	# Populate the selectmods OptionButton
	populate_select_mods()

	# Select the saved mod or default to the first option
	select_mod_from_saved_or_default()

	# Load relevant data for the selected mod
	loadMobs()
	loadTiles()
	loadFurniture()


# Adds available mods to the OptionButton
func populate_select_mods() -> void:
	selectmods.clear()  # Remove all existing options from the OptionButton
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()
	
	# Iterate through Gamedata.mods and add each mod ID as an option
	for mod_id in mod_ids:
		selectmods.add_item(mod_id)


# This function selects a mod id for loadTiles() and other functions to reload.
func _on_select_mods_item_selected(index):
	selectedmod = selectmods.get_item_text(index)
	save_selected_mod()  # Save the newly selected mod

	# Refresh the UI with the new selection
	Helper.free_all_children(self)
	instanced_brushes.clear()
	loadMobs()
	loadTiles()
	loadFurniture()


# this function will read all files in Gamedata.mods.by_id(selectedmod).mobs and creates tilebrushes for each tile in the list. It will make separate lists for each category that the mobs belong to.
func loadMobs():
	# Combine mobs and mobgroups into a single list
	var mobList: Dictionary = Gamedata.mods.by_id(selectedmod).mobs.get_all()
	var mobgroupList: Dictionary = Gamedata.mods.by_id(selectedmod).mobgroups.get_all()
	var newMobsList: Control = scrolling_Flow_Container.instantiate()
	newMobsList.header = "Mobs"
	newMobsList.collapse_button_pressed.connect(_on_collapse_button_pressed)
	add_child(newMobsList)
	newMobsList.is_collapsed = load_collapse_state("Mobs")

	# Add all mobs
	for dmob: RefCounted in mobList.values():
		create_brush_instance(dmob, "mob", newMobsList)

	# Add all mobgroups
	for dmobgroup: RefCounted in mobgroupList.values():
		create_brush_instance(dmobgroup, "mobgroup", newMobsList)


# Function to create a brush instance and configure it
func create_brush_instance(entity: RefCounted, entity_type: String, newMobsList: Control):
	var texture: Resource = entity.sprite
	var brushInstance = tileBrush.instantiate()
	brushInstance.set_tile_texture(texture)
	brushInstance.entityID = entity.id
	brushInstance.entityType = entity_type
	brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
	if entity_type == "mobgroup":
		brushInstance.show_label()  # Specific behavior for mobgroups
	newMobsList.add_content_item(brushInstance)
	instanced_brushes.append(brushInstance)


func loadFurniture():
	var furnitureList: Dictionary = Gamedata.mods.by_id(selectedmod).furnitures.get_all()
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


# this function will read all files in Gamedata.mods.by_id("Core").tiles and creates tilebrushes for each tile in the list. It will make separate lists for each category that the tiles belong to.
func loadTiles():
	var tileList: Dictionary = Gamedata.mods.by_id(selectedmod).tiles.get_all()
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
				var texture: Resource = Gamedata.mods.by_id(str(selectedmod)).tiles.sprite_by_file(imagefileName)
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


# Save the selected mod into the settings.cfg
func save_selected_mod():
	var config = ConfigFile.new()
	var path = "user://settings.cfg"

	# Load existing settings
	var err = config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Failed to load settings for saving:", err)
		return

	# Save the selected mod
	config.set_value("mapeditor", "selected_mod", selectedmod)
	if config.save(path) != OK:
		print("Failed to save selected mod.")

# Load the selected mod from settings.cfg or default to "Core"
func load_selected_mod() -> String:
	var config = ConfigFile.new()
	var path = "user://settings.cfg"

	# Load the config file
	var err = config.load(path)
	if err == OK:
		# Return the saved mod or default to "Core"
		return config.get_value("mapeditor", "selected_mod", "Core")
	else:
		print("Failed to load selected mod. Defaulting to 'Core':", err)
		return "Core"

func select_mod_from_saved_or_default():
	var mod_index = -1
	for i in range(selectmods.get_item_count()):
		if selectmods.get_item_text(i) == selectedmod:
			mod_index = i
			break

	# If the mod is found, select it; otherwise, default to the first mod
	if mod_index >= 0:
		selectmods.select(mod_index)
	else:
		selectedmod = "Core"  # Fallback to "Core"
		selectmods.select(0)
