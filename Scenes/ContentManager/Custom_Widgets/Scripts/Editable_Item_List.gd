extends Control

#This scene is a generic widget that allows users to add an item to the list
#It is intended to be used in the content editor
#After instantiating, set the header to indicate its contents
#Use the get_items function to get an array of items
#Emits signal "item_activated" when an item is doubleclicked

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_window: Popup = null
@export var popup_textedit: TextEdit = null
signal item_activated(itemText: String)
var is_collapsed: bool = true
@export var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header

#This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	contentItems.visible = is_collapsed
	is_collapsed = !is_collapsed

#This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	pupup_window.show()

#Called after the user enters a string into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_window.hide()
	if popup_textedit.text == "":
		return;
	contentItems.add_item(popup_textedit.text)

#Called after the users presses cancel on the popup asking for a string
func _on_cancel_button_up():
	pupup_window.hide()

#Called when an item in the list is activated by doubleclick or enter
func _on_content_items_item_activated(index):
	var strItemText: String = contentItems.get_item_text(index)
	if strItemText:
		item_activated.emit(strItemText)
	else:
		print_debug("Tried to signal that item with index (" + str(index) + ") was activated,\
		 but the item has no text")

func clear_list():
	contentItems.clear()

#This function returns all items in contentItems as an array
func get_items():
	var myArray: Array = []
	for item in contentItems.item_count:
		myArray.append(contentItems.get_item_text(item))
	return myArray
	
func add_item_to_list(itemText: String):
	contentItems.add_item(itemText)
	
