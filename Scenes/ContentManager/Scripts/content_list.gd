extends Control

# This scene is a control which lists content from any loaded mods
# It allows users to select content for editing and creating new content
# This node should be used to load everything from one specific json file or one directory
# The json file or directory is specified by setting the source variable
# This node is intended to be used in the content editor

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null
signal item_activated(type: Gamedata.ContentType, itemID: String, list: Control)
var popupAction: String = ""
var contentType: Gamedata.ContentType:
	set(newData):
		contentType = newData
		load_data()

var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header


var is_collapsed: bool = false:
	get:
		return is_collapsed
	set(value):
		is_collapsed = value
		set_collapsed()
		save_collapse_state()

# This function adds items to the content list based on the provided path
# If the path is a directory, it will list all the files in the directory
# If the path is a json file, it will list all the items in the json file
func load_data():
	contentItems.clear()
	var loaders = {
		Gamedata.ContentType.MAPS: load_map_list,
		Gamedata.ContentType.TACTICALMAPS: load_tacticalmap_list,
		Gamedata.ContentType.FURNITURES: load_furnitures_list,
		Gamedata.ContentType.ITEMGROUPS: load_itemgroups_list,
		Gamedata.ContentType.ITEMS: load_items_list,
		Gamedata.ContentType.TILES: load_tiles_list,
		Gamedata.ContentType.MOBS: load_mobs_list,
		Gamedata.ContentType.PLAYERATTRIBUTES: load_playerattributes_list,
		Gamedata.ContentType.WEARABLESLOTS: load_wearableslots_list,
		Gamedata.ContentType.STATS: load_stats_list,
		Gamedata.ContentType.SKILLS: load_skills_list,
		Gamedata.ContentType.QUESTS: load_quests_list
	}
	loaders[contentType].call()
	load_collapse_state()

# Executed when an item in ContentItems is double-clicked or 
# when the user selects an item in ContentItems and presses enter
# Index is the position in the ContentItems list starting from 0
func _on_content_items_item_activated(index: int):
	# Get the id of the item from the metadata
	var strItemID: String = contentItems.get_item_metadata(index)
	if strItemID:
		item_activated.emit(contentType, strItemID, self)
	else:
		print_debug("Tried to signal that item with ID (" + str(index) + ") was activated,\
		 but the item has no metadata")

# This function will append an item to the game data
func add_item_to_data(id: String):
	Gamedata.add_id_to_data(contentType, id)
	load_data()

# This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	popupAction = "Add"
	popup_textedit.text = ""
	pupup_ID.show()

# This function requires that an item from the list is selected
# Once clicked, it will show pupup_ID to ask the user for a new ID
# If the user enters an ID and presses OK, it will read the file from the source variable
# And duplicate the item that has the same ID as the ID that was selected
# The duplicate item will recieve the ID that the user has entered in the popup
# Lastly, the new duplicated item will be added to contentItems
func _on_duplicate_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	popupAction = "Duplicate"
	popup_textedit.text = selected_id
	pupup_ID.show()

# Called after the user enters an ID into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_ID.hide()
	
	match contentType:
		Gamedata.ContentType.MAPS:
			add_map_popup_ok()
		
		Gamedata.ContentType.TACTICALMAPS:
			add_tacticalmap_popup_ok()
		
		Gamedata.ContentType.ITEMGROUPS:
			add_itemgroup_popup_ok()
		
		Gamedata.ContentType.FURNITURES:
			add_furniture_popup_ok()
		
		Gamedata.ContentType.PLAYERATTRIBUTES:
			add_playerattribute_popup_ok()
		
		Gamedata.ContentType.WEARABLESLOTS:
			add_wearableslot_popup_ok()
		
		Gamedata.ContentType.STATS:
			add_stat_popup_ok()
		
		Gamedata.ContentType.SKILLS:
			add_skill_popup_ok()
		
		Gamedata.ContentType.QUESTS:
			add_quest_popup_ok()
		
		Gamedata.ContentType.ITEMS:
			add_item_popup_ok()
		
		Gamedata.ContentType.TILES:
			add_tile_popup_ok()
		
		Gamedata.ContentType.MOBS:
			add_mob_popup_ok()
		
		_:
			# Handle unexpected content types or provide a default action
			print("Unknown content type:", contentType)


# Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()
	popupAction = ""

