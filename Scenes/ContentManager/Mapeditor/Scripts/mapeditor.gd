extends Control

@export var panWindow: Control = null
@export var mapScrollWindow: ScrollContainer = null
@export var gridContainer: ColorRect = null
@export var tileGrid: GridContainer = null
@export var map_preview: Popup = null


# Settings controls:
@export var name_text_edit: TextEdit
@export var description_text_edit: TextEdit
@export var categories_list: Control
@export var weight_spin_box: SpinBox

# Loading mods
@export var select_mods: OptionButton
@export var type_selector_menu_button: MenuButton = null
@export var contentList: PackedScene = null
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
var selectedMod: String = "Core"

# Connection controls
@export var north_check_box: CheckBox = null # Checked if this map has a road connection north
@export var east_check_box: CheckBox = null # Checked if this map has a road connection east
@export var south_check_box: CheckBox = null # Checked if this map has a road connection south
@export var west_check_box: CheckBox = null # Checked if this map has a road connection west

signal zoom_level_changed(value: int)

# This signal should alert the content_list that a refresh is needed
@warning_ignore("unused_signal")
signal data_changed()
var tileSize: int = 128
var mapHeight: int = 32
var mapWidth: int = 32
var currentMap: DMap:
	set(newMap):
		currentMap = newMap
		set_settings_values()
		tileGrid.on_map_data_changed()


var zoom_level: int = 20:
	set(val):
		zoom_level = val
		zoom_level_changed.emit(zoom_level)


func _ready():
	setPanWindowSize()
	zoom_level = 20
	populate_select_mods()  # Populate the select_mods OptionButton
	refresh_lists()

func refresh_lists() -> void:
	# Clear existing content in the VBoxContainer
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()  # Ensure the nodes are properly removed and freed

	# Reload content lists for the currently selected mod
	load_content_list(DMod.ContentType.MAPS, "Maps")
	load_content_list(DMod.ContentType.TACTICALMAPS, "Tactical Maps")
	load_content_list(DMod.ContentType.ITEMS, "Items")
	load_content_list(DMod.ContentType.TILES, "Terrain Tiles")
	load_content_list(DMod.ContentType.MOBS, "Mobs")
	load_content_list(DMod.ContentType.FURNITURES, "Furniture")
	load_content_list(DMod.ContentType.ITEMGROUPS, "Item Groups")
	load_content_list(DMod.ContentType.PLAYERATTRIBUTES, "Player Attributes")
	load_content_list(DMod.ContentType.WEARABLESLOTS, "Wearable Slots")
	load_content_list(DMod.ContentType.STATS, "Stats")
	load_content_list(DMod.ContentType.SKILLS, "Skills")
	load_content_list(DMod.ContentType.QUESTS, "Quests")
	load_content_list(DMod.ContentType.OVERMAPAREAS, "Overmap areas")
	load_content_list(DMod.ContentType.MOBGROUPS, "Mob groups")
	load_content_list(DMod.ContentType.MOBFACTIONS, "Mob factions")
	
	# Repopulate the type selector menu
	populate_type_selector_menu_button()

# Clears the select_mods OptionButton and populates it with mod IDs from Gamedata.mods
func populate_select_mods() -> void:
	select_mods.clear()  # Remove all existing options from the OptionButton
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()
	
	# Iterate through Gamedata.mods and add each mod ID as an option
	for mod_id in mod_ids:
		select_mods.add_item(mod_id)

	# Set the first item as the default selection (if any mods exist)
	if mod_ids.size() > 0:
		selectedMod = mod_ids[0]  # Default to the first mod ID
		select_mods.select(0)
	else:
		selectedMod = ""  # No mods available, clear the selectedMod

func load_content_list(type: DMod.ContentType, strHeader: String):
	# Instantiate a content list
	var contentListInstance: Control = contentList.instantiate()

	# Set the source properties, dynamically using the selectedMod ID
	contentListInstance.header = strHeader
	contentListInstance.mod_id = selectedMod  # Use the current mod ID
	contentListInstance.contentType = type

	# Add it as a child to the content VBoxContainer
	content.add_child(contentListInstance)


func setPanWindowSize():
	var panWindowWidth: float = 0.8*tileSize*mapWidth
	var panWindowHeight: float = 0.8*tileSize*mapHeight
	panWindow.custom_minimum_size = Vector2(panWindowWidth, panWindowHeight)

