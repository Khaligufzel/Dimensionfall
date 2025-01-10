extends Control

# This script supports the UI for controlling a FurnitureBlueprintSrv when the player interacts with it.
# It displays furniture details and handles crafting functionalities.

@export var furniture_container_view: Control = null
@export var furniture_name_label: Label = null
@export var furniture_description_label: Label = null


# Recipe panel controls:
@export var ingredients_grid_container: GridContainer = null
@export var construct_button: Button = null


var furniture_instance: FurnitureBlueprintSrv = null:
	set(value):
		_disconnect_furniture_signals()
		furniture_instance = value
		if furniture_instance:
			_connect_furniture_signals()
			_update_furniture_ui()


# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.signal_broker.furniture_interacted.connect(_on_furniture_interacted)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)
	# Connect to the ItemManager.allAccessibleItems_changed signal
	ItemManager.allAccessibleItems_changed.connect(_on_all_accessible_items_changed)


# Updates UI elements based on the current furniture_instance.
func _update_furniture_ui():
	furniture_container_view.set_inventory(furniture_instance.get_inventory())
	furniture_name_label.text = furniture_instance.get_furniture_name()
	_refresh_ingredient_list()
	_update_construct_button()


# Connects necessary signals from the furniture_instance.
func _connect_furniture_signals():
	if not furniture_instance.about_to_be_destroyed.is_connected(_on_furniture_about_to_be_destroyed):
		furniture_instance.about_to_be_destroyed.connect(_on_furniture_about_to_be_destroyed)

	# Connect inventory contents_changed signal
	var my_inventory = furniture_instance.get_inventory()
	if my_inventory.contents_changed.is_connected(_on_inventory_contents_changed):
		my_inventory.contents_changed.disconnect(_on_inventory_contents_changed)
	my_inventory.contents_changed.connect(_on_inventory_contents_changed)


# Disconnects signals from the previous furniture_instance.
func _disconnect_furniture_signals():
	if furniture_instance:
		# Disconnect inventory contents_changed signal
		var my_inventory = furniture_instance.get_inventory()
		if my_inventory.contents_changed.is_connected(_on_inventory_contents_changed):
			my_inventory.contents_changed.disconnect(_on_inventory_contents_changed)


# Callback for furniture interaction. Only for FurnitureBlueprintSrv types
func _on_furniture_interacted(new_furniture_instance: Node3D):
	if new_furniture_instance is FurnitureBlueprintSrv:
		furniture_instance = new_furniture_instance
		self.show()

# Callback for furniture exiting proximity.
func _on_container_exited_proximity(exited_furniture_instance: Node3D):
	if exited_furniture_instance == furniture_instance:
		furniture_instance = null
		self.hide()

# Closes the UI when the close button is pressed.
func _on_close_menu_button_button_up() -> void:
	furniture_instance = null
	self.hide()


# Handles furniture destruction signal.
func _on_furniture_about_to_be_destroyed(furniture: FurnitureBlueprintSrv):
	if furniture == furniture_instance:
		_disconnect_furniture_signals()
		furniture_instance = null


# Utility function to create a TextureRect for item icons.
func _create_icon(texture: Texture) -> TextureRect:
	var icon = TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

# Utility function to create a Label for item names.
func _create_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label

