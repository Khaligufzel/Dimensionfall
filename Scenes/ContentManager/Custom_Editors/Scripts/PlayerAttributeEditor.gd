extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one playerattribute
# It expects to save the data to a DPlayerAttribute instance that contains all data from a attribute
# To load data, provide the DPlayerAttribute to edit

@export var playerattributeImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var playerattributeSelector: Popup = null # Allows selecting a sprite
@export var min_amount_numedit: SpinBox
@export var max_amount_numedit: SpinBox
@export var current_amount_numedit: SpinBox
@export var depletion_rate_numedit: SpinBox

signal data_changed()
var olddata: DPlayerAttribute # Remember what the value of the data was before editing
# The data that represents this playerattribute
# The data is selected from Gamedata.playerattributes
# based on the ID that the user has selected in the content editor
var dplayerattribute: DPlayerAttribute:
	set(value):
		dplayerattribute = value
		load_playerattribute_data()
		playerattributeSelector.sprites_collection = Gamedata.playerattributes.sprites
		olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true))


# This function update the form based on the DMob data that has been loaded
func load_playerattribute_data() -> void:
	if not playerattributeImageDisplay == null and dplayerattribute.sprite:
		playerattributeImageDisplay.texture = dplayerattribute.sprite
		PathTextLabel.text = dplayerattribute.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dplayerattribute.id)
	if NameTextEdit != null:
		NameTextEdit.text = dplayerattribute.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dplayerattribute.description
	if min_amount_numedit != null:
		min_amount_numedit.value = dplayerattribute.min_amount
	if max_amount_numedit != null:
		max_amount_numedit.value = dplayerattribute.max_amount
	if current_amount_numedit != null:
		current_amount_numedit.value = dplayerattribute.current_amount
	if depletion_rate_numedit != null:
		depletion_rate_numedit.value = dplayerattribute.depletion_rate

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DMob instance
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dplayerattribute.spriteid = PathTextLabel.text
	dplayerattribute.name = NameTextEdit.text
	dplayerattribute.description = DescriptionTextEdit.text
	dplayerattribute.min_amount = int(min_amount_numedit.value)
	dplayerattribute.max_amount = max_amount_numedit.value
	dplayerattribute.current_amount = int(current_amount_numedit.value)
	dplayerattribute.depletion_rate = depletion_rate_numedit.value

	dplayerattribute.changed(olddata)
	data_changed.emit()
	olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true))

# When the playerattributeImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/PlayerAttributes/". The texture of the playerattributeImageDisplay will change to the selected image
func _on_attribute_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		playerattributeSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var playerattributeTexture: Resource = clicked_sprite.get_texture()
	playerattributeImageDisplay.texture = playerattributeTexture
	PathTextLabel.text = playerattributeTexture.resource_path.get_file()
