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
# An attribute can have either default mode or fixed mode. The tab that is visible will get 
# saved into the dplayerattribute's data.
@export var mode_tab_container: TabContainer = null
# Shows controls for fixed_mode properties and is the second child of mode_tab_container
@export var fixed_grid: GridContainer = null
@export var fixed_amount_spin_box: SpinBox = null
# Shows controls for default properties and is the first child of mode_tab_container
@export var default_grid: GridContainer = null


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


# This function updates the form based on the DPlayerAttribute data that has been loaded
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
	
	# Process and show the correct mode
	process_default_mode()
	process_fixed_mode()

	# Fallback: If neither mode exists, show default_mode tab
	if not dplayerattribute.default_mode and not dplayerattribute.fixed_mode:
		mode_tab_container.set_current_tab(0)  # Show default_mode tab by default


# Function to handle loading and showing default mode
func process_default_mode() -> void:
	if dplayerattribute.default_mode:
		mode_tab_container.set_current_tab(0)  # Make default_mode tab visible
		if min_amount_spinbox != null:
			min_amount_spinbox.value = dplayerattribute.default_mode.min_amount
		if max_amount_spinbox != null:
			max_amount_spinbox.value = dplayerattribute.default_mode.max_amount
		if current_amount_spinbox != null:
			current_amount_spinbox.value = dplayerattribute.default_mode.current_amount
		if depletion_rate_spinbox != null:
			depletion_rate_spinbox.value = dplayerattribute.default_mode.depletion_rate
		if depletion_effect != null:
			update_depleted_effect_option(dplayerattribute.default_mode.depletion_effect)
		# Load the UI color into the color picker
		if ui_color_picker != null:
			ui_color_picker.color = Color.html(dplayerattribute.default_mode.ui_color)
	else:
		mode_tab_container.set_current_tab(0)  # Hide default_mode tab if it doesn't exist


# Function to handle loading and showing fixed mode
func process_fixed_mode() -> void:
	if dplayerattribute.fixed_mode:
		mode_tab_container.set_current_tab(1)  # Make fixed_mode tab visible
		if fixed_amount_spin_box != null:
			fixed_amount_spin_box.value = dplayerattribute.fixed_mode.amount
	else:
		mode_tab_container.set_current_tab(1)  # Hide fixed_mode tab if it doesn't exist


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


# This function handles saving the data from the UI into the DPlayerAttribute instance
func _on_save_button_button_up() -> void:
	dplayerattribute.spriteid = path_text_label.text
	dplayerattribute.sprite = icon_rect.texture
	dplayerattribute.name = name_text_edit.text
	dplayerattribute.description = description_text_edit.text

	var current_tab = mode_tab_container.get_current_tab_control()
	# Process saving based on which tab is visible
	if current_tab == default_grid:  # DefaultMode tab is visible
		save_default_mode()
	elif current_tab == fixed_grid:  # FixedMode tab is visible
		save_fixed_mode()

	dplayerattribute.changed(olddata)
	data_changed.emit()
	olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true))


# Function to save data into default mode
func save_default_mode() -> void:
	if not dplayerattribute.default_mode:
		dplayerattribute.default_mode = DPlayerAttribute.DefaultMode.new({})  # Initialize default_mode if not present
	dplayerattribute.default_mode.min_amount = min_amount_spinbox.value
	dplayerattribute.default_mode.max_amount = max_amount_spinbox.value
	dplayerattribute.default_mode.current_amount = current_amount_spinbox.value
	dplayerattribute.default_mode.depletion_rate = depletion_rate_spinbox.value
	dplayerattribute.default_mode.depletion_effect = depletion_effect.get_item_text(depletion_effect.selected)
	dplayerattribute.default_mode.ui_color = ui_color_picker.color.to_html()

	# Delete fixed_mode if it exists
	if dplayerattribute.fixed_mode:
		dplayerattribute.fixed_mode = null


# Function to save data into fixed mode
func save_fixed_mode() -> void:
	if not dplayerattribute.fixed_mode:
		dplayerattribute.fixed_mode = DPlayerAttribute.FixedMode.new({})  # Initialize fixed_mode if not present
	dplayerattribute.fixed_mode.amount = fixed_amount_spin_box.value

	# Delete default_mode if it exists
	if dplayerattribute.default_mode:
		dplayerattribute.default_mode = null


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
