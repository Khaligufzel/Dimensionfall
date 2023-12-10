extends Control

#This scene is a control which lists content from any loaded mods
#It allows users to select content for editing and creating new content
#This node should be used to load everything from one specific json file or one directory
#The json file or directory is specified by setting the source variable
#This node is intended to be used in the content editor

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null
signal item_activated(data: Array, itemID: String)
var is_collapsed: bool = false
var popupAction: String = ""
var contentdata: Array = []:
	set(newData):
		contentdata = newData
		load_data()
var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header



# This function will take a string and create a new json file with just {} as the contents.
#If the file already exists, we do not overwrite it
func create_new_json_file(filename: String = "", isArray: bool = true):
	# If no string was provided, return without doing anything.
	if filename.is_empty():
		return

	# If the file already exists, alert the user that the file already exists.
	if FileAccess.file_exists(filename):
#		print_debug("The file already exists: " + filename)
		return

	var file = FileAccess.open(filename, FileAccess.WRITE)
	#The file cen contain either one object or one array with a list of objects
	if isArray:
		file.store_string("[]")
	else:
		file.store_string("{}")
	file.close()
	load_data()


#This function adds items to the content list based on the provided path
#If the path is a directory, it will list all the files in the directory
#If the path is a json file, it will list all the items in the json file
func load_data():
	if contentdata.is_empty():
		return
	contentItems.clear()
	#If the first item is a string, it's a list of files.
	#Otherwise, it's a list of objects representing some kind of data
	if contentdata[0] is String:
		make_file_list()
	else:
		make_item_list()

func make_item_list():
	for item in contentdata:
		# get the id of the item, "missing_id" if not found
		var item_id: String = item.get("id", "missing_id")
		#Add the item and save the index number
		var item_index: int = contentItems.add_item(item_id)
		contentItems.set_item_metadata(item_index, item_id)
		
		if item.has("imagePath"):
			contentItems.set_item_icon(item_index,load(item["imagePath"]))

func make_file_list() -> void:
	for file_name in contentdata:
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(file_name.replace(".json", ""))
		#Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, file_name.replace(".json", ""))

# Executed when an item in ContentItems is double-clicked or 
# when the user selects an item in ContentItems and presses enter
# Index is the position in the ContentItems list starting from 0
func _on_content_items_item_activated(index: int):
	# Get the id of the item from the metadata
	var strItemID: String = contentItems.get_item_metadata(index)
	if strItemID:
		item_activated.emit(contentdata, strItemID)
	else:
		print_debug("Tried to signal that item with ID (" + str(index) + ") was activated,\
		 but the item has no metadata")

#This function will append an item to the game data
func add_item_to_data(id: String):
	Gamedata.add_id_to_data(contentdata, id)
	load_data()
	
#This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	popupAction = "Add"
	popup_textedit.text = ""
	pupup_ID.show()

#This function requires that an item from the list is selected
#Once clicked, it will show pupup_ID to ask the user for a new ID
#If the user enters an ID and presses OK, it will read the file from the source variable
#And duplicate the item that has the same ID as the ID that was selected
#The duplicate item will recieve the ID that the user has entered in the popup
#Lastly, the new duplicated item will be added to contentItems
func _on_duplicate_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	popupAction = "Duplicate"
	popup_textedit.text = selected_id
	pupup_ID.show()
	

#Called after the user enters an ID into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_ID.hide()
	var myText = popup_textedit.text
	if myText == "":
		return;
	if popupAction == "Add":
		if contentdata[0] is Dictionary:
			Gamedata.add_id_to_data(contentdata, myText)
		else:
			Gamedata.add_file_to_data(contentdata, myText)
	if popupAction == "Duplicate":
		if contentdata[0] is Dictionary:
			Gamedata.duplicate_item_in_data(contentdata,get_selected_item_text(),myText)
		else:
			print_debug("There should be code here for when a file in the gets duplicated")
	popupAction = ""
	load_data()

#Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()
	popupAction = ""

#This function requires that an item from the list is selected
#Once clicked, the selected item will be removed from contentItems
#It will also remove the item from the json file specified by source
func _on_delete_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	contentItems.remove_item(contentItems.get_selected_items()[0])
	Gamedata.remove_item_from_data(contentdata, selected_id)
	load_data()

func get_selected_item_text() -> String:
	if !contentItems.is_anything_selected():
		return ""
	return contentItems.get_item_text(contentItems.get_selected_items()[0])

#This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	contentItems.visible = is_collapsed
	if is_collapsed:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	is_collapsed = !is_collapsed
