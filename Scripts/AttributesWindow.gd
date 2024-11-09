extends Control

# This script controls the attribute window
# The attribute window shows stats about the player like food, water, stamina

# These are references to the containers in the UI where stats and skills are displayed
@export var attributeContainer: VBoxContainer
var player_instance: CharacterBody3D

# Dictionary to store the AttributeDisplay instances by attribute ID
var attribute_displays: Dictionary = {}

# Inner class to represent a UI display for a single attribute
class AttributeDisplay:
	var hbox: HBoxContainer
	var progress_bar: ProgressBar

	# Constructor to initialize the UI controls
	func _init(attribute: PlayerAttribute):
		hbox = HBoxContainer.new()
		
		# Add the icon (TextureRect) for the attribute
		var icon = TextureRect.new()
		icon.texture = attribute.sprite
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		hbox.add_child(icon)

		# Create the ProgressBar to represent the current amount
		progress_bar = ProgressBar.new()
		progress_bar.min_value = attribute.default_mode.min_amount
		progress_bar.max_value = attribute.default_mode.max_amount
		progress_bar.value = attribute.default_mode.current_amount
		progress_bar.custom_minimum_size = Vector2(100, 16)
		progress_bar.tooltip_text = attribute.description

		# Set custom colors
		var ui_color = Color.html(attribute.attribute_data.default_mode.ui_color)
		var darker_color = ui_color.darkened(0.4)
		
		# Create and set the background stylebox
		var background_stylebox = progress_bar.get_theme_stylebox("background").duplicate()
		background_stylebox.set_bg_color(darker_color)
		progress_bar.add_theme_stylebox_override("background", background_stylebox)

		# Create and set the fill stylebox
		var fill_stylebox = progress_bar.get_theme_stylebox("fill").duplicate()
		fill_stylebox.set_bg_color(ui_color)
		progress_bar.add_theme_stylebox_override("fill", fill_stylebox)

		hbox.add_child(progress_bar)

	# Update the ProgressBar value and visibility
	func update(attribute: PlayerAttribute) -> void:
		if attribute.default_mode.hide_when_empty and attribute.default_mode.current_amount < 1:
			set_visibility(false)
		else:
			set_visibility(true)
		progress_bar.value = attribute.default_mode.current_amount

	func set_visibility(is_visible: bool) -> void:
		progress_bar.visible = is_visible
		hbox.visible = is_visible


	# Update the minimum value of the ProgressBar
	func update_min_amount(min_amount: float) -> void:
		progress_bar.min_value = min_amount

	# Update the maximum value of the ProgressBar
	func update_max_amount(max_amount: float) -> void:
		progress_bar.max_value = max_amount

# Initialize the attribute window when the node enters the scene tree
func _ready():
	Helper.signal_broker.player_attribute_changed.connect(_on_player_attribute_changed)
	player_instance = get_tree().get_first_node_in_group("Players")
	_on_player_attribute_changed(player_instance)
	visibility_changed.connect(_on_visibility_changed)

# Handles the update of the attribute display when the player attribute changes
func _on_player_attribute_changed(player_node: CharacterBody3D, attr: PlayerAttribute = null):
	if attr and attr.default_mode:  # If a specific attribute has changed
		if attribute_displays.has(attr.id):
			# Update only the specific attribute display
			attribute_displays[attr.id].update(attr)
		else:
			# Create a new display if it doesn't exist
			var display = AttributeDisplay.new(attr)
			attribute_displays[attr.id] = display
			attributeContainer.add_child(display.hbox)
	else:  # If the entire player attributes need to be refreshed
		clear_container(attributeContainer)  # Clear existing content
		attribute_displays.clear()  # Clear existing displays
		var playerattributes = player_node.attributes
		for attribute: PlayerAttribute in playerattributes.values():
			if attribute.default_mode:
				var display = AttributeDisplay.new(attribute)
				attribute_displays[attribute.id] = display
				attributeContainer.add_child(display.hbox)


# Utility function to clear all children in a container
func clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

# New function to refresh stats and skills when the window becomes visible
func _on_visibility_changed() -> void:
	if visible:
		_on_player_attribute_changed(player_instance)
