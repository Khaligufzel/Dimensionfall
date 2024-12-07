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
@export var maxed_effect_option_button: OptionButton = null
@export var ui_color_picker: ColorPicker = null
# An attribute can have either default mode or fixed mode. The tab that is visible will get 
# saved into the dplayerattribute's data.
@export var mode_tab_container: TabContainer = null
# Shows controls for fixed_mode properties and is the second child of mode_tab_container
@export var fixed_grid: GridContainer = null
@export var fixed_amount_spin_box: SpinBox = null
@export var hide_when_empty_check_box: CheckBox = null
@export var depleting_effect_option_button: OptionButton = null
@export var drain_attribute_grid_container: GridContainer = null
@export var drain_attribute_panel_container: PanelContainer = null
@export var default_grid: HBoxContainer = null


signal data_changed()
var olddata: DPlayerAttribute # Remember what the value of the data was before editing
# The data that represents this playerattribute
# The data is selected from dplayerattribute.parent
# based on the ID that the user has selected in the content editor
var dplayerattribute: DPlayerAttribute:
	set(value):
		dplayerattribute = value
		load_playerattribute_data()
		sprite_selector.sprites_collection = dplayerattribute.parent.sprites
		olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true), null)


func _ready() -> void:
	# Set drag forwarding for the drain_attribute_grid_container
	drain_attribute_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_attribute_data)
	
	# Connect the signal for when the depleting effect option changes
	depleting_effect_option_button.item_selected.connect(_on_depleting_effect_option_changed)


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
		if maxed_effect_option_button != null:
			select_optionbutton_item_by_text(dplayerattribute.default_mode.maxed_effect, maxed_effect_option_button)
		if depletion_effect != null:
			select_optionbutton_item_by_text(dplayerattribute.default_mode.depletion_effect, depletion_effect)
		if depleting_effect_option_button != null:
			select_optionbutton_item_by_text(dplayerattribute.default_mode.depleting_effect, depleting_effect_option_button)
			_on_depleting_effect_option_changed(depleting_effect_option_button.selected)
		# Load the UI color into the color picker
		if ui_color_picker != null:
			ui_color_picker.color = Color.html(dplayerattribute.default_mode.ui_color)
		if hide_when_empty_check_box != null:
			hide_when_empty_check_box.button_pressed = dplayerattribute.default_mode.hide_when_empty

		# Load drain attributes into the grid container
		if dplayerattribute.default_mode.drain_attributes:
			_load_drain_attributes_into_ui(dplayerattribute.default_mode.drain_attributes)
	else:
		mode_tab_container.set_current_tab(0)  # Hide default_mode tab if it doesn't exist


# Function to handle loading and showing fixed mode
func process_fixed_mode() -> void:
	if dplayerattribute.fixed_mode:
		mode_tab_container.set_current_tab(1)  # Make fixed_mode tab visible
		if fixed_amount_spin_box != null:
			fixed_amount_spin_box.value = dplayerattribute.fixed_mode.amount
	else:
		mode_tab_container.set_current_tab(0)  # Hide fixed_mode tab if it doesn't exist


# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()


# Update the selected option in the SlotOptionButton to match the specified slot name
func select_optionbutton_item_by_text(mytext: String, optionbutton: OptionButton):
	var items = optionbutton.get_item_count()
	for i in range(items):
		if optionbutton.get_item_text(i) == mytext:
			optionbutton.selected = i
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
	olddata = DPlayerAttribute.new(dplayerattribute.get_data().duplicate(true), null)


# Function to save data into default mode
func save_default_mode() -> void:
	if not dplayerattribute.default_mode:
		dplayerattribute.default_mode = DPlayerAttribute.DefaultMode.new({})  # Initialize default_mode if not present
	dplayerattribute.default_mode.min_amount = min_amount_spinbox.value
	dplayerattribute.default_mode.max_amount = max_amount_spinbox.value
	dplayerattribute.default_mode.current_amount = current_amount_spinbox.value
	dplayerattribute.default_mode.depletion_rate = depletion_rate_spinbox.value
	dplayerattribute.default_mode.maxed_effect = maxed_effect_option_button.get_item_text(maxed_effect_option_button.selected)
	dplayerattribute.default_mode.depletion_effect = depletion_effect.get_item_text(depletion_effect.selected)
	dplayerattribute.default_mode.depleting_effect = depleting_effect_option_button.get_item_text(depleting_effect_option_button.selected)
	dplayerattribute.default_mode.ui_color = ui_color_picker.color.to_html()

	# Save drain attributes from the UI into dplayerattribute
	dplayerattribute.default_mode.drain_attributes = _get_drain_attributes_from_ui()
	# Save the value of hide_when_empty_check_box
	dplayerattribute.default_mode.hide_when_empty = hide_when_empty_check_box.button_pressed

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

