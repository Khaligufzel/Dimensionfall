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
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
var selectedMod: String = "Core"


# This function will load the contents of the data into the contentListInstance
func _ready():
	load_content_list(Gamedata.data.tacticalmaps, "Tactical Maps")
	# Hacky exception for maps, need to find a better solution
	load_content_list({"maps": true}, "Maps")
	load_content_list({"items": true}, "Items")
	load_content_list({"tiles": true}, "Terrain Tiles")
	load_content_list({"mobs": true}, "Mobs")
	# Hacky exception for furnitures, need to find a better solution
	load_content_list({"furnitures": true}, "Furniture")
	load_content_list({"itemgroups": true}, "Item Groups")
	load_content_list(Gamedata.data.wearableslots, "Wearable Slots")
	load_content_list(Gamedata.data.stats, "Stats")
	load_content_list(Gamedata.data.skills, "Skills")
	load_content_list(Gamedata.data.quests, "Quests")  # Added quests


func load_content_list(data: Dictionary, strHeader: String):
	# Instantiate a contentlist
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.header = strHeader
	contentListInstance.contentData = data
	contentListInstance.item_activated.connect(_on_content_item_activated)

	# Add it as a child to the content VBoxContainer
	content.add_child(contentListInstance)


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")


# The user has double-clicked or pressed enter on one of the items in the content lists
# Depending on whether the source is a JSON file, we are going to load the relevant content
func _on_content_item_activated(data: Dictionary, itemID: String, list: Control):
	if data.is_empty() or itemID == "":
		print_debug("Tried to load the selected content item, but either \
		data (Array) or itemID ("+itemID+") is empty")
		return

	# HACK Hacky implementation, need to find a better solution
	var editors = {
		"tiles": terrainTileEditor,
		"furnitures": furnitureEditor,
		"itemgroups": itemgroupEditor,
		"items": itemEditor,
		"mobs": mobEditor,
		"maps": mapEditor
	}

	for key in editors.keys():
		if data == {key: true}:
			instantiate_editor(data, itemID, editors[key], list)
			return
	
	if data == Gamedata.data.tacticalmaps:
		instantiate_editor(data, itemID, tacticalmapEditor, list)
	elif data == Gamedata.data.wearableslots:
		instantiate_editor(data, itemID, wearableslotEditor, list)
	elif data == Gamedata.data.stats:
		instantiate_editor(data, itemID, statsEditor, list)
	elif data == Gamedata.data.skills:
		instantiate_editor(data, itemID, skillsEditor, list)
	elif data == Gamedata.data.quests:
		instantiate_editor(data, itemID, questsEditor, list)


# This will add an editor to the content editor tab view. 
# The editor that should be instantiated is passed through in the newEditor parameter
# It is important that the editor has the property contentSource or contentData so it can be set
# If a tab for the given itemID already exists, switch to that tab.
# Otherwise, instantiate a new editor.
func instantiate_editor(data: Dictionary, itemID: String, newEditor: PackedScene, list: Control):
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
	
	if data == {"maps": true}:# HACK Hacky exception for maps, need to find a better solution
		newContentEditor.currentMap = Gamedata.maps.by_id(itemID)
		return
	if data == {"furnitures": true}:# HACK Hacky exception for furniture, need to find a better solution
		newContentEditor.dfurniture = Gamedata.furnitures.by_id(itemID)
		newContentEditor.data_changed.connect(list.load_data)
		return
	if data == {"itemgroups": true}:# HACK Hacky exception for itemgroups, need to find a better solution
		newContentEditor.ditemgroup = Gamedata.itemgroups.by_id(itemID)
		newContentEditor.data_changed.connect(list.load_data)
		return
	if data == {"items": true}:# HACK Hacky exception for items, need to find a better solution
		newContentEditor.ditem = Gamedata.items.by_id(itemID)
		newContentEditor.data_changed.connect(list.load_data)
		return
	if data == {"tiles": true}:# HACK Hacky exception for tiles, need to find a better solution
		newContentEditor.dtile = Gamedata.tiles.by_id(itemID)
		newContentEditor.data_changed.connect(list.load_data)
		return
	if data == {"mobs": true}:# HACK Hacky exception for mobs, need to find a better solution
		newContentEditor.dmob = Gamedata.mobs.by_id(itemID)
		newContentEditor.data_changed.connect(list.load_data)
		return
		
		
	if data.dataPath.ends_with(".json"):
		var itemdata: Dictionary = data.data[Gamedata.get_array_index_by_id(data, itemID)]
		# We only pass the data for the specific id to the editor
		newContentEditor.contentData = itemdata
		newContentEditor.data_changed.connect(_on_editor_data_changed)
	else:
		# If the data source does not end with json, it's a directory
		# So now we pass in the file we want the editor to edit
		newContentEditor.contentSource = data.dataPath + itemID + ".json"


# The content_list that had its data changed refreshes
func _on_editor_data_changed(data: Dictionary, _newdata: Dictionary, _olddata: Dictionary):
	# Loop over each of the content lists. Only the list that matches
	# the data will refresh
	for element in content.get_children():
		if element.contentData == data:
			element.load_data()
