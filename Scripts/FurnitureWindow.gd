extends Control

# This script supports the UI for controlling a FurnitureStaticSrv when the player interacts with it.
# It displays furniture details and handles crafting functionalities.

@export var furniture_container_view: Control = null
@export var furniture_name_label: Label = null
@export var crafting_queue_container: GridContainer = null
@export var crafting_recipe_container: GridContainer = null
@export var crafting_v_box_container: VBoxContainer = null

# Recipe panel controls:
@export var recipe_panel_container: PanelContainer = null
@export var item_name_label: Label = null
@export var item_description_label: Label = null
@export var item_craft_time_label: Label = null
@export var ingredients_grid_container: GridContainer = null
@export var add_to_queue_button: Button = null


var furniture_instance: FurnitureStaticSrv = null:
	set(value):
		_disconnect_furniture_signals()
		furniture_instance = value
		if furniture_instance:
			_connect_furniture_signals()
			_update_furniture_ui()
			# Show or hide crafting container based on whether this furniture is a crafting station
			crafting_v_box_container.visible = furniture_instance.is_crafting_station()

# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.signal_broker.furniture_interacted.connect(_on_furniture_interacted)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)

# Updates UI elements based on the current furniture_instance.
func _update_furniture_ui():
	furniture_container_view.set_inventory(furniture_instance.get_inventory())
	furniture_name_label.text = furniture_instance.get_furniture_name()
	_populate_crafting_recipe_container()
	_populate_crafting_queue_container()

# Connects necessary signals from the furniture_instance.
func _connect_furniture_signals():
	furniture_instance.crafting_queue_updated.connect(_on_crafting_queue_updated)
	if not furniture_instance.about_to_be_destroyed.is_connected(_on_furniture_about_to_be_destroyed):
		furniture_instance.about_to_be_destroyed.connect(_on_furniture_about_to_be_destroyed)

# Disconnects signals from the previous furniture_instance.
func _disconnect_furniture_signals():
	if furniture_instance:
		if furniture_instance.crafting_queue_updated.is_connected(_on_crafting_queue_updated):
			furniture_instance.crafting_queue_updated.disconnect(_on_crafting_queue_updated)

# Callback for furniture interaction.
func _on_furniture_interacted(new_furniture_instance: FurnitureStaticSrv):
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

# Retrieves the crafting time for a specific item by ID.
func _get_craft_time(item_id: String) -> float:
	var recipe: RItem.CraftRecipe = Runtimedata.items.get_first_recipe_by_id(item_id)
	return recipe.craft_time if recipe else 10  # Default to 10 seconds.

# Adds a crafting recipe item to the UI.
func _add_recipe_item(item_id: String):
	var item_data: RItem = Runtimedata.items.by_id(item_id)
	if not item_data:
		return

	# Add the icon directly to the container
	var icon = _create_icon(item_data.sprite)
	crafting_recipe_container.add_child(icon)

	# Add the button directly to the container
	var button = _create_button(item_data.name, _on_recipe_button_pressed.bind(item_id))
	crafting_recipe_container.add_child(button)


# Populates the crafting recipes UI.
func _populate_crafting_recipe_container():
	if not furniture_instance:
		return
	Helper.free_all_children(crafting_recipe_container)
	for item_id in furniture_instance.rfurniture.get_crafting_items():
		_add_recipe_item(item_id)

# Adds a crafting queue item to the UI.
func _add_queue_item(item_id: String):
	var item_data: RItem = Runtimedata.items.by_id(item_id)
	if not item_data:
		return

	crafting_queue_container.add_child(_create_icon(item_data.sprite))
	crafting_queue_container.add_child(_create_label(item_data.name))
	crafting_queue_container.add_child(_create_button("X", _on_delete_button_pressed.bind(item_id)))

# Populates the crafting queue UI.
func _populate_crafting_queue_container():
	if not furniture_instance or not furniture_instance.crafting_container:
		return
	Helper.free_all_children(crafting_queue_container)
	for item_id in furniture_instance.crafting_container.crafting_queue:
		_add_queue_item(item_id)

# Handles updates to the crafting queue.
func _on_crafting_queue_updated(_current_queue: Array[String]):
	_populate_crafting_queue_container()

# Handles the queue button being pressed.
func _on_queue_button_pressed(item_id: String):
	furniture_instance.add_to_crafting_queue(item_id)

# Handles the delete button being pressed.
func _on_delete_button_pressed(_item_id: String):
	furniture_instance.crafting_container.remove_from_crafting_queue()

# Handles furniture destruction signal.
func _on_furniture_about_to_be_destroyed(furniture: FurnitureStaticSrv):
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

# Handles the recipe button being pressed. Updates the Recipe panel.
func _on_recipe_button_pressed(item_id: String):
	var item_data: RItem = Runtimedata.items.by_id(item_id)
	if not item_data:
		return

	# Update the Recipe panel controls with the selected item's details
	item_name_label.text = item_data.name
	item_description_label.text = item_data.description
	item_craft_time_label.text = "Craft Time: " + str(_get_craft_time(item_id)) + " seconds"

	# Connect the add_to_queue_button to _on_queue_button_pressed with the item_id
	if add_to_queue_button.button_up.is_connected(_on_queue_button_pressed):
		add_to_queue_button.button_up.disconnect(_on_queue_button_pressed)  # Disconnect previous signal
	add_to_queue_button.button_up.connect(_on_queue_button_pressed.bind(item_id))

	# Clear and populate the ingredients list
	Helper.free_all_children(ingredients_grid_container)
	var item_recipe: RItem.CraftRecipe = item_data.get_first_recipe()
	if item_recipe:
		for ingredient in item_recipe.required_resources:
			var ingredient_id: String = ingredient.id
			var ingredient_amount: int = ingredient.amount
			var ingredient_data: RItem = Runtimedata.items.by_id(ingredient_id)

			if ingredient_data:
				# Add the sprite (icon)
				var ingredient_icon = _create_icon(ingredient_data.sprite)
				ingredients_grid_container.add_child(ingredient_icon)

				# Add the name
				var ingredient_label = _create_label(ingredient_data.name)
				ingredients_grid_container.add_child(ingredient_label)

				# Add the amount
				var amount_label = _create_label("x" + str(ingredient_amount))
				ingredients_grid_container.add_child(amount_label)
