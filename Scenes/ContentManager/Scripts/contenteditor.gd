extends Control

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
	load_content_list(Gamedata.ContentType.MAPS, "Maps")
	load_content_list(Gamedata.ContentType.TACTICALMAPS, "Tactical Maps")
	load_content_list(Gamedata.ContentType.ITEMS, "Items")
	load_content_list(Gamedata.ContentType.TILES, "Terrain Tiles")
	load_content_list(Gamedata.ContentType.MOBS, "Mobs")
	load_content_list(Gamedata.ContentType.FURNITURES, "Furniture")
	load_content_list(Gamedata.ContentType.ITEMGROUPS, "Item Groups")
	load_content_list(Gamedata.ContentType.PLAYERATTRIBUTES, "Player Attributes")
	load_content_list(Gamedata.ContentType.WEARABLESLOTS, "Wearable Slots")
	load_content_list(Gamedata.ContentType.STATS, "Stats")
	load_content_list(Gamedata.ContentType.SKILLS, "Skills")
	load_content_list(Gamedata.ContentType.QUESTS, "Quests")
	load_content_list(Gamedata.ContentType.OVERMAPAREAS, "Overmap areas")
	load_content_list(Gamedata.ContentType.MOBGROUPS, "Mob groups")
	# Populate the type_selector_menu_button with items
	populate_type_selector_menu_button()


func load_content_list(type: Gamedata.ContentType, strHeader: String):
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
func _on_content_item_activated(type: Gamedata.ContentType, itemID: String, list: Control):
	if itemID == "":
		print_debug("Tried to load the selected content item, but either \
		data (Array) or itemID ("+itemID+") is empty")
		return

	# HACK Hacky implementation, need to find a better solution
	var editors = {
		Gamedata.ContentType.TILES: terrainTileEditor,
		Gamedata.ContentType.FURNITURES: furnitureEditor,
		Gamedata.ContentType.ITEMGROUPS: itemgroupEditor,
		Gamedata.ContentType.ITEMS: itemEditor,
		Gamedata.ContentType.MOBS: mobEditor,
		Gamedata.ContentType.MAPS: mapEditor,
		Gamedata.ContentType.TACTICALMAPS: tacticalmapEditor,
		Gamedata.ContentType.PLAYERATTRIBUTES: playerattributesEditor,
		Gamedata.ContentType.WEARABLESLOTS: wearableslotEditor,
		Gamedata.ContentType.STATS: statsEditor,
		Gamedata.ContentType.SKILLS: skillsEditor,
		Gamedata.ContentType.QUESTS: questsEditor,
		Gamedata.ContentType.OVERMAPAREAS: overmapareaEditor,
		Gamedata.ContentType.MOBGROUPS: mobgroupsEditor
	}

	instantiate_editor(type, itemID, editors[type], list)


# This will add an editor to the content editor tab view. 
# The editor that should be instantiated is passed through in the newEditor parameter
# It is important that the editor has the property contentSource or contentData so it can be set
# If a tab for the given itemID already exists, switch to that tab.
# Otherwise, instantiate a new editor.
func instantiate_editor(type: Gamedata.ContentType, itemID: String, newEditor: PackedScene, list: Control):
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
		Gamedata.ContentType.MAPS:
			newContentEditor.currentMap = Gamedata.maps.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.TACTICALMAPS:
			newContentEditor.currentMap = Gamedata.tacticalmaps.by_id(itemID)
		
		Gamedata.ContentType.FURNITURES:
			newContentEditor.dfurniture = Gamedata.furnitures.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.ITEMGROUPS:
			newContentEditor.ditemgroup = Gamedata.itemgroups.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.ITEMS:
			newContentEditor.ditem = Gamedata.items.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.TILES:
			newContentEditor.dtile = Gamedata.tiles.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.MOBS:
			newContentEditor.dmob = Gamedata.mobs.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.PLAYERATTRIBUTES:
			newContentEditor.dplayerattribute = Gamedata.playerattributes.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.WEARABLESLOTS:
			newContentEditor.dwearableslot = Gamedata.wearableslots.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.STATS:
			newContentEditor.dstat = Gamedata.mods["Core"].stats.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.SKILLS:
			newContentEditor.dskill = Gamedata.skills.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.QUESTS:
			newContentEditor.dquest = Gamedata.quests.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.OVERMAPAREAS:
			newContentEditor.dovermaparea = Gamedata.overmapareas.by_id(itemID)
			newContentEditor.data_changed.connect(list.load_data)
		
		Gamedata.ContentType.MOBGROUPS:
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