# Load drain attributes into the drain_attribute_grid_container
func _load_drain_attributes_into_ui(drain_attributes: Dictionary) -> void:
	# Clear existing entries
	for child in drain_attribute_grid_container.get_children():
		child.queue_free()

	# Populate the container with attributes from the provided dictionary
	for attribute_id in drain_attributes.keys():
		_add_drain_attribute_entry(attribute_id, drain_attributes[attribute_id])


# Get the current drain attributes from the UI
func _get_drain_attributes_from_ui() -> Dictionary:
	var drain_attributes = {}
	var children = drain_attribute_grid_container.get_children()
	for i in range(0, children.size(), 4):  # Step by 4 to handle sprite-label-spinbox-deleteButton
		var label = children[i + 1] as Label
		var spinbox = children[i + 2] as SpinBox
		if label and spinbox:
			drain_attributes[label.text] = spinbox.value
	return drain_attributes


# Add a new drain attribute entry to the drain_attribute_grid_container
func _add_drain_attribute_entry(attribute_id: String, amount: float) -> void:
	var attribute_data = dplayerattribute.parent.by_id(attribute_id)

	# Create a TextureRect for the sprite
	var texture_rect = TextureRect.new()
	texture_rect.texture = attribute_data.sprite
	texture_rect.custom_minimum_size = Vector2(32, 32)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drain_attribute_grid_container.add_child(texture_rect)

	# Create a Label for the attribute ID
	var label = Label.new()
	label.text = attribute_id
	drain_attribute_grid_container.add_child(label)

	# Create a SpinBox for the amount to be drained
	var spinbox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = 100  # Adjust max value as needed
	spinbox.step = 0.1
	spinbox.tooltip_text = "The amount to drain each second."
	spinbox.value = amount
	drain_attribute_grid_container.add_child(spinbox)

	# Create a Button to delete the attribute entry
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_delete_drain_attribute_entry.bind([texture_rect, label, spinbox, delete_button]))
	drain_attribute_grid_container.add_child(delete_button)


# Delete an attribute entry from the drain_attribute_grid_container
func _delete_drain_attribute_entry(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		drain_attribute_grid_container.remove_child(element)
		element.queue_free()


# Function to determine if the dragged data can be dropped in the drain_attribute_grid_container
func _can_drop_attribute_data(_newpos, data) -> bool:
	if not data or not data.has("id"):
		return false
	if not dplayerattribute.parent.has_id(data["id"]):
		return false

	# Ensure the attribute ID isn't already in the grid
	for i in range(1, drain_attribute_grid_container.get_children().size(), 4):
		var label = drain_attribute_grid_container.get_children()[i] as Label
		if label and label.text == data["id"]:
			return false

	return true


# Handle data being dropped in the drain_attribute_grid_container
func _drop_attribute_data(newpos, data) -> void:
	if _can_drop_attribute_data(newpos, data):
		_handle_drain_attribute_drop(data)


# Add a dropped attribute to the drain_attribute_grid_container
func _handle_drain_attribute_drop(dropped_data) -> void:
	if dropped_data and "id" in dropped_data:
		var attribute_id = dropped_data["id"]
		if dplayerattribute.parent.has_id(attribute_id):
			_add_drain_attribute_entry(attribute_id, 1.0)  # Default value for new attributes
		else:
			print_debug("Invalid attribute ID: " + attribute_id)
	else:
		print_debug("Dropped data does not contain a valid 'id' key.")


# Called when the depleting effect option is changed
func _on_depleting_effect_option_changed(index: int) -> void:
	var selected_text = depleting_effect_option_button.get_item_text(index)
	if selected_text == "drain other attributes":
		drain_attribute_panel_container.visible = true
	else:
		drain_attribute_panel_container.visible = false
