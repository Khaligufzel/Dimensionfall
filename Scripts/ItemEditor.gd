extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one item
#It expects to save the data to a DItem instance that contains all data from an item
#To load data, provide the DItem instance


@export var tab_container: TabContainer = null

# Used to open the sprite selector popup
@export var item_image_display: TextureRect = null
@export var id_text_label: Label = null

# To show the name of the sprite
@export var path_text_label: Label = null

# Name and description of the item
@export var name_text_edit: TextEdit = null
@export var description_text_edit: TextEdit = null

#The actual sprite selector popup
@export var item_selector: Popup = null

# Inventory propeties
@export var volume_number_box: SpinBox = null
@export var weight_number_box: SpinBox = null
@export var stack_size_number_box: SpinBox = null
@export var max_stack_size_number_box: SpinBox = null

@export var types_container: HFlowContainer = null
@export var two_handed_check_box: CheckBox = null

@export var references_editor: Control = null



# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed()

var olddata: DItem # Remember what the value of the data was before editing
# The data that represents this item
# based on the ID that the user has selected in the content editor
var ditem: DItem = null:
	set(value):
		if value:
			ditem = value
			load_item_data()
                        item_selector.sprites_collection = ditem.parent.sprites
			olddata = DItem.new(ditem.get_data().duplicate(true), null)
		
func _ready():
	refresh_tab_visibility()


#This function update the form based on the contentData that has been loaded
func load_item_data() -> void:
        if item_image_display != null and ditem.spriteid:
                item_image_display.texture = ditem.parent.sprite_by_file(ditem.spriteid)
                path_text_label.text = ditem.spriteid
        if id_text_label != null:
                id_text_label.text = str(ditem.id)
        if name_text_edit != null:
                name_text_edit.text = ditem.name
        if description_text_edit != null:
                description_text_edit.text = ditem.description
        if volume_number_box != null:
                volume_number_box.value = float(ditem.volume)
        if weight_number_box != null:
                weight_number_box.value = float(ditem.weight)
        if stack_size_number_box != null:
                stack_size_number_box.value = float(ditem.stack_size)
        if max_stack_size_number_box != null:
                max_stack_size_number_box.value = float(ditem.max_stack_size)
        if two_handed_check_box != null:
                two_handed_check_box.button_pressed = ditem.two_handed

	# Loop through types_container children to load additional properties and set button_pressed
	for i in range(types_container.get_child_count()):
		var child = types_container.get_child(i)
		if child is CheckBox:
			var tabIndex = get_tab_by_title(child.text)
			var tab = tab_container.get_child(tabIndex)
			if not ditem.get(child.text.to_lower()) == null:
				tab.ditem = ditem
				 # Set button_pressed to true if contentData has the property
				child.button_pressed = true 
	refresh_tab_visibility()

	var myreferences: Dictionary = ditem.parent.get_references_by_id(ditem.id)
	references_editor.reference_data = myreferences


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the ditem
# The central array for item data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
        ditem.spriteid = path_text_label.text
        ditem.sprite = item_image_display.texture
	# We add this image property only for the itemprotosets of gloot
        ditem.image = ditem.parent.sprite_path + path_text_label.text
        ditem.name = name_text_edit.text
        ditem.description = description_text_edit.text
        ditem.volume = volume_number_box.value
        ditem.weight = weight_number_box.value
        ditem.stack_size = int(stack_size_number_box.value)
        ditem.max_stack_size = int(max_stack_size_number_box.value)
        ditem.two_handed = two_handed_check_box.button_pressed
	
	# Loop through types_container children to save additional properties
	for i in range(types_container.get_child_count()):
		var child = types_container.get_child(i)
		# Check if the child is a CheckBox and its button_pressed is true
		if child is CheckBox:
			if child.button_pressed:
				# Save additional properties if checkbox is checked
				var tabIndex = get_tab_by_title(child.text)
				var tab = tab_container.get_child(tabIndex)
				if tab:
					tab.save_properties()
			else:
				# Delete the property if checkbox is not checked and it exists in contentData
				if not ditem.get(child.text.to_lower()) == null:
					ditem.set(child.text.to_lower(),null)
	ditem.changed(olddata)
	data_changed.emit()
	olddata = DItem.new(ditem.get_data().duplicate(true), null)


#When the item_image_display is clicked, the user will be prompted to select an image from
# "res://Mods/Core/items/". The texture of the item_image_display will change to the selected image
func _on_item_image_display_gui_input(event) -> void:
        if event is InputEventMouseButton and event.pressed:
                item_selector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
        var itemTexture: Resource = clicked_sprite.get_texture()
        item_image_display.texture = itemTexture
        path_text_label.text = itemTexture.resource_path.get_file()


func _on_type_check_button_up():
	refresh_tab_visibility()

# This function loops over the checkboxes.
# It will show corresponding tabs in the tab container if the box is checked.
# It will hide the corresponding tabs in the tab container if the box is unchecked.
func refresh_tab_visibility() -> void:
	# Loop over all children of the types_container
	for i in range(types_container.get_child_count()):
		# Get the child node at index 'i'
		var child = types_container.get_child(i)
		# Check if the child is a CheckBox
		if child is CheckBox:
			# Find the tab index in the TabContainer with the same name as the checkbox text
			var tabIndex = get_tab_by_title(child.text)
			if tabIndex != -1:  # Check if a valid tab index is returned
				tab_container.set_tab_hidden(tabIndex, !child.button_pressed)
				var tab = tab_container.get_child(tabIndex)
				tab.ditem = ditem if child.button_pressed else null


# Returns the tab control with the given name
func get_tab_by_title(tabName: String) -> int:
	# Loop over all children of the types_container
	for i in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(i) == tabName:
			return i
	return -1