# This function requires that an item from the list is selected
# Once clicked, the selected item will be removed from contentItems
# It will also remove the item from the json file specified by source
func _on_delete_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	
	match contentType:
		Gamedata.ContentType.MAPS:
			delete_map(selected_id)
		
		Gamedata.ContentType.TACTICALMAPS:
			delete_tacticalmap(selected_id)
		
		Gamedata.ContentType.FURNITURES:
			delete_furniture(selected_id)
		
		Gamedata.ContentType.ITEMGROUPS:
			delete_itemgroup(selected_id)
		
		Gamedata.ContentType.ITEMS:
			delete_item(selected_id)
		
		Gamedata.ContentType.TILES:
			delete_tile(selected_id)
		
		Gamedata.ContentType.MOBS:
			delete_mob(selected_id)
		
		Gamedata.ContentType.PLAYERATTRIBUTES:
			delete_playerattribute(selected_id)
		
		Gamedata.ContentType.WEARABLESLOTS:
			delete_wearableslot(selected_id)
		
		Gamedata.ContentType.STATS:
			delete_stat(selected_id)
		
		Gamedata.ContentType.SKILLS:
			delete_skill(selected_id)
		
		Gamedata.ContentType.QUESTS:
			delete_quest(selected_id)
		
		_:
			# Handle unexpected content types or provide a default action
			print("Unknown content type:", contentType)


func get_selected_item_text() -> String:
	if not contentItems.is_anything_selected():
		return ""
	return contentItems.get_item_text(contentItems.get_selected_items()[0])


# This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	is_collapsed = !is_collapsed


func set_collapsed():
	contentItems.visible = not is_collapsed
	if not is_collapsed:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN


# Function to initiate drag data for selected item
# Only one item can be selected and dragged at a time.
# We get the selected item from contentItems
# This function should return a new object with an id property that holds the item's text
func _get_drag_data(_newpos):
	# Check if an item is selected
	var selected_index = contentItems.get_selected_items()
	if selected_index.size() == 0:
		return null  # No item selected, so no drag data should be initiated

	# Get the selected item text and ID (metadata, which should be the item ID)
	selected_index = selected_index[0]  # Take the first item in case of multiple (unlikely, but safe)
	var selected_item_text = contentItems.get_item_text(selected_index)
	var selected_item_id = contentItems.get_item_metadata(selected_index)

	# Create a drag preview
	# var preview = _create_drag_preview(selected_item_id)
	# set_drag_preview(preview)

	# Return an object with the necessary data
	return {"id": selected_item_id, "text": selected_item_text}


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, _data) -> bool:
	return false


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		print_debug("tried to drop data, but can't")


# Helper function to create a preview Control for dragging
func _create_drag_preview(item_id: String) -> Control:
	var preview = TextureRect.new()
	
	match contentType:
		Gamedata.ContentType.FURNITURES:
			preview.texture = Gamedata.furnitures.sprite_by_id(item_id)
		
		Gamedata.ContentType.ITEMGROUPS:
			preview.texture = Gamedata.itemgroups.sprite_by_id(item_id)
		
		Gamedata.ContentType.MAPS:
			preview.texture = Gamedata.maps.by_id(item_id).sprite
		
		Gamedata.ContentType.TILES:
			preview.texture = Gamedata.tiles.by_id(item_id).sprite
		
		Gamedata.ContentType.MOBS:
			preview.texture = Gamedata.mobs.by_id(item_id).sprite
		
		Gamedata.ContentType.ITEMS:
			preview.texture = Gamedata.items.by_id(item_id).sprite
		
		Gamedata.ContentType.PLAYERATTRIBUTES:
			preview.texture = Gamedata.playerattributes.by_id(item_id).sprite
		
		Gamedata.ContentType.WEARABLESLOTS:
			preview.texture = Gamedata.wearableslots.by_id(item_id).sprite
		
		Gamedata.ContentType.STATS:
			preview.texture = Gamedata.stats.by_id(item_id).sprite
		
		Gamedata.ContentType.SKILLS:
			preview.texture = Gamedata.skills.by_id(item_id).sprite
		
		Gamedata.ContentType.QUESTS:
			preview.texture = Gamedata.quests.by_id(item_id).sprite
		
		_:
			# Handle unexpected content types or provide a default action
			print("Unknown content type:", contentType)

	preview.custom_minimum_size = Vector2(32, 32)  # Set the desired size for your preview
	return preview



