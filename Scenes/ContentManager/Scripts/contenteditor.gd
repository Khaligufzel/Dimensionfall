extends Control

@export var select_mods: OptionButton = null
@export var contentList: PackedScene = null
@export var mapEditor: PackedScene = null
@export var tacticalmapEditor: PackedScene = null
@export var terrainTileEditor: PackedScene = null
@export var furnitureEditor: PackedScene = null
@export var itemEditor: PackedScene = null
@export var mobEditor: PackedScene = null
@export var itemgroupEditor: PackedScene = null
@export var wearableslotEditor: PackedScene = null
@export var statsEditor: PackedScene = null
@export var skillsEditor: PackedScene = null
@export var questsEditor: PackedScene = null
@export var playerattributesEditor: PackedScene = null
@export var overmapareaEditor: PackedScene = null
@export var mobgroupsEditor: PackedScene = null
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
@export var type_selector_menu_button: MenuButton = null
var selectedMod: String = "Core"

# This function will load the contents of the data into the contentListInstance
func _ready():
	populate_select_mods()  # Populate the select_mods OptionButton
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
	# Populate the type_selector_menu_button with items
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
	# Instantiate a contentlist
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.header = strHeader
	contentListInstance.contentType = type
	contentListInstance.item_activated.connect(_on_content_item_activated)

	# Add it as a child to the content VBoxContainer
	content.add_child(contentListInstance)


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")


# The user has double-clicked or pressed enter on one of the items in the content lists
# Depending on whether the source is a JSON file, we are going to load the relevant content
func _on_content_item_activated(type: DMod.ContentType, itemID: String, list: Control):
	if itemID == "":
		print_debug("Tried to load the selected content item, but either \
		data (Array) or itemID ("+itemID+") is empty")
		return

	# HACK Hacky implementation, need to find a better solution
	var editors = {
		DMod.ContentType.TILES: terrainTileEditor,
		DMod.ContentType.FURNITURES: furnitureEditor,
		DMod.ContentType.ITEMGROUPS: itemgroupEditor,
		DMod.ContentType.ITEMS: itemEditor,
		DMod.ContentType.MOBS: mobEditor,
		DMod.ContentType.MAPS: mapEditor,
		DMod.ContentType.TACTICALMAPS: tacticalmapEditor,
		DMod.ContentType.PLAYERATTRIBUTES: playerattributesEditor,
		DMod.ContentType.WEARABLESLOTS: wearableslotEditor,
		DMod.ContentType.STATS: statsEditor,
		DMod.ContentType.SKILLS: skillsEditor,
		DMod.ContentType.QUESTS: questsEditor,
		DMod.ContentType.OVERMAPAREAS: overmapareaEditor,
		DMod.ContentType.MOBGROUPS: mobgroupsEditor
	}

	instantiate_editor(type, itemID, editors[type], list)


# This will add an editor to the content editor tab view. 
# The editor that should be instantiated is passed through in the newEditor parameter
# It is important that the editor has the property contentSource or contentData so it can be set
# If a tab for the given itemID already exists, switch to that tab.
# Otherwise, instantiate a new editor.
func instantiate_editor(type: DMod.ContentType, itemID: String, newEditor: PackedScene, list: Control):
	# Check if a tab for the itemID already exists
	for i in range(tabContainer.get_child_count()):
		var child = tabContainer.get_child(i)
		if child.name == itemID:
			# Tab for itemID exists, switch to this tab
			tabContainer.current_tab = i
			return

	# If no existing tab is found, instantiate a new editor
	var newContentEditor: Control = newEditor.instantiate()
	newContentEditor.name = itemID
	tabContainer.add_child(newContentEditor)
	tabContainer.current_tab = tabContainer.get_child_count() - 1
	
	match type:
		DMod.ContentType.MAPS:
			newContentEditor.currentMap = Gamedata.maps.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.TACTICALMAPS:
			newContentEditor.currentMap = Gamedata.tacticalmaps.by_id(itemID)
		
		DMod.ContentType.FURNITURES:
			newContentEditor.dfurniture = Gamedata.furnitures.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.ITEMGROUPS:
			newContentEditor.ditemgroup = Gamedata.itemgroups.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.ITEMS:
			newContentEditor.ditem = Gamedata.items.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.TILES:
			newContentEditor.dtile = Gamedata.tiles.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.MOBS:
			newContentEditor.dmob = Gamedata.mobs.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.PLAYERATTRIBUTES:
			newContentEditor.dplayerattribute = Gamedata.playerattributes.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.WEARABLESLOTS:
			newContentEditor.dwearableslot = Gamedata.wearableslots.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.STATS:
			newContentEditor.dstat = Gamedata.mods.by_id("Core").stats.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.SKILLS:
			newContentEditor.dskill = Gamedata.skills.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.QUESTS:
			newContentEditor.dquest = Gamedata.quests.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.OVERMAPAREAS:
			newContentEditor.dovermaparea = Gamedata.overmapareas.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		DMod.ContentType.MOBGROUPS:
			newContentEditor.dmobgroup = Gamedata.mobgroups.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		_:
			print("Unknown content type:", type)


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
		"Stats", "Skills", "Quests", "Overmap areas", "Mob groups"
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
	popup_menu.id_pressed.connect(_on_type_selected)


# Function to handle item selection from the popup menu and save the state
func _on_type_selected(id):
	var popup_menu = type_selector_menu_button.get_popup()
	var item_text = popup_menu.get_item_text(id)
	
	# Toggle the checked state of the item
	var is_checked = popup_menu.is_item_checked(id)
	popup_menu.set_item_checked(id, not is_checked)

	# Show or hide the content list based on the checked state
	if not is_checked:
		show_content_list(item_text)
	else:
		hide_content_list(item_text)

	# Save the new state to the configuration file
	save_item_state(item_text, not is_checked)

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

# Function to save the state of an item to the configuration file
func save_item_state(item_text: String, is_checked: bool):
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Load existing settings to not overwrite them
	var err = config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Failed to load settings:", err)
		return

	config.set_value("type_selector", item_text, is_checked)
	config.save(path)


func _on_select_mods_item_selected(index: int) -> void:
	pass # Replace with function body.
