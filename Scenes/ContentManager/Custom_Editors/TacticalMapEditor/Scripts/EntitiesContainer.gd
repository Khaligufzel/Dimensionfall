extends VBoxContainer

@export var scrolling_Flow_Container: PackedScene = null
@export var tileBrush: PackedScene = null
@export var select_mod_option_button: OptionButton = null


var instanced_brushes: Array[Node] = []
var selected_mod: String = "Core"

signal tile_brush_selection_change(tilebrush: Control)
var selected_brush: Control:
	set(newBrush):
		selected_brush = newBrush
		tile_brush_selection_change.emit(selected_brush)

func _ready():
	# Load the saved selected mod or default to "Core"
	selected_mod = load_selected_mod()

	# Populate the selectmods OptionButton
	populate_select_mods()

	# Select the saved mod or default to the first option
	select_mod_from_saved_or_default()
	loadMaps()


# loop over Gamedata.mods.by_id("Core").maps and creates tilebrushes for each map sprite in the list. 
func loadMaps():
	var mapsList: Dictionary = Gamedata.mods.by_id(selected_mod).maps.get_all()
	var newTilesList: Control = scrolling_Flow_Container.instantiate()
	newTilesList.header = "maps"
	add_child(newTilesList)

	for mapkey in mapsList.keys():
		var map: DMap = mapsList[mapkey]
		var mySprite: Resource = map.sprite
		if mySprite:
			# Create a TextureRect node
			var brushInstance = tileBrush.instantiate()
			brushInstance.set_label(map.id)
			# Assign the texture to the TextureRect
			brushInstance.set_tile_texture(mySprite)
			# Since the map editor needs to knw what tile ID is used,
			# We store the tile id in a variable in the brush
			brushInstance.mapID = map.id
			brushInstance.tilebrush_clicked.connect(tilebrush_clicked)
			# Add the TextureRect as a child to the TilesList
			newTilesList.add_content_item(brushInstance)
			instanced_brushes.append(brushInstance)

#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	deselect_all_brushes()
	# If the clicked brush was not select it, we select it. Otherwise we deselect it
	if selected_brush != tilebrush:
		selected_brush = tilebrush
		selected_brush.set_selected(true)
	else:
		selected_brush = null
	
func deselect_all_brushes():
	for child in instanced_brushes:
		child.set_selected(false)


func _on_select_mod_option_button_item_selected(index: int) -> void:
	selected_mod = select_mod_option_button.get_item_text(index)
	save_selected_mod()  # Save the newly selected mod

	# Refresh the UI with the new selection
	Helper.free_all_children(self)
	instanced_brushes.clear()
	loadMaps()

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
	config.set_value("mapeditor", "selected_mod", selected_mod)
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
	for i in range(select_mod_option_button.get_item_count()):
		if select_mod_option_button.get_item_text(i) == selected_mod:
			mod_index = i
			break

	# If the mod is found, select it; otherwise, default to the first mod
	if mod_index >= 0:
		select_mod_option_button.select(mod_index)
	else:
		selected_mod = "Core"  # Fallback to "Core"
		select_mod_option_button.select(0)


# Populate available mods in the OptionButton
func populate_select_mods() -> void:
	select_mod_option_button.clear()
	for mod_id in Gamedata.mods.get_all_mod_ids():
		select_mod_option_button.add_item(mod_id)