var start_point
var end_point
var mouse_button_is_pressed
# Overriding the _gui_input function to detect drag attempts
func _on_content_items_gui_input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					start_point = event.global_position
					mouse_button_is_pressed = true
				else:
					# Finalize drawing/copying operation
					end_point = event.global_position
					if mouse_button_is_pressed:
						var drag_threshold: int = 5  # Pixels
						var distance_dragged = start_point.distance_to(end_point)
						
						if distance_dragged <= drag_threshold:
							print_debug("Released the mouse button, but clicked instead of dragged")
					mouse_button_is_pressed = false
	# When the users presses and holds the mouse wheel, we scroll the grid
	if event is InputEventMouseMotion:
		end_point = event.global_position
		if mouse_button_is_pressed:
			if not _get_drag_data(end_point) == null:
				var drag_data: Dictionary = _get_drag_data(end_point)
				force_drag(drag_data, _create_drag_preview(drag_data.id))


func _on_content_items_mouse_entered():
	mouse_button_is_pressed = false


func save_collapse_state():
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Ensure to load existing settings to not overwrite them
	var err = config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Failed to load settings:", err)
		return

	config.set_value("contenteditor:contentlist:" + header, "is_collapsed", is_collapsed)
	config.save(path)


func load_collapse_state():
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Load the config file
	var err = config.load(path)
	if err == OK:
		if config.has_section_key("contenteditor:contentlist:" + header, "is_collapsed"):
			is_collapsed = config.get_value("contenteditor:contentlist:" + header, "is_collapsed")
			set_collapsed()
		else:
			print("No saved state for:", header)
	else:
		print("Failed to load settings for:", header, "with error:", err)



func load_map_list():
	var maplist: Dictionary = Gamedata.maps.get_maps()
	for map: String in maplist.keys():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(map)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, map)
		var mySprite: Texture = maplist[map].sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)


func load_tacticalmap_list():
	var maplist: Dictionary = Gamedata.tacticalmaps.get_maps()
	for map: String in maplist.keys():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(map)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, map)


# Load the furniture list
func load_furnitures_list():
	var furniturelist: Dictionary = Gamedata.furnitures.get_furnitures()
	for furniture: DFurniture in furniturelist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(furniture.id)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, furniture.id)
		var mySprite: Texture = furniture.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)

# Load the itemgroups list
func load_itemgroups_list():
	var itemgrouplist: Dictionary = Gamedata.itemgroups.get_itemgroups()
	for itemgroup: DItemgroup in itemgrouplist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(itemgroup.id)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, itemgroup.id)
		var mySprite: Texture = itemgroup.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)

# Load the items list
func load_items_list():
	var itemlist: Dictionary = Gamedata.items.get_items()
	for item: DItem in itemlist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(item.id)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, item.id)
		var mySprite: Texture = item.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)

# Load the tiles list
func load_tiles_list():
	var tilelist: Dictionary = Gamedata.tiles.get_tiles()
	for tile: DTile in tilelist.values():
		# Add all the filenames to the Contenttiles list as child nodes
		var tile_index: int = contentItems.add_item(tile.id)
		# Add the ID as metadata which can be used to load the tile data
		contentItems.set_item_metadata(tile_index, tile.id)
		var mySprite: Texture = tile.sprite
		if mySprite:
			contentItems.set_item_icon(tile_index, mySprite)

# Load the mobs list
func load_mobs_list():
	var moblist: Dictionary = Gamedata.mobs.get_mobs()
	for mob: DMob in moblist.values():
		# Add all the filenames to the Contentmobs list as child nodes
		var mob_index: int = contentItems.add_item(mob.id)
		# Add the ID as metadata which can be used to load the mob data
		contentItems.set_item_metadata(mob_index, mob.id)
		var mySprite: Texture = mob.sprite
		if mySprite:
			contentItems.set_item_icon(mob_index, mySprite)


# Load the playerattribute list
func load_playerattributes_list():
	var playerattributelist: Dictionary = Gamedata.playerattributes.get_playerattributes()
	for playerattribute: DPlayerAttribute in playerattributelist.values():
		# Add all the filenames to the Contentmobs list as child nodes
		var attribute_index: int = contentItems.add_item(playerattribute.id)
		# Add the ID as metadata which can be used to load the mob data
		contentItems.set_item_metadata(attribute_index, playerattribute.id)
		var mySprite: Texture = playerattribute.sprite
		if mySprite:
			contentItems.set_item_icon(attribute_index, mySprite)


# Load the wearableslot list
func load_wearableslots_list():
	var wearableslotlist: Dictionary = Gamedata.wearableslots.get_wearableslots()
	for wearableslot: DWearableSlot in wearableslotlist.values():
		# Add all the filenames to the Contentmobs list as child nodes
		var attribute_index: int = contentItems.add_item(wearableslot.id)
		# Add the ID as metadata which can be used to load the mob data
		contentItems.set_item_metadata(attribute_index, wearableslot.id)
		var mySprite: Texture = wearableslot.sprite
		if mySprite:
			contentItems.set_item_icon(attribute_index, mySprite)


