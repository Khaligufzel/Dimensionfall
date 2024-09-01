extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one playerattribute
# It expects to save the data to a DPlayerAttribute instance that contains all data from a attribute
# To load data, provide the DPlayerAttribute to edit


@export var icon_rect: TextureRect = null
@export var id_text_label: Label = null
@export var path_text_label: Label = null
@export var name_text_edit: TextEdit = null
@export var description_text_edit: TextEdit = null
@export var sprite_selector: Popup = null # Allows selecting a sprite
@export var min_amount_spinbox: SpinBox = null
@export var max_amount_spinbox: SpinBox = null
@export var current_amount_spinbox: SpinBox = null
@export var depletion_rate_spinbox: SpinBox = null
@export var depletion_effect: OptionButton = null
@export var ui_color_picker: ColorPicker = null


signal data_changed()
var olddata: DPlayerAttribute # Remember what the value of the data was before editing
# The data that represents this playerattribute
# The data is selected from Gamedata.playerattributes
# based on the ID that the user has selected in the content editor
var dplayerattribute: DPlayerAttribute:
	set(value):
		dplayerattribute = value
		load_playerattribute_data()
		sprite_selector.sprites_collection = Gamedata.playerattributes.sprites
		olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true))


# This function update the form based on the DMob data that has been loaded
func load_playerattribute_data() -> void:
	if not icon_rect == null and dplayerattribute.sprite:
		icon_rect.texture = dplayerattribute.sprite
		path_text_label.text = dplayerattribute.spriteid
	if id_text_label != null:
		id_text_label.text = str(dplayerattribute.id)
	if name_text_edit != null:
		name_text_edit.text = dplayerattribute.name
	if description_text_edit != null:
		description_text_edit.text = dplayerattribute.description
	if min_amount_spinbox != null:
		min_amount_spinbox.value = dplayerattribute.min_amount
	if max_amount_spinbox != null:
		max_amount_spinbox.value = dplayerattribute.max_amount
	if current_amount_spinbox != null:
		current_amount_spinbox.value = dplayerattribute.current_amount
	if depletion_rate_spinbox != null:
		depletion_rate_spinbox.value = dplayerattribute.depletion_rate
	if depletion_effect != null:
		update_depleted_effect_option(dplayerattribute.depletion_effect)
	# Load the UI color into the color picker
	if ui_color_picker != null:
		ui_color_picker.color = Color.html(dplayerattribute.ui_color)


# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()



# Update the selected option in the SlotOptionButton to match the specified slot name
func update_depleted_effect_option(effectname: String):
	var items = depletion_effect.get_item_count()
	for i in range(items):
		if depletion_effect.get_item_text(i) == effectname:
			depletion_effect.selected = i
			return


# This function takes all data from the form elements and stores them in the DMob instance
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dplayerattribute.spriteid = path_text_label.text
	dplayerattribute.sprite = icon_rect.texture
	dplayerattribute.name = name_text_edit.text
	dplayerattribute.description = description_text_edit.text
	dplayerattribute.min_amount = int(min_amount_spinbox.value)
	dplayerattribute.max_amount = max_amount_spinbox.value
	dplayerattribute.current_amount = int(current_amount_spinbox.value)
	dplayerattribute.depletion_rate = depletion_rate_spinbox.value
	dplayerattribute.depletion_effect = depletion_effect.get_item_text(depletion_effect.selected)
	# Save the selected color from the color picker back to dplayerattribute
	dplayerattribute.ui_color = ui_color_picker.color.to_html()

	dplayerattribute.changed(olddata)
	data_changed.emit()
	olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true))

# When the icon_rect is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/PlayerAttributes/". The texture of the icon_rect will change to the selected image
func _on_attribute_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		sprite_selector.show()


# When the player presses "ok" on the icon selection popup
func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var playerattributeTexture: Resource = clicked_sprite.get_texture()
	icon_rect.texture = playerattributeTexture
	path_text_label.text = playerattributeTexture.resource_path.get_file()