# Utility function to create a Button with a connected callback.
func _create_button(text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.button_up.connect(callback)
	return button


# Populates the ingredients list using the furniture destruction items.
func _refresh_ingredient_list():
	if not furniture_instance:
		return  # Exit if no valid furniture instance is provided

	Helper.free_all_children(ingredients_grid_container)
	
	var rfurniture: RFurniture = furniture_instance.rfurniture
	# Get the items from the furniture destruction data
	var items: Dictionary = rfurniture.construction.items if rfurniture.construction and not rfurniture.construction.items.is_empty() else {}

	# Loop through the items to populate the ingredient list
	for ingredient_id in items.keys():
		_add_ingredient_to_list(ingredient_id, items[ingredient_id])


# Adds a single ingredient to the ingredients list.
func _add_ingredient_to_list(ingredient_id: String, required_amount: int):
	var ingredient_data: RItem = Runtimedata.items.by_id(ingredient_id)
	if not ingredient_data:
		return  # Exit if the ingredient data is not found

	# Calculate available and required amounts
	var available_amount: int = furniture_instance.get_available_ingredient_amount(ingredient_id)

	# Add UI elements for the ingredient
	_add_ingredient_icon(ingredient_data.sprite)
	_add_ingredient_name_label(ingredient_data.name, available_amount, required_amount)
	_add_ingredient_amount_label(available_amount, required_amount)

	# Add the "+" button with proper color and state
	_add_ingredient_add_button(ingredient_id, required_amount)


# Add the icon for the ingredient to the ingredients grid container.
func _add_ingredient_icon(sprite: Texture):
	var icon = _create_icon(sprite)
	ingredients_grid_container.add_child(icon)


# Add the ingredient name label and set its color based on availability.
func _add_ingredient_name_label(ingredient_name: String, available: int, required: int):
	var label = _create_label(ingredient_name)
	if available < required:
		label.modulate = Color(1, 0, 0)  # Red if insufficient
	ingredients_grid_container.add_child(label)


# Add the ingredient amount label and set its color based on availability.
func _add_ingredient_amount_label(available: int, required: int):
	var label = _create_label(str(available) + " / " + str(required))
	if available < required:
		label.modulate = Color(1, 0, 0)  # Red if insufficient
	ingredients_grid_container.add_child(label)


# Add the "+" button for the ingredient and set its color and state.
func _add_ingredient_add_button(ingredient_id: String, required_amount: int):
	var button = _create_button("+", func() -> void:
		if furniture_instance:
			# Transfer items to the furniture inventory
			ItemManager.transfer_items_to_inventory(
				furniture_instance.get_inventory(),
				ingredient_id,
				required_amount
			)
		# Update the UI after the transfer
		_refresh_ingredient_list()
		_update_construct_button()
	)

	# Determine button state based on ingredient availability outside the inventory
	var has_sufficient_outside = has_sufficient_ingredient_outside_inventory(ingredient_id, required_amount)
	button.modulate = Color(0, 1, 0) if has_sufficient_outside else Color(1, 0, 0)
	button.disabled = not has_sufficient_outside

	# Add the button to the grid container
	ingredients_grid_container.add_child(button)


# Function to check if the amount of a specific ingredient is sufficient outside the given inventory.
# Calls ItemManager.has_sufficient_amount_not_in_inventory and returns the result.
func has_sufficient_ingredient_outside_inventory(item_id: String, amount: int) -> bool:
	if not furniture_instance:
		return false  # Ensure furniture_instance is valid

	# Get the inventory of the furniture_instance
	var inventory = furniture_instance.get_inventory()
	
	# Call ItemManager.has_sufficient_amount_not_in_inventory and return the result
	return ItemManager.has_sufficient_amount_not_in_inventory(inventory, item_id, amount)


# Called when allAccessibleItems_changed signal is emitted.
func _on_all_accessible_items_changed(_items_added: Array, _items_removed: Array):
	if furniture_instance:
		_refresh_ingredient_list()
		_update_construct_button()


# Callback for when the inventory contents change.
func _on_inventory_contents_changed():
	if furniture_instance:
		_refresh_ingredient_list()
		_update_construct_button()

# Enables or disables the construct button based on whether all construction items are present
func _update_construct_button():
	if furniture_instance and furniture_instance.has_all_construction_items():
		construct_button.disabled = false  # Enable the button if all items are available
	else:
		construct_button.disabled = true  # Disable the button if items are missing


# The player has pressed the construct button, so we finish construction
# Spawn the actual furniture instance and remove the blueprint instance
func _on_construct_button_button_up() -> void:
	var furniture_spawner: FurnitureBlueprintSpawner = furniture_instance.spawner
	var chunk: Chunk = furniture_spawner.chunk
	# Spawn the furniture with the adjusted position
	chunk.spawn_furniture({
		"json": {"id": furniture_instance.rfurniture.id, "rotation": furniture_instance.get_my_rotation()},
		"pos": furniture_instance.furniture_transform.get_position()
	})
	furniture_instance.die()
	hide()