# Function to populate the type_selector_menu_button with content list headers and load their state
func populate_type_selector_menu_button():
	var popup_menu = type_selector_menu_button.get_popup()
	popup_menu.clear()  # Clear any existing items
	
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	config.load(path)  # Load existing settings if available

	# Define a list of headers to add to the menu button
	var headers = [
		"Maps", "Tactical Maps", "Items", "Terrain Tiles", "Mobs", 
		"Furniture", "Item Groups", "Player Attributes", "Wearable Slots", 
		"Stats", "Skills", "Quests", "Overmap areas", "Mob groups", "Mob factions"
	]
	
	for i in headers.size():
		var item_text = headers[i]
		popup_menu.add_check_item(item_text, i)  # Add a checkable item

		# Load saved state or default to checked if not found
		var is_checked = config.get_value("type_selector", item_text, true)
		popup_menu.set_item_checked(i, is_checked)

		# Show or hide the content list based on the state
		if is_checked:
			show_content_list(item_text)
		else:
			hide_content_list(item_text)

	# Connect item selection signal to save state when changed
	if not popup_menu.id_pressed.is_connected(_on_type_selected):
		popup_menu.id_pressed.connect(_on_type_selected)


# Function to handle item selection from the popup menu and save the state
func _on_type_selected(id):
	var popup_menu = type_selector_menu_button.get_popup()
	var item_text = popup_menu.get_item_text(id)

# Function to show a content list with the given header text
func show_content_list(header_text: String):
	for child in content.get_children():
		if child is Control and child.header == header_text:
			child.visible = true
			break

# Function to hide a content list with the given header text
func hide_content_list(header_text: String):
	for child in content.get_children():
		if child is Control and child.header == header_text:
			child.visible = false
			break


var mouse_button_pressed: bool = false

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		if mouse_button_pressed:
			mapScrollWindow.scroll_horizontal = mapScrollWindow.scroll_horizontal - event.relative.x
			mapScrollWindow.scroll_vertical = mapScrollWindow.scroll_vertical - event.relative.y


#Scroll to the center when the scroll window is ready
func _on_map_scroll_window_ready():
	await get_tree().create_timer(0.5).timeout
	mapScrollWindow.scroll_horizontal = int(panWindow.custom_minimum_size.x/3.5)
	mapScrollWindow.scroll_vertical = int(panWindow.custom_minimum_size.y/3.5)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	# If the user has pressed the save button before closing the editor, the tileGrid.oldmap should
	# contain the same data as currentMap, so it shouldn't make a difference
	# If the user did not press the save button, we reset the map to what it was before the last save
	currentMap.set_data(tileGrid.oldmap.get_data().duplicate(true))
	queue_free()


func _on_rotate_map_button_up():
	tileGrid.rotate_map()


# When the user presses the map preview button
func _on_preview_map_button_up():
	map_preview.mapData = currentMap.get_data()
	map_preview.show()


# Function to set the values of the controls
func set_settings_values() -> void:
	# Set basic properties
	name_text_edit.text = currentMap.name
	description_text_edit.text = currentMap.description
	if not currentMap.categories.is_empty():
		categories_list.set_items(currentMap.categories)
	weight_spin_box.value = currentMap.weight

	# Set road connections using currentMap.get_connection()
	north_check_box.button_pressed = currentMap.get_connection("north") == "road"
	east_check_box.button_pressed = currentMap.get_connection("east") == "road"
	south_check_box.button_pressed = currentMap.get_connection("south") == "road"
	west_check_box.button_pressed = currentMap.get_connection("west") == "road"


# Function to get the values of the controls
func update_settings_values():
	# Update basic properties
	currentMap.name = name_text_edit.text
	currentMap.description = description_text_edit.text
	currentMap.categories = categories_list.get_items()
	currentMap.weight = int(weight_spin_box.value)

	# Update road connections using currentMap.set_connection()
	if north_check_box.button_pressed:
		currentMap.set_connection("north","road")
	else:
		currentMap.set_connection("north","ground")
	if east_check_box.button_pressed:
		currentMap.set_connection("east","road")
	else:
		currentMap.set_connection("east","ground")
	if south_check_box.button_pressed:
		currentMap.set_connection("south","road")
	else:
		currentMap.set_connection("south","ground")
	if west_check_box.button_pressed:
		currentMap.set_connection("west","road")
	else:
		currentMap.set_connection("west","ground")

func _on_select_mods_item_selected(index: int) -> void:
	# Read the mod ID from the select_mods OptionButton
	selectedMod = select_mods.get_item_text(index)
	# Refresh the lists with the new mod ID
	refresh_lists()