# Load the stats list
func load_stats_list():
	var statslist: Dictionary = Gamedata.stats.get_stats()
	for stat: DStat in statslist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(stat.id)
		# Add the ID as metadata which can be used to load the stat data
		contentItems.set_item_metadata(item_index, stat.id)
		var mySprite: Texture = stat.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)


# Load the skills list
func load_skills_list():
	var skillslist: Dictionary = Gamedata.skills.get_skills()
	for skill: DSkill in skillslist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(skill.id)
		# Add the ID as metadata which can be used to load the skill data
		contentItems.set_item_metadata(item_index, skill.id)
		var mySprite: Texture = skill.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)


# Load the quests list
func load_quests_list():
	var questslist: Dictionary = Gamedata.quests.get_quests()
	for quest: DQuest in questslist.values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(quest.id)
		# Add the ID as metadata which can be used to load the quest data
		contentItems.set_item_metadata(item_index, quest.id)
		var mySprite: Texture = quest.sprite
		if mySprite:
			contentItems.set_item_icon(item_index, mySprite)


func add_map_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.maps.add_new_map(myText)
	if popupAction == "Duplicate":
		Gamedata.maps.duplicate_map_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_tacticalmap_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.tacticalmaps.add_new_tacticalmap(myText)
	if popupAction == "Duplicate":
		Gamedata.tacticalmaps.duplicate_tacticalmap_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_playerattribute_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.playerattributes.add_new_playerattribute(myText)
	if popupAction == "Duplicate":
		Gamedata.playerattributes.duplicate_playerattribute_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_wearableslot_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.wearableslots.add_new_wearableslot(myText)
	if popupAction == "Duplicate":
		Gamedata.wearableslots.duplicate_wearableslots_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_furniture_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.furnitures.add_new_furniture(myText)
	if popupAction == "Duplicate":
		Gamedata.furnitures.duplicate_furniture_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_itemgroup_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.itemgroups.add_new_itemgroup(myText)
	if popupAction == "Duplicate":
		Gamedata.itemgroups.duplicate_itemgroup_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_stat_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.stats.add_new_stat(myText)
	if popupAction == "Duplicate":
		Gamedata.stats.duplicate_stat_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_skill_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.skills.add_new_skill(myText)
	if popupAction == "Duplicate":
		Gamedata.skills.duplicate_skill_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_quest_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.quests.add_new_quest(myText)
	if popupAction == "Duplicate":
		Gamedata.quests.duplicate_quest_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_item_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.items.add_new_item(myText)
	if popupAction == "Duplicate":
		Gamedata.items.duplicate_item_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_tile_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.tiles.add_new_tile(myText)
	if popupAction == "Duplicate":
		Gamedata.tiles.duplicate_tile_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func add_mob_popup_ok():
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		Gamedata.mobs.add_new_mob(myText)
	if popupAction == "Duplicate":
		Gamedata.mobs.duplicate_mob_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


func delete_map(selected_id) -> void:
	Gamedata.maps.delete_map(selected_id)
	load_data()

func delete_tacticalmap(selected_id) -> void:
	Gamedata.tacticalmaps.delete_map(selected_id)
	load_data()

func delete_furniture(selected_id) -> void:
	Gamedata.furnitures.delete_furniture(selected_id)
	load_data()

func delete_itemgroup(selected_id) -> void:
	Gamedata.itemgroups.delete_itemgroup(selected_id)
	load_data()

func delete_item(selected_id) -> void:
	Gamedata.items.delete_item(selected_id)
	load_data()

func delete_tile(selected_id) -> void:
	Gamedata.tiles.delete_tile(selected_id)
	load_data()

func delete_mob(selected_id) -> void:
	Gamedata.mobs.delete_mob(selected_id)
	load_data()

func delete_playerattribute(selected_id) -> void:
	Gamedata.playerattributes.delete_playerattribute(selected_id)
	load_data()

func delete_wearableslot(selected_id) -> void:
	Gamedata.wearableslots.delete_playerattribute(selected_id)
	load_data()

func delete_stat(selected_id) -> void:
	Gamedata.stats.delete_stat(selected_id)
	load_data()

func delete_skill(selected_id) -> void:
	Gamedata.skills.delete_skill(selected_id)
	load_data()

func delete_quest(selected_id) -> void:
	Gamedata.quests.delete_quest(selected_id)
	load_data()
